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
