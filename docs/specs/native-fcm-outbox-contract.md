# Native FCM and Postgres outbox contract

Date: 2026-08-28  
Scope: iOS-first Flutter customer app, with Android-compatible contracts.  
Authority: PostgreSQL queue state and queue-event/outbox records. FCM is a delivery transport and invalidation signal only.

## Contract decisions

- Keep PostgreSQL queue state and lifecycle events authoritative. A push may be delayed, duplicated, reordered, or missed; Flutter always refetches an authenticated REST snapshot before showing current ticket details.
- Keep the existing Web Push channel for the web application. Add FCM as a separate mobile channel; do not send FCM tokens to the Web Push subscription API.
- Queue customer notification intent must be created in the same transaction as the state transition and durable lifecycle event. Direct customer Web Push calls must be migrated or mirrored through an equivalent durable outbox path before FCM is enabled for that event.
- Respect the shared `notificationSettings.queueAlerts` preference and the separate device-level OS permission. Denying OS permission or disabling queue alerts never blocks queue joining or ticket reads.
- Register every active app installation independently. One customer may have multiple iPhones/Android devices; one event may deliver once to each active installation.
- Do not send every position change. Send targeted lifecycle signals: join/paid success, near turn, called, served, skipped/requeued, cancelled, carried over, and queue closed/reopened when the customer's ticket is affected.

## Confirmed foundation

The existing `queue_notification_outbox` has a unique `idempotency_key`, queue event/day/ticket references, recipient/channel, payload, lease, attempt, expiry, and audit fields. The channel constraint currently supports only `web_push` and `email`; inserts use `ON CONFLICT (idempotency_key) DO NOTHING` ([`20260731_03_expand_queue_events_and_add_outbox.sql:25-57`](/Users/carloabella/Projects/getprio/dev/database/migrations/20260731_03_expand_queue_events_and_add_outbox.sql:25), [`queueNotificationOutbox.js:7-35`](/Users/carloabella/Projects/getprio/dev/backend/src/repositories/queueNotificationOutbox.js:7)).

The dispatcher claims pending/retry rows with a two-minute lease, retries failures through attempt eight with increasing delays, and marks exhausted work dead. A worker crash can be recovered after lease expiry, but dead rows are not retried automatically ([`queueNotificationOutbox.js:38-87`](/Users/carloabella/Projects/getprio/dev/backend/src/repositories/queueNotificationOutbox.js:38), [`queueLifecycleWorker.js:19-73`](/Users/carloabella/Projects/getprio/dev/backend/src/services/queueLifecycleWorker.js:19)). These mechanics should be reused for FCM rather than building a second queue.

The current Web Push service already gates customer delivery on `queueAlerts`, sends short customer-safe copy, deactivates 404/410 subscriptions, and treats delivery as best effort ([`pushNotificationService.js:106-145`](/Users/carloabella/Projects/getprio/dev/backend/src/services/pushNotificationService.js:106), [`pushNotificationService.js:196-230`](/Users/carloabella/Projects/getprio/dev/backend/src/services/pushNotificationService.js:196)). The existing account notification-settings route remains shared ([`accountRoutes.js:280-330`](/Users/carloabella/Projects/getprio/dev/backend/src/routes/accountRoutes.js:280)).

## Mobile registration contract

Add mobile-only routes under `/backend/mobile/`:

| Route | Auth | Request / result |
| --- | --- | --- |
| `PUT /api/mobile/push/registrations/{installationId}` | Bearer customer | Upsert the current installation's FCM token and metadata; return the registration ID and active state. |
| `DELETE /api/mobile/push/registrations/{installationId}` | Bearer customer | Deactivate only the authenticated customer's installation; return success. |

An optional authenticated list route may be added only if Account needs device management. The client never supplies `userId`, `tenantId`, recipient keys, or an arbitrary owner.

The registration request should contain:

```json
{
  "token": "<opaque FCM registration token>",
  "platform": "ios",
  "appVersion": "1.0.0",
  "locale": "en-PH"
}
```

`installationId` is generated and stored locally as a random non-user identifier. The proposed server record needs `user_id`, installation ID, current token, platform, app version, locale, active flag, created/updated timestamps, last success, last failure, and failure reason. The token and installation ID need deliberate uniqueness rules so a token rotation deactivates the old token without deactivating another installation accidentally.

Register only after Firebase reports an authorized OS notification state. On Firebase token refresh, upsert the new token and deactivate or supersede the old token for that installation. On logout, call the deactivation route before clearing local auth when possible; clear local registration state regardless of network result. Reinstall creates a new installation ID.

The mobile registration record must be separate from `push_subscriptions`: the current shared table requires a browser endpoint plus `p256dh` and `auth` keys and cannot represent an FCM token ([`accountRoutes.js:454-498`](/Users/carloabella/Projects/getprio/dev/backend/src/routes/accountRoutes.js:454), [`pushSubscriptions.js:7-116`](/Users/carloabella/Projects/getprio/dev/backend/src/repositories/pushSubscriptions.js:7)).

## Outbox and delivery contract

Extend the outbox channel constraint and dispatcher to support `fcm`. For a customer lifecycle event with durable `eventKey`, enqueue a mobile intent with an idempotency key such as:

```text
{eventKey}:customer:fcm
```

This deduplicates one logical event/channel while still allowing delivery to all active installations for that customer. The outbox recipient remains a server-derived `user:{userId}` key; the dispatcher resolves active FCM registrations at send time.

The preferred path is:

1. queue mutation, lifecycle event, and customer FCM outbox intent commit in one transaction;
2. worker claims the outbox row using the existing lease and attempt logic;
3. dispatcher loads the authenticated recipient's active FCM installations;
4. Firebase Admin sends the minimal message to each active token;
5. invalid/unregistered tokens are deactivated; transient provider failures throw so the outbox retries; and
6. the row is marked sent only after the channel handler finishes its intended recipient processing.

The current source has a split boundary: queue-day lifecycle paths enqueue durable customer intents, while calling, serving/skipping/cancelling, closing, requeueing, and near-turn paths still call Web Push directly after publishing a snapshot ([`queueService.js:518-549`](/Users/carloabella/Projects/getprio/dev/backend/src/services/queueService.js:518), [`queueService.js:609-649`](/Users/carloabella/Projects/getprio/dev/backend/src/services/queueService.js:609), [`queueService.js:749-779`](/Users/carloabella/Projects/getprio/dev/backend/src/services/queueService.js:749), [`queueAutomationHelpers.js:11-50`](/Users/carloabella/Projects/getprio/dev/backend/src/services/queueAutomationHelpers.js:11)). FCM must not be added as a second direct call beside these paths because that preserves duplicate and crash-window risks. Normalize the event path first or provide equivalent durable keys and transactional enqueue behavior for each covered event.

### Retry and stale-token rules

- Transient Firebase/network/service failures: throw from the FCM channel handler and let the existing outbox mark the row `retry`.
- Invalid, unregistered, or permanently rejected token: deactivate that installation token and do not retry that token. The row may be considered delivered for that recipient while other active installations continue.
- Mixed result: persist per-installation success/failure where observability requires it, then retry only unresolved transient recipients without re-sending completed recipients. The exact data model must be designed before implementation; the existing `notification_deliveries` table has no token-level uniqueness/idempotency contract.
- Eight attempts/dead-letter: retain the existing operational behavior unless a measured FCM reliability requirement changes it. Dead notification delivery never rolls back a queue state transition.

Firebase Admin error-code classification must be verified against the selected SDK version during implementation. The source repository currently has no FCM sender or classification logic.

## Safe payload and deep link

Use a minimal notification payload. Proposed shape:

```json
{
  "eventType": "customer_queue_called",
  "notificationId": "<durable event or outbox reference>",
  "ticketRef": "<opaque ticket reference>",
  "route": "ticket"
}
```

The visible title/body may include the vendor name, ticket number, and short customer-safe instruction. The data payload must not include passwords, access/refresh tokens, MFA or reset values, email/phone numbers, payment data, internal notes, or a full queue snapshot. `ticketRef` is a navigation hint only; after opening, the app must verify authenticated ownership through the shared ticket/snapshot API and render the server response.

Use an in-app route such as `getprio://tickets/{ticketRef}` only as a pending navigation target. If the reference is absent or no longer resolves, open My Tickets and refresh instead. Push delivery must never authorize access to a ticket.

The client keeps a short-lived local set of recently handled `notificationId` values to avoid duplicate UI work, but this is an optimization only. Durable deduplication remains the outbox `idempotency_key` and lifecycle `eventKey`.

## Flutter lifecycle behavior

- **Foreground:** receive the FCM signal, coalesce or suppress a redundant OS banner according to the notification UX, immediately refetch the affected authenticated ticket snapshot, and update Home/My Tickets/detail. Do not mutate local status from the payload.
- **Background:** let the OS display the safe notification. On tap, restore/refresh the bearer session, validate the pending route, refetch, then render the ticket.
- **Terminated:** process the notification-open event after Firebase initialization, retain only a non-sensitive pending route, restore auth from secure storage, refetch, and fall back to My Tickets or login if needed.
- **Resume and signal loss:** refresh active tickets on app resume and use the agreed foreground polling fallback (approximately 30 seconds while an active ticket is open). Pull-to-refresh remains available. Duplicated, out-of-order, delayed, or missed messages must converge to REST state.
- **Permission denied / queue alerts off:** continue all queue actions without registration or push; show the notification setting state clearly.

The existing web customer dashboard already combines a live stream with 30-second polling, which supports the fallback principle but does not establish Flutter behavior ([`CustomerDashboardPage.tsx:125-145`](/Users/carloabella/Projects/getprio/dev/frontend/src/pages/CustomerDashboardPage.tsx:125)).

## Event coverage

The mobile event taxonomy is:

| Event | Customer push? | Client behavior |
| --- | --- | --- |
| Free join or confirmed paid join | Yes | Refetch and open the created ticket. |
| Near turn | Yes, threshold-based | Refetch position; do not promise service timing. |
| Called | Yes | Show called state and proceed instruction. |
| Served | Yes | Refetch and move to history. |
| Skipped / requeued | Yes | Refetch; show final skipped state or new waiting position. |
| Cancelled | Yes | Refetch and confirm the terminal state. |
| Carried over | Yes | Keep active with no live position and show expiry if supplied. |
| Unserved / expired | Yes | Show the final outcome in history. |
| Queue closed/reopened affecting the customer | Yes | Refetch queue-day and ticket state. |
| Every position change | No | Screen refetch/polling is sufficient. |

This aligns with the existing customer queue notification coverage checklist, while FCM remains a new channel ([`web-push-notifications-execution-checklist.md:94-109`](/Users/carloabella/Projects/getprio/dev/docs/plan/web-push-notifications-execution-checklist.md:94)).

## Privacy, observability, and acceptance

Log event type, outbox ID, installation ID or hashed token reference, provider result class, attempt number, and timestamps. Never log the raw FCM token or complete payload. Avoid storing provider response bodies when they may contain token data.

The implementation is ready for validation when tests demonstrate:

- bearer-authenticated registration/deactivation cannot operate on another customer's installation;
- token refresh replaces the installation token and stale provider responses deactivate only the intended installation;
- queue-alert opt-out and OS permission denial prevent FCM sends without blocking queue flows;
- queue mutation plus lifecycle event plus FCM outbox intent is atomic;
- event/channel idempotency, concurrent claims, two-minute lease recovery, transient retry, permanent stale-token deactivation, and dead-letter behavior are deterministic;
- multiple active devices receive one logical event without duplicate sends per installation;
- payloads contain no sensitive data and notification taps always refetch authenticated REST state; and
- foreground, background, terminated, resume, offline, duplicate, delayed, and out-of-order event scenarios converge to the server snapshot.

No FCM implementation has been added. The required new backend surface is the mobile registration/deactivation API plus FCM delivery integration behind the existing outbox; shared notification settings and queue state remain unchanged.
