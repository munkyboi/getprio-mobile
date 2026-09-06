# Mobile QR Join and Payment Contract

## QR payload

The printed location QR uses the existing readable join URL with a separate opaque UUID:

`https://<approved-host>/join/<vendorSlug>/<locationSlug>?source=qr&id=<location-qr-uuid>`

- `id` is a server-generated random UUID v4 for one location.
- It is separate from `store_locations.id` and is generated when the location is created; existing locations receive one during migration/backfill.
- It remains stable for printed QR codes until an authorized vendor/platform admin regenerates it.
- Regeneration immediately invalidates the previous UUID; existing tickets are unaffected.
- If vendor/location slugs are present, the server cross-checks them against `id` and rejects mismatches. Enterprise integrations may omit the slugs when the valid `id` is present.

## Host validation

- The platform dashboard maintains the approved HTTPS host list.
- The mobile app includes the primary GetPrio host as a built-in fallback and refreshes/caches the maintained list from trusted GetPrio configuration.
- The scanner accepts only HTTPS URLs whose host is on the maintained list and whose join path/query has a valid `id` and `source=qr`.
- The app never opens the scanned URL or navigates to an arbitrary host. It sends only the parsed UUID to the trusted mobile API.
- The server remains authoritative and may bind a UUID to an approved enterprise host when that integration is configured.
- Invalid schemes, hosts, paths, UUIDs, fragments, unexpected parameters, or unresolved IDs produce a safe invalid-QR state without logging raw QR contents.

## Resolve and join

1. The authenticated app calls `GET /mobile/queue-join/resolve?id=<location-qr-uuid>`.
2. The endpoint returns canonical vendor/location details, queue availability/reason, current free/paid mode, fee/currency, and any required join constraints. It creates no ticket or payment.
3. The app calls `POST /mobile/queue-join` with the UUID, customer preferences, and a client-generated `joinAttemptId`.
4. The server resolves the UUID again and rechecks location activity, queue intake, and the current fee. The earlier preview is never trusted as authorization or pricing.

Both join endpoints first return `otpRequired: true` with an email challenge. No ticket or checkout is created before verification. After successful verification, free queues create the authenticated customer ticket. The customer name uses the saved display name, falling back to profile name. If the same customer already has an active ticket at that location and queue day, the request returns that ticket. Different vendors/locations remain allowed; after cancellation, a new join is allowed.

## Known-vendor join

When a vendor has multiple locations, the vendor details action opens a modal bottom sheet populated from the loaded vendor details. Selecting a location starts the join for that location slug; dismissing the sheet does nothing. A single location skips the sheet. The authenticated app calls `POST /api/mobile/queue-join/direct` with the vendor slug and optional location slug. The server resolves the active primary/location queue, rechecks availability and the current fee, and uses the same authenticated payment and ticket-issuance flow as QR joins. The client never creates a ticket before a required PayMongo payment is confirmed.

## Email verification

- The server sends a six-digit code to the authenticated customer's account email for both QR and direct joins. An account without an email cannot join.
- The initial response includes `otpId`, `deliveryTarget`, `expiresAt`, `resendAvailableAt`, `resendsRemaining`, and canonical tenant/location slugs.
- `POST /api/mobile/queue-join/otp/verify` accepts `otpId` and `code` with an `Idempotency-Key`. It verifies challenge ownership, rechecks the original location's availability, and uses the existing queue OTP service before creating the ticket or payment attempt.
- `POST /api/mobile/queue-join/otp/resend` accepts `otpId` with an `Idempotency-Key`, checks ownership, and returns the replacement challenge. The app replaces its active challenge ID and clears the old code.
- Existing queue OTP expiry, attempt limits, resend cooldowns, and lockouts remain authoritative on the server. The app auto-submits a complete code, prevents concurrent submissions, displays errors, and disables resend during the cooldown or after the resend limit.
- Email validation does not opt the customer into queue email notifications.
- Deploy the backend contract and a compatible mobile build together; older builds cannot render the new challenge response.

## Paid queues

- A paid join creates one authenticated, idempotent payment attempt tied to the customer and `joinAttemptId`.
- The app opens hosted PayMongo checkout; no native payment SDK is required for MVP.
- The ticket is created only after server-side PayMongo confirmation through webhook or authenticated sync.
- PayMongo returns through a verified HTTPS universal link containing only a short-lived opaque reference.
- The app calls the authenticated mobile payment-status/sync endpoint and never trusts a URL `status` value.
- Repeated requests with the same `joinAttemptId` return the existing ticket or payment attempt.
- If the app closes during checkout, the customer can recover the pending attempt after relaunch/login.
- A pending attempt is retried on app resume, pull-to-refresh, and bounded backoff polling. No second checkout is created while the original remains pending.
- Cancelled, failed, or expired checkout creates no ticket and permits a new attempt after the previous attempt reaches a terminal state.
- A late provider success is reconciled server-side. If the queue is no longer available, no ticket is issued and the existing blocked/refund-pending payment path is used.

## Race and error states

- If the fee changes after resolution, return `QUEUE_FEE_CHANGED` with the new fee and require customer confirmation. Never silently charge a different amount.
- If the queue is closed or paused, return `joinable: false` with a reason and do not show Join or Pay.
- The server rechecks queue intake during both free ticket creation and paid ticket issuance.
- A duplicate scan or network retry is safe because the app locks the active attempt and the server enforces idempotency.
- Ticket cancellation remains waiting-only, as defined by the shared queue ticket lifecycle contract.
