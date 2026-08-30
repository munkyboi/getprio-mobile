# Sprint 1 Figma Prototype

## Prototype

- File: [GetPrio Customer Mobile MVP - Sprint 1 Prototype](https://www.figma.com/design/tfI4l98g3VPzB2gxpQYnoc)
- Platform direction: iOS-first Flutter customer app
- Figma file key: `tfI4l98g3VPzB2gxpQYnoc`

## Covered journey

1. Welcome, email/password sign-in, registration, and Google/Facebook OAuth entry points
2. Home dashboard with an upcoming ticket and queue quick actions
3. Explore vendor directory with queue-open and closed capability states
4. Join tab opening directly into the QR scanner, without vendor preselection
5. Free-queue join guidance and paid-queue review before hosted PayMongo checkout
6. Called-ticket status with vendor/location context
7. My Tickets with active and historical tickets
8. Waiting-ticket cancellation confirmation
9. Account profile, display name, queue notification toggle, password/MFA entry, and logout
10. Authenticator-app MFA setup
11. First-run notification permission prompt with a non-blocking “Not now” path

## Handoff rules

- The customer-facing name is the saved display name; profile name is the fallback.
- Join is authenticated-only in the mobile app.
- The QR scanner is the primary Join action and does not require Explore first.
- Free joins can proceed immediately after a valid QR scan.
- Paid joins show the fee and create the ticket only after confirmed hosted checkout.
- Ticket position, ETA, and lifecycle status are server-authoritative.
- Push notifications are optional and should deep-link to the affected ticket, followed by an authoritative REST refresh.

## States still required in implementation QA

The prototype establishes the primary screens and key decision states. Flutter implementation must add loading, empty, malformed-QR, queue-closed, payment-pending, payment-failed, stale-ticket, offline, notification-denied, and API-error states using the same visual language.
