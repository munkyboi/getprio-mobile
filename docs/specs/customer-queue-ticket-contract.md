# Customer queue ticket lifecycle and mobile contract

Date: 2026-08-28  
Scope: authenticated customer queue flows in the Flutter mobile MVP.  
Authority: the shared GetPrio API and queue lifecycle; push notifications only signal that the app should refetch.

## Contract decisions

- The server is authoritative for ticket status, position, ETA, queue-day state, and timestamps.
- The mobile client exposes ticket reads and one customer mutation: cancel a ticket while its status is `waiting`.
- Vendor and system transitions are read-only from the customer's mobile app. The app does not locally advance a ticket because a push arrived, a timer elapsed, or the user reopened the screen.
- A customer may have more than one active ticket across vendors or locations. Each ticket is identified by its `lookupCode` and scoped to its vendor/location.
- The customer-facing name is `customerDisplayName` when present; otherwise use `customerName` (the saved profile name in the settled product language).

## Customer-visible statuses

The shared status union is `waiting`, `pending_carry_over`, `called`, `served`, `skipped`, `cancelled`, `unserved`, and `expired` ([`shared/types.ts:6-14`](/Users/carloabella/Projects/getprio/dev/shared/types.ts:6)).

| Server status | Customer meaning | Active ticket? | Position / ETA | Mobile action |
| --- | --- | --- | --- | --- |
| `waiting` | Joined and waiting in line. | Yes | Show the 1-based live position and approximate wait when present. | Show Cancel ticket. |
| `called` | Staff has called the customer; proceed to the service area. | Yes | Position is not applicable. | View only. |
| `pending_carry_over` | The ticket was retained for one later eligible Queue Day, but has no live position until that day opens. | Yes | No live position; show `carryOverExpiresAt` when present. | View only; no mobile cancellation action. |
| `served` | The ticket was served. | No | Not applicable. | History only. |
| `skipped` | Staff skipped the ticket. | No for the customer MVP; it may later be requeued by a vendor workflow. | Not applicable. | History only. |
| `cancelled` | The ticket was cancelled. | No | Not applicable. | History only. |
| `unserved` | The queue closed after the ticket was called without service. | No | Not applicable. | History only; explain that the outcome is final. |
| `expired` | The carry-over opportunity ended without service. | No | Not applicable. | History only; explain that this is not a cancellation. |

The existing transition table allows vendor/system changes between these states: `waiting` can become `called`, `cancelled`, `skipped`, or `unserved`; `pending_carry_over` can become `waiting`, `cancelled`, or `expired`; `called` can become `served`, `skipped`, `cancelled`, or `unserved`; and `skipped` can be requeued to `waiting`. Terminal states are `served`, `cancelled`, `unserved`, and `expired` ([`queueLifecycle.js:1-20`](/Users/carloabella/Projects/getprio/dev/backend/src/services/queueLifecycle.js:1)). The mobile UI must not expose those vendor/system transitions as customer controls.

## Ticket fields

### Live ticket detail

Use the authenticated queue snapshot's `focusTicket` and its surrounding vendor/location and queue-day fields. The shared shape provides:

- `id`, `lookupCode`, and `ticketNumber` for identity and support references;
- `customerName` and optional `customerDisplayName` for the customer label;
- `status`, optional `statusReason`, `customerConfirmedAt`, `isCarriedOver`, `carryOverCount`, `servicePriorityBand`, `carryOverExpiresAt`, and `currentQueueDayId`;
- `position`, `estimatedWaitMinutes`, and `joinedAt` ([`shared/types.ts:1362-1380`](/Users/carloabella/Projects/getprio/dev/shared/types.ts:1362)); and
- queue-day state, intake state, vendor/location identity, and `serverNow` for explaining whether the queue is open, paused, closing, or closed ([`shared/types.ts:1394-1438`](/Users/carloabella/Projects/getprio/dev/shared/types.ts:1394), [`shared/types.ts:1453-1468`](/Users/carloabella/Projects/getprio/dev/shared/types.ts:1453)).

The account history shape adds vendor/location names and slugs, status reason, carry-over expiry, queue-day ID, journey segments, and created/updated timestamps ([`accountRoutes.js:100-116`](/Users/carloabella/Projects/getprio/dev/backend/src/routes/accountRoutes.js:100), [`shared/types.ts:1866-1881`](/Users/carloabella/Projects/getprio/dev/shared/types.ts:1866)).

### Position and estimated wait

- For `waiting`, calculate neither value locally. Display the server's `position` and `estimatedWaitMinutes` from the latest snapshot.
- The current server derives a waiting ticket's position from its index in the current queue-day waiting list and returns `null` for non-waiting states ([`queueSnapshotHelpers.js:152-186`](/Users/carloabella/Projects/getprio/dev/backend/src/services/queueSnapshotHelpers.js:152)).
- The current estimate is `position × tenant.averageServiceMinutes`; it is an approximate planning aid and must not be presented as a promise ([`queueSnapshotHelpers.js:183-186`](/Users/carloabella/Projects/getprio/dev/backend/src/services/queueSnapshotHelpers.js:183)).
- For `called`, `pending_carry_over`, and terminal states, hide the position card and explain the status instead of showing a stale position. For carry-over, show the expiry when supplied.

## Lifecycle and notification meanings

| Event | In-app result | Push meaning |
| --- | --- | --- |
| Join confirmed | Add the ticket to active tickets and open its detail screen. | “Your queue ticket is confirmed.” |
| Near turn | Refresh the snapshot and show the current position. | “You’re almost next”; not a guarantee. |
| Called | Refresh and show the called state with an instruction to proceed. | “Your ticket was called.” |
| Served | Move the ticket to history after refresh. | “Your ticket was served.” |
| Skipped / requeued | Show skipped in history, or show the refreshed waiting position if the server requeues it. | Explain the server-reported outcome; do not infer requeue locally. |
| Carried over | Keep it in active tickets without a live position. | Explain that it is retained for a later eligible Queue Day and show expiry if available. |
| Queue closed / reopened affecting the ticket | Refresh and show the queue-day state and any changed ticket status. | The push is a prompt to refetch, not the source of truth. |
| Cancelled | Remove from active tickets after successful mutation and keep it in history. | Confirm cancellation if delivered. |
| Unserved / expired | Keep in history with a final outcome explanation. | Explain the final outcome and avoid offering cancellation. |

The existing queue notification checklist covers cancellation, near-turn, close/reopen, skipped, called, served, requeued, and carry-over customer events ([`web-push-notifications-execution-checklist.md:94-109`](/Users/carloabella/Projects/getprio/dev/docs/plan/web-push-notifications-execution-checklist.md:94)). Push remains best effort and cannot change queue state ([`web-push-notifications-execution-checklist.md:128-136`](/Users/carloabella/Projects/getprio/dev/docs/plan/web-push-notifications-execution-checklist.md:128)).

## Customer actions

### Cancel

The mobile app shows Cancel ticket only for `waiting` and sends bearer authentication. The shared route accepts authenticated ownership (while retaining its legacy request-matching path), checks that the ticket is still `waiting`, and returns `409` if the state has changed ([`publicRoutes.js:800-869`](/Users/carloabella/Projects/getprio/dev/backend/src/routes/publicRoutes.js:800)). The UI must confirm the action, disable duplicate submissions, refetch the returned snapshot, and treat a concurrent `409` as “This ticket is no longer waiting” followed by a fresh read.

No mobile controls are specified for transfer, priority changes, editing, customer confirmation, requeue, or cancellation of called/carry-over/terminal tickets.

### History

My Tickets uses the paginated account history endpoint rather than the overview's 50-ticket convenience list. The repository orders both newest-first by `created_at` and includes the complete customer ticket summary with journey segments ([`tickets.js:425-485`](/Users/carloabella/Projects/getprio/dev/backend/src/repositories/tickets.js:425), [`tickets.js:488-531`](/Users/carloabella/Projects/getprio/dev/backend/src/repositories/tickets.js:488)). Active tickets may be presented separately on Home and at the top of My Tickets, but the API remains the source for deduplication and status.

## Error and stale-state behavior

- `401`: refresh the bearer session once when possible; otherwise require login.
- `403`: do not reveal another customer's ticket; show that the ticket is unavailable to this account.
- `404`: show that the ticket or vendor/location is no longer available and offer a history refresh.
- `409` on cancellation: the ticket changed state; refetch and render the new authoritative status.
- Network timeout/offline: keep the last successful snapshot marked as stale, offer retry/pull-to-refresh, and never claim that a ticket changed based only on a local timer or push payload.
- Malformed or missing fields: fail closed for actions, preserve the ticket identifier, and show an unavailable-status state rather than inventing a position or ETA.

## Implementation boundary

This contract does not justify a new ticket lifecycle endpoint. Flutter should consume the shared `QueueSnapshot`, customer account overview/history, and cancellation response. Mobile-specific work remains limited to the three gaps recorded by the API audit: OAuth deep-link bearer handoff, authenticated paid PayMongo join return handling, and FCM device-token/delivery integration ([`customer-mobile-api-audit.md`](/Users/carloabella/Projects/getprio/mobile-app/docs/research/customer-mobile-api-audit.md)).
