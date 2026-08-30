# Native FCM and Postgres Outbox Audit

**Scope:** Research-only audit for the GetPrio customer Flutter mobile MVP. The
primary source is `/Users/carloabella/Projects/getprio/dev`. This document does
not implement FCM or change the existing application.

## Executive conclusion

The existing Postgres outbox is a useful source-of-truth foundation, but it is
not an FCM pipeline yet. It currently supports only `web_push` and `email`, and
only some lifecycle-generated notifications enter the outbox. Several ordinary
queue actions still call the Web Push service directly after the state change.

The safest mobile design is therefore to retain Postgres queue events and the
outbox as the authoritative notification intent, add an FCM delivery channel,
and move customer mobile delivery behind the same outbox boundary. The Flutter
client should treat FCM as an invalidation/signal mechanism and refetch the
authoritative ticket snapshot through authenticated REST. No FCM token,
notification payload, or local notification state should be treated as queue
truth.

## Confirmed existing behavior

### Outbox schema and transaction boundary

`queue_notification_outbox` has a unique `idempotency_key`, optional queue
event/day/ticket references, tenant and recipient keys, a channel constrained to
`web_push` or `email`, template and JSON payload fields, aggregate/deadline
versions, availability/expiry timestamps, lease fields, attempt count, error,
sent, and audit timestamps. There is an index for pending/retry dispatch.

Source: [`20260731_03_expand_queue_events_and_add_outbox.sql`](file:///Users/carloabella/Projects/getprio/dev/database/migrations/20260731_03_expand_queue_events_and_add_outbox.sql#L25-L57).

`enqueue()` inserts with `ON CONFLICT (idempotency_key) DO NOTHING`, so repeated
creation of the same event/channel intent does not create another outbox row.
The caller can pass a transaction client. Lifecycle code does this while the
queue event and queue mutation are being committed, which gives the desired
state-change-plus-intent transaction boundary.

Source: [`queueNotificationOutbox.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/repositories/queueNotificationOutbox.js#L7-L35) and [`queueDayLifecycleService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueDayLifecycleService.js#L51-L123).

Queue lifecycle events use a unique `event_key`; `createLifecycleEvent()` also
uses `ON CONFLICT (event_key) DO NOTHING`. Its event keys include queue-day
versions/deadline versions or ticket/queue-day transitions. This is durable
event deduplication in Postgres, distinct from the Web Push service's in-memory
dedupe map.

Source: [`queueEvents.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/repositories/queueEvents.js#L99-L140) and [`20260731_03_expand_queue_events_and_add_outbox.sql`](file:///Users/carloabella/Projects/getprio/dev/database/migrations/20260731_03_expand_queue_events_and_add_outbox.sql#L3-L23).

### Claiming, leasing, retries, and expiry

The dispatcher claims `pending` and `retry` rows, or expired `processing` rows,
with `FOR UPDATE SKIP LOCKED`. It leases each row for two minutes, increments
`attempt_count`, and returns the claimed row. Expired rows are excluded from
claiming, as are rows whose `expires_at` has passed.

On success, the row becomes `sent` and its lease/error fields are cleared. On
failure, the row becomes `retry` until the eighth attempt; at or above eight it
becomes `dead`. The next attempt is delayed by
`LEAST(attempt_count, 6)` minutes. A worker crash can therefore be recovered
after the two-minute lease expires, but there is no automatic retry after a row
is `dead`.

Source: [`queueNotificationOutbox.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/repositories/queueNotificationOutbox.js#L38-L87) and [`20260731_03_expand_queue_events_and_add_outbox.sql`](file:///Users/carloabella/Projects/getprio/dev/database/migrations/20260731_03_expand_queue_events_and_add_outbox.sql#L39-L54).

`queueLifecycleWorker` runs warning emission, queue-day reconciliation,
carry-over expiry, and one outbox batch in that order. It prevents overlapping
runs in the same process. The server starts this worker with its default
interval; the configured minimum is 15 seconds and the default is 60 seconds.

Source: [`queueLifecycleWorker.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueLifecycleWorker.js#L19-L73) and [`server.ts`](file:///Users/carloabella/Projects/getprio/dev/backend/src/server.ts#L43-L61).

### Dispatcher behavior

The dispatcher resolves the tenant, then:

- dispatches `web_push` vendor intents to the vendor queue notification method;
- dispatches `web_push` customer intents by loading the ticket and calling the
  customer queue notification method;
- dispatches `email` customer/admin intents through the existing email service;
- records Web Push success/failure in `notification_deliveries`, linked by
  `outbox_id`; and
- marks the outbox intent sent after the channel handler returns, or retries it
  after an exception.

Source: [`queueNotificationOutboxDispatcher.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueNotificationOutboxDispatcher.js#L45-L147) and [`queueNotificationOutboxDispatcher.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueNotificationOutboxDispatcher.js#L149-L178).

There are two important boundaries to preserve when adding FCM. A missing
tenant or missing ticket currently returns without throwing, after which the
dispatcher marks the intent `sent`; this is existing behavior, not evidence of
an FCM contract. Also, `notification_deliveries` has `sent`/`failed` records but
no token-level delivery model or uniqueness constraint.

Source: [`queueNotificationOutboxDispatcher.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueNotificationOutboxDispatcher.js#L45-L49) and [`notificationDeliveries.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/repositories/notificationDeliveries.js#L30-L67).

### Which queue events currently create outbox intents

The lifecycle service creates customer Web Push and optional email intents for
terminal outcomes during queue-day closure and for pending-carry-over expiry.
The customer Web Push intent uses an idempotency suffix of
`customer:web_push`, recipient `user:{user_id}` when available, and a small
payload containing `ticketId` and `reasonCode`.

Source: [`queueDayLifecycleService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueDayLifecycleService.js#L507-L546) and [`queueDayLifecycleService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueDayLifecycleService.js#L777-L813).

The lifecycle service also creates staff Web Push and admin email intents for
queue-day warnings, closure, reopening, and reconciliation failures. Closing
warnings can be obsoleted when a newer deadline version exists or when the
queue day closes.

Source: [`queueDayLifecycleService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueDayLifecycleService.js#L75-L123) and [`queueNotificationOutbox.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/repositories/queueNotificationOutbox.js#L90-L110).

The ordinary customer queue paths are not uniformly outbox-backed. Calling a
ticket, serving/skipping/cancelling it, closing a queue day, and requeueing a
ticket call `notifyCustomerQueueUpdate()` directly after publishing a snapshot.
Near-turn checks also call it directly. The direct queue event helper inserts a
basic `queue_events` row without an `event_key`, so these calls are not covered
by the lifecycle event/outbox idempotency scheme.

Source: [`queueService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueService.js#L33-L49), [`queueService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueService.js#L518-L549), [`queueService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueService.js#L609-L649), [`queueService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueService.js#L749-L779), [`queueService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueService.js#L856-L942), [`queueService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueService.js#L1006-L1029), and [`queueAutomationHelpers.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/queueAutomationHelpers.js#L11-L50).

### Current Web Push transport, payload, dedupe, and stale-token handling

The existing transport is the Node `web-push` library using VAPID public,
private, and subject configuration. Customer sends are skipped if the customer
has no user ID, VAPID is not configured, or `notificationSettings.queueAlerts`
is false. Sends are addressed to every active subscription for the user.

Source: [`pushNotificationService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/pushNotificationService.js#L1-L20), [`pushNotificationService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/pushNotificationService.js#L196-L230), and [`pushNotificationService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/pushNotificationService.js#L470-L493).

The stored Web Push subscription is an authenticated user's browser endpoint
plus `p256dh` and `auth` keys, with optional tenant metadata. Active endpoints
are unique. Registration upserts the endpoint and resets failures; deletion is
scoped to the authenticated user's subscription ID. A 404 or 410 from the
provider deactivates by endpoint. Other errors increment `failure_count` and
are logged, but the direct Web Push method returns `false` rather than throwing.

Source: [`pushSubscriptions.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/repositories/pushSubscriptions.js#L7-L116), [`pushSubscriptions.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/repositories/pushSubscriptions.js#L153-L177), and [`pushNotificationService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/pushNotificationService.js#L106-L145).

The transport has a process-local two-minute dedupe map keyed by user/tenant and
notification tag. It is not durable, shared between worker processes, or a
substitute for the outbox unique key. Sends are sequential per subscription.

Source: [`pushNotificationService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/pushNotificationService.js#L6-L8), [`pushNotificationService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/pushNotificationService.js#L71-L92), and [`pushNotificationService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/pushNotificationService.js#L196-L229).

Customer Web Push messages contain a title, short body, event type, tag, and a
browser URL to the ticket page when a lookup code exists. Existing copy contains
the vendor name and ticket number; it does not include phone, email, payment
proof, or internal notes. The service logs event type/tag and identifiers, not
the full payload.

Source: [`pushNotificationService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/pushNotificationService.js#L94-L103), [`pushNotificationService.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/services/pushNotificationService.js#L441-L493), and [`web-push-notifications-execution-checklist.md`](file:///Users/carloabella/Projects/getprio/dev/docs/plan/web-push-notifications-execution-checklist.md#L128-L136).

### Existing subscription APIs and shared settings

The existing authenticated routes are:

| Existing route | Confirmed behavior | Mobile reuse status |
| --- | --- | --- |
| `GET /api/push/vapid-public-key` | Returns Web Push VAPID metadata. | Web-only; not an FCM API. |
| `POST /api/account/push-subscriptions` | Validates a browser subscription, optionally checks tenant access, then upserts it for the authenticated user. | Do not send an FCM token to this route. |
| `DELETE /api/account/push-subscriptions/:subscriptionId` | Deactivates only a subscription owned by the authenticated user. | Web-only; analogous mobile operation is absent. |
| `GET/PATCH /api/account/notification-settings` | Reads/normalizes or updates `bookingAlerts`, `queueAlerts`, `campaignAlerts`, and `preferredContactMethod`. | Reuse for the mobile queue-alert preference. |

Sources: [`accountRoutes.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/routes/accountRoutes.js#L44-L45), [`accountRoutes.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/routes/accountRoutes.js#L280-L330), [`accountRoutes.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/routes/accountRoutes.js#L454-L498), and [`pushRoutes.js`](file:///Users/carloabella/Projects/getprio/dev/backend/src/routes/pushRoutes.js#L1-L14).

The customer settings implementation defaults `queueAlerts` to enabled and
the push service checks that setting immediately before customer delivery. OS
permission and FCM registration state do not exist in the shared setting
object; they should remain device/provider state rather than a replacement for
`queueAlerts`.

## Proposed FCM contract

The following is a mobile addition inferred from the confirmed gaps above. It
is not currently implemented or supported by the repository.

### Registration and revocation

Add a mobile-only authenticated surface under `/backend/mobile/` (or keep a
route shared with web only if the same device-token model is genuinely useful
to both clients):

- register or rotate one FCM registration token for the authenticated user,
  with a stable installation/device identifier, platform, app version, and
  optional locale;
- revoke one installation token on logout, uninstall cleanup, or token
  rotation; and
- list/revoke only the current user's mobile registrations if the Account UI
  needs device management.

The server must bind registration to the bearer-authenticated user and must
not accept user IDs, tenant IDs, or recipient keys as authority from the
client. The token must be stored separately from `push_subscriptions`, because
the current table requires a Web Push endpoint and key pair. A proposed mobile
record needs an active flag and last-success/last-failure data; the exact schema
and token uniqueness rule remain implementation work.

### Outbox integration and event keys

Extend the outbox channel contract to include `fcm`, then create customer FCM
intents with the same event's durable key and a channel suffix such as
`{event.eventKey}:customer:fcm`. This preserves one logical notification per
event/channel while allowing multiple active customer devices to receive it.

The intended migration is to enqueue mobile customer intents in the same
transaction as the queue state transition and lifecycle event. The direct
customer calls listed above should be routed through that boundary or otherwise
receive equivalent durable event keys. Do not merely call FCM beside the
existing direct Web Push call: that would preserve the current duplicate and
crash-window risks.

The existing outbox retry/lease machinery can be reused. FCM delivery should
throw for transient provider failures so the dispatcher marks the intent
`retry`; a permanent invalid/unregistered token should deactivate that token
and be treated as a non-retryable recipient outcome. The provider's exact error
classification must be verified against the selected Firebase Admin SDK before
implementation; the current repository does not define it.

For observability, record FCM attempts in `notification_deliveries` only after
confirming that its channel constraint and recipient semantics are extended for
FCM. If token-level results are required, the data model needs a deliberate
per-token delivery design; the current table has no uniqueness/idempotency rule
for that purpose.

### Safe payload and deep link

The FCM payload should be a minimal signal, for example:

```json
{
  "eventType": "customer_queue_called",
  "ticketId": "123",
  "notificationId": "outbox-or-event-reference",
  "deepLink": "getprio://tickets/123"
}
```

This shape is proposed, not an existing API response. It intentionally avoids
email, phone number, payment data, internal notes, authentication tokens, and
full queue snapshots. The app should open the ticket route from the deep link,
then refetch the authenticated ticket/queue snapshot. If a lookup code is
required by an existing REST route, obtain it through the authenticated API or
an already-authorized ticket response rather than putting bearer/refresh
credentials in the push payload or URL.

Notification title/body may reuse the current short customer-safe copy, but
the mobile client must not assume that a push body is current queue state.

### Foreground, background, and terminated behavior

This is the proposed Flutter behavior:

- **Foreground:** receive the FCM event, suppress or coalesce a redundant OS
  banner as appropriate, and immediately refetch the affected ticket snapshot.
- **Background:** allow the OS notification to inform the customer; when the
  user taps it, open the ticket deep link and refetch before rendering details.
- **Terminated:** open the same deep link from the notification tap, restore the
  authenticated session from secure storage, then refetch. If the session is
  unavailable, show login and retain only a non-sensitive pending destination.
- **Signal loss:** keep the existing REST refresh/polling fallback. A missed,
  delayed, duplicated, or out-of-order FCM event must converge to the server
  snapshot when the app resumes, manually refreshes, or polls.

These are client acceptance behaviors, not confirmed backend behavior. The
existing web application already uses polling and a live stream for open
customer dashboards; that does not establish an FCM or Flutter lifecycle
implementation.

Source for the existing web fallback: [`CustomerDashboardPage.tsx`](file:///Users/carloabella/Projects/getprio/dev/frontend/src/pages/CustomerDashboardPage.tsx#L125-L145).

## Gaps and implementation acceptance checks

Confirmed gaps are:

1. the outbox channel check excludes FCM;
2. there is no FCM token table, registration route, revocation route, or Firebase
   Admin delivery service;
3. the existing Web Push subscription table/API cannot represent an FCM token;
4. customer queue notifications are split between outbox-backed lifecycle
   paths and direct Web Push calls; and
5. current delivery records do not define FCM token-level outcomes.

Before implementation is considered complete, tests should prove authenticated
registration/revocation ownership, token rotation, queue-alert opt-out,
transactional outbox creation, durable event/channel idempotency, concurrent
claim safety, retry/dead-letter behavior, permanent stale-token deactivation,
transient retry, safe payload contents, deep-link refetch, duplicate/out-of-order
event convergence, and foreground/background/terminated handling. These are
acceptance requirements derived from the current behavior and the proposed
mobile contract; they are not claims that the existing code already satisfies
them.
