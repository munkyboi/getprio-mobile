# Queue ticket and booking details

Approved in chat on 9 October 2026. Targets the main GetPrio mobile app on Zero32 Domain.

## Selected queue ticket

- Show one selected ticket, without a carousel or app-bar avatars.
- Center the app-bar title and reuse Vendor Details cover and centered circular vendor logo/photo.
- Use a rounded pass card with warm paper colors, a perforated divider and the existing scannable barcode.
- For a called ticket awaiting arrival confirmation, show only `Your ticket was called. Proceed to the vendor.` in an alert above the card.
- Keep ticket number, customer, location, status, joined time, wait/queue information, notes, cancellation and review actions inside the card. Vendor-confirmed arrival remains its own state inside the card.
- Preserve repository refresh signals, pull-to-refresh, barcode data and cancellation behavior.

## Booking details

- Use the same centered app bar, vendor hero, pass card and dividers as queue tickets.
- Keep booking and payment statuses distinct. Show schedule, services/quantities, notes, deadlines and vendor rejection/expiration reasons within the card.
- Retain payment QR enlargement, private receipt submission, reference input and vendor review messages.
- Fetch details on opening and every 15 seconds while the page is current and the app is foregrounded. Refresh immediately on app resume. No booking push hook is claimed.
- Serialize requests; retain the last successful data and the payment form on temporary errors. A proof submission invalidates any older fetch result to prevent restoring an unpaid form.
- Cancel the timer and remove the lifecycle observer when the page is disposed. Covered pages and background sessions make no periodic requests.

## Verification and limits

Flutter analysis passed. All 301 tests passed, including called-alert placement/content, title centering, shared hero, booking status polling, payment-draft retention on failures, background/covered-page handling, disposal and stale-fetch protection after evidence submission.

The signed main Runner Profile build succeeded, passed signature verification, and was installed and launched on Zero32 Domain. Physical visual/live vendor acceptance remains pending. Tests use fake booking APIs and do not submit live bookings or payment evidence.

KanbanFlow synchronization is pending: browser access to kanbanflow.com was denied because its admin-enforced policy could not be verified. Pending update: add these UI/polling changes and verification evidence to M28, preserve its In Progress status and existing labels/estimates, and keep remaining payment/lifecycle acceptance open.

## Web-reference refinement

The further mobile refinement uses the supplied confirmed and canceled web booking screenshots as visual references:

- Color-coded booking and payment badges remain separate, above vendor/location information.
- A schedule panel shows the complete date/time range, elapsed duration, service count and total fee. Parallel services use the earliest start/latest end; bundled snapshot prices are summed without multiplying quantities again. A single-service fallback multiplies its unit price once. Group-funded totals use the campaign target plus adjustment.
- Booked service cards show compact square, tappable thumbnails, individual time ranges, recorded fees and quantity badges. Missing images omit the thumbnail; current location catalogue images supplement booked snapshots without replacing recorded prices or times.
- Customer name/phone, notes and pending/expiry information stay in the booking card. Payment has its own card for upload, vendor review, verified/rejected proof, receipt reference/name and review reason.
- View payment proof obtains a fresh HTTPS signed URL through the existing authenticated customer endpoint on each tap. Loading prevents duplicate requests; failures offer retry. No public storage URL is constructed and authentication headers are not sent to the image host.
- Both cards remain mounted while scrolling so payment drafts survive scrolling back to the hero. Existing foreground polling, refresh error retention and stale-request protection remain intact.

Analysis and all 304 tests passed, including phone layout, bundled pricing, fallback quantity pricing, private proof retry/viewer navigation and the existing refresh/payment draft tests. The signed main Runner Profile build passed signature verification and was installed and launched on Zero32 Domain. No live proof or vendor decision was submitted. Physical visual and end-to-end acceptance remain pending; cancellation and linked ticket navigation remain separate lifecycle work.

KanbanFlow access remains blocked by admin-policy verification. Pending M28 update: add this refinement and private proof viewing, remove private proof viewing from remaining implementation work, record the 304-test verification, and retain In Progress with outstanding lifecycle/device acceptance work.

### Booking heading spacing

Removed the heading modifier's automatic 40-pixel top margin between the vendor hero and booking reference. The reference uses the same heading typography directly, retaining the card's normal 20-pixel content padding. Analysis and all six booking presentation/live-refresh tests passed. The signed main Runner Profile build passed signature verification and was installed on Zero32 Domain. Include this small spacing correction in the pending M28 refinement update.

## Alert, linked queue ticket and customer arrival

The booking next-step alert is above the booking card. When the server returns a linked ticket, the alert offers an action to its existing native Ticket Details screen, using the booking's vendor/location and ticket lookup code. Both Lists → Bookings and newly created bookings wire this navigation; returning refreshes the booking.

Customer arrival follows the web/backend contract in `booking-arrival` and the local `origin/main` account route: authenticated POST `/api/account/bookings/:id/arrival`. The button says `I’ve arrived` only for confirmed/rescheduled bookings with `customerSelfCheckInEnabled: true`, no expiry/check-in/ticket, and within the inclusive 15-minute-before/after window based on the root `scheduledStartAt`. Required manual payment must be `paid` or have `paymentVerifiedAt`, matching server rules. Missing opt-in fails closed. Early, staff-only, payment-blocked and late states explain availability; a foreground clock updates the label. The server remains authoritative for ownership, payment, window and queue capacity.

Duplicate arrival requests are blocked. Starting arrival invalidates older polls; successful arrival applies the returned booking and exposes its ticket link. Errors retain details and refetch to reconcile a lost response or concurrent staff check-in before retry. Both polling and the clock stop on disposal; covered/background pages do no periodic work.

Analysis and all 309 tests passed, including inclusive boundaries, root-vs-bundle schedules, vendor/payment/status gates, duplicate suppression, stale-fetch protection, alert placement/link arguments, failure/retry and clock transitions. The final copy/countdown refinement also passed analysis and all five arrival tests. The signed main Runner Profile build passed signature verification and was installed on Zero32 Domain. Tests use fake APIs; no production booking arrival was submitted. Physical end-to-end vendor acceptance remains pending.

KanbanFlow remains inaccessible because browser admin-policy verification failed. Pending M28 update: add top alert, linked native ticket navigation and customer arrival; record verification; retain In Progress for cancellation and physical lifecycle/payment acceptance.
