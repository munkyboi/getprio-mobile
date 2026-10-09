# Customer mobile booking plan

Approved in chat on 9 October 2026. Primary development device: Zero32 Domain.

Target: the main GetPrio customer mobile app (`mobile-app` repository, iOS `Runner` scheme). The user clarified that this feature is not being built for the separate Sandbox mobile app. Use the main app identity and production API configuration for subsequent device builds.

## User decisions

- Rename the Tickets bottom destination to Lists, with a grid icon.
- Lists contains two rounded, fully clickable cards: Tickets and Bookings.
- Vendor locations form a single-expanded accordion. The primary location is selected initially, falling back to the first location.
- Expanding a location selects it for Book and Join Queue and highlights its pin/header.
- Expanded content shows the location queue and compact service rows. Add/remove selects services; Info opens an available description.
- Use a two-column Book / Join Queue footer and a native booking bottom sheet.
- Reuse the web booking rules; payments remain subject to manual vendor review.
- Use a shared six-digit OTP input based on the supplied Flutter Component Library reference. Preserve regular text fields for recovery codes.

## Implementation stages

1. Shared OTP input, Lists navigation, location/service UI, booking-only discovery, and physical-device review.
2. Native booking flow using existing location services, quantities, together/sequential scheduling, live availability, contact details, email OTP, and customer booking creation. Add manual payment instructions, reference and private proof upload/view.
3. Complete booking management: cancellation eligibility, linked ticket navigation after vendor check-in, status/payment review and expiry, notifications, and recovery on sign-in/app resume.

Group-funded bookings are deferred. Service selections are cleared when changing locations. Keep one location expanded at all times.

## Current implementation

Branch: `codex/mobile-booking-lists-ui`, based on mobile `origin/main` at `0b9fd23`.

- Shared `GetPrioOtpInput` uses Pinput 5.0.2, six digit boxes, digit filtering, complete-code paste/autofill, external controllers, validation, focus and disabled states. Registration, MFA, account email/phone verification and queue joining use it. Existing queue-join automatic verification remains intact.
- Lists routes to the existing Tickets page and an API-backed paginated Bookings page. Invitation notifications still open Tickets directly.
- Vendor details select the primary location, display only its expanded content, fetch location services, clear selection on switching, and disable queue joins for vendors without queue capability.
- The booking sheet additionally implements the first part of stage 2: quantities, composed/single-service slots, contact details, OTP request/verify/resend, and creation through the existing account API. Booking/payment statuses are shown separately in the list and details. After creation, the details page continues into native manual payment instructions and receipt submission for eligible bookings.
- Booking drafts remain in memory while the sheet is open. Closing requires discard confirmation; backdrop and drag dismissal are disabled. Durable interrupted-draft/session recovery is pending.

## Remaining before booking release

- Richer review/expiry outcomes and physical end-to-end vendor payment acceptance. Native payment instructions, reference, proof upload and private proof viewing are implemented.
- Eligible cancellation and complete lifecycle/refund messaging. Linked queue-ticket navigation and vendor-enabled customer arrival are implemented.
- Booking push delivery/deep links and durable session/interrupted-flow recovery.
- Physical verification of email OTP autofill, photo upload, keyboard/safe areas, application switching and vendor approval/check-in.
- End-to-end verification against the selected backend, with a test vendor and customer. Widget tests use fake APIs and do not submit live bookings or send verification emails.

## Verification

The implementation adds widget tests for OTP filtering/complete-code entry, error reset, disabled/narrow-screen states; Lists routing; primary-location/service selection and clearing; booking list retry/history; and the OTP-bound creation flow. Existing navigation and location tests follow the updated contracts.

Verification on 9 October 2026:

- `flutter analyze`: passed, no issues.
- Full Flutter suite: 290 tests passed.
- After the final closed-queue display adjustment: all 11 affected tests passed.
- Initial device preview only: signed iOS `Profile-Sandbox` build: succeeded; signature verification passed.
- Initial preview installed and launched `com.getprio.getprioMobile.ios.sandbox` on Zero32 Domain.
- Physical UI/autofill and live booking/payment/vendor acceptance still require review. Installation/launch does not constitute those checks.

That initial Sandbox preview preceded the main-app target clarification and is not main-app acceptance evidence.

The first Flutter device build timed out during Xcode build-settings lookup. The successful profile build used Xcode with explicit Sandbox Dart defines. Ignored CocoaPods build files were restored from the release checkout with the same lockfile, and cached plugin source references were relocated using structured Swift property-list editing. No tracked iOS project files were changed.

## Main app target verification after clarification

On 9 October 2026, built the main iOS `Runner` scheme with `Profile`, `GETPRIO_ENVIRONMENT=production`, `GETPRIO_API_BASE_URL=https://api.getprio.online`, and approved hosts `api.getprio.online,getprio.online`. No Sandbox flavor was supplied.

- Signed main build succeeded; `codesign --verify --deep --strict` passed.
- Artifact identity: `com.getprio.getprioMobile`, display name `GetPrio Mobile`; Firebase bundle identity matched.
- Installed and launched the main app successfully on Zero32 Domain.
- All nine environment configuration tests passed.
- This is a local development build, not an App Store/TestFlight release. Physical interaction, live OTP/booking, payment and vendor acceptance remain pending.

## Location accordion scroll correction

On 9 October 2026, corrected location switching after a long expanded service list. The tapped location header is anchored to its viewport position while the previous location collapses, with normal scroll bounds for shorter pages. A phone-size regression test reproduces the displaced header before the fix and passes afterward. All 12 affected booking, location selection and parallax tests passed; Flutter analysis passed. Main Runner Profile build and signature verification passed.

## Manual payment continuation

The report about BKG-B980FDAC exposed the missing post-OTP payment UI. The web/backend contract creates a pending, unpaid request before uploading evidence; creating the record is not vendor confirmation. The specific production record was not read or altered during this fix.

- New requests open details with the required manual-payment continuation; existing eligible unpaid requests can resume from Lists → Bookings.
- Vendor QR or bank/account details and server-owned amount are displayed with a payment reference and private receipt picker.
- JPEG/PNG/WebP receipts up to 8 MB use the existing authenticated direct-upload API, followed by evidence submission using server-returned metadata.
- Payment evidence remains pending vendor review, with separate booking and payment status messages. Duplicate submits are disabled and failed attempts retain the reference and receipt for retry. Expired/canceled/checked-in/group-funded bookings and already-submitted proofs do not offer upload.
- Private proof preview, live payment upload/vendor review acceptance and remaining lifecycle work are still pending.

Verification: Flutter analysis passed; all 295 tests passed. The signed main Runner Profile build passed signature verification and was installed and launched on Zero32 Domain. Payment upload tests use fake APIs; no live receipt, payment or vendor decision was submitted.

## Vendor location and service images

Single-location vendors keep their location content open and omit the accordion chevron and expanded accessibility hint. Multi-location vendors keep the chevrons. Services with an `imageUrl` from the existing public API now show a compact thumbnail that opens a larger pinch-to-zoom image viewer with a close action. Image taps do not add/remove a service; absent images do not leave thumbnail gaps, and failed image loads show a fallback.

Verification: all 13 affected booking/location/parallax tests passed, including image viewer navigation and single/multiple-location chevrons; Flutter analysis passed. Signed main Runner Profile build succeeded and signature verification passed.

## Payment QR enlargement

The manual-payment QR in eligible unpaid booking details is clickable and opens a larger pinch-to-zoom view. Service images and payment QR images share the same viewer. Closing returns to the payment form with its entered reference intact. Bank-only destinations have no QR action. All 12 affected payment/booking UI tests passed; Flutter analysis passed.

## Unified details and live booking refresh

Queue ticket and booking details now share the Vendor Details artwork, centered app bar and single pass-card design. The called-ticket alert is a single sentence above the card, with other details inside. Booking details poll every 15 seconds while visible/foregrounded and refresh on app resume; failed refreshes retain the last data and payment draft, and stale fetches cannot overwrite submitted proof. Full behavior and verification are in `mobile-ticket-booking-details.md`. Flutter analysis passed; all 301 tests passed.

## Service thumbnail sizing correction

Service thumbnail buttons now use zero padding so images fill the full 56 × 56 square instead of being squeezed horizontally. The fallback keeps the same square dimensions; tapping still opens the shared image viewer. Flutter analysis and all seven mobile booking UI tests passed. The signed main Runner Profile build passed signature verification and was installed on Zero32 Domain.

KanbanFlow update remains pending: the browser could not verify the admin-enforced access policy. Add this correction and its verification to M28 alongside the pending unified-details/live-refresh update; preserve the card's In Progress status and other fields.

## Lists grid sizing correction

Removed default button padding around the two Lists cards so each surface fills its grid column, leaving a single 14-pixel gutter. The row stretches both cards to the taller content height, and their icons stay aligned at the bottom even when subtitles wrap. Analysis and all seven mobile booking UI tests passed, including Tickets/Bookings navigation. The signed main Runner Profile build passed signature verification and was installed on Zero32 Domain. Batch this small layout correction into the pending M28 update; board access remains blocked by browser admin-policy verification.

## Shared safe-area top spacing

The shared `GetPrioTheme.safeAreaTopSpacing` token is 10 logical pixels. CustomerShell applies it once inside its system SafeArea, across Home, Explore, Lists and Profile. Page list padding remains shared and unchanged; routed app-bar screens retain their existing header layout. Analysis and all nine navigation/mobile-booking UI tests passed. The signed main Runner Profile build passed signature verification and was installed on Zero32 Domain. Include this styling adjustment in the pending M28 update; the browser admin-policy verification blocker remains unresolved.

## Consistent tab headers

Home, Explore, Lists and Profile now use `TabPageHeader` with the same heading typography, bottom separator, eight-pixel title bottom padding, four-pixel description gap and twenty-pixel content gap. It applies no top margin, so the shell's ten-pixel safe-area spacing is the only extra top offset. This removes the prior heading modifier's hidden forty-pixel margin on Home/Explore/Profile and adds the missing separator to Lists. Analysis and all 33 affected navigation, booking UI, Home and Profile tests passed. The signed main Runner Profile build passed signature verification and was installed on Zero32 Domain. Batch this correction into the pending M28 update while the board access-policy blocker persists.

## Lists, list rows and screen header refinements

- Bookings uses `cupertino_tabbar` 2.0.0 for the requested animated, segmented Upcoming/History control, with separators and selected semantics. The dependency is pure Dart. Booking rows and empty states use plain list styling; rows have dividers, chevrons, schedule and separate booking/payment badges.
- Lists retains its two navigation tiles and adds Active queue tickets and Upcoming bookings sections using plain divided rows. Ticket overview filters active statuses; upcoming requests cover pending, confirmed and rescheduled, follow each status's pagination, deduplicate and sort by scheduled start. Each row opens its native detail screen.
- Lists sections load when selected, refresh from ticket signals/app resume and after returning from details or the full Bookings list. Independent loading/error/retry states retain the last successful rows. Hidden tabs do not start signal-driven requests.
- Shared screen app bars now keep titles bold and centered relative to the whole bar, with back/actions preserved and symmetric title clearance. Detail pass and image viewer headers use this same component.
- Tickets removes the redundant My tickets heading, separator and subtitle; content starts ten pixels below the app bar.
- The booking sheet removes BOOKING, uses heading typography without its automatic forty-pixel top margin, adds eight-pixel header top padding and aligns the close action with the heading area. Draft confirmation and payment/OTP behavior are preserved.

Verification: analysis passed; all 311 tests passed, including tab switching, status pagination/sorting, active-ticket filtering, row navigation and last-data retention after refresh errors. The signed main Runner Profile build passed signature verification and was installed on Zero32 Domain. No production booking, OTP, payment proof or arrival was submitted during verification; physical visual/end-to-end acceptance remains pending.

KanbanFlow synchronization remains blocked because the browser could not verify its admin-enforced access policy. Pending M28 update: add this UI refinement, new Lists data sections and dependency, record verification, and retain In Progress with remaining cancellation and physical end-to-end acceptance work.

## Shared-library tabs and review keyboard dismissal

The Forui request was withdrawn; the app continues using `shadcn_flutter`. Bookings now uses the existing library's `Tabs` and `TabItem` widgets for its full-width Upcoming/History selector, retaining selected semantics, list filtering, pagination and retry. `cupertino_tabbar` has been removed from the manifest and lockfile, superseding the earlier Cupertino tab refinement.

The vendor rating comment explicitly unfocuses on an outside pointer tap, including mobile touch input. This hides the onscreen keyboard and keeps the entered comment and selected stars available for submission. Existing drag-to-dismiss and submit-time dismissal remain. The regression test checks focus and keyboard visibility after tapping the dialog title, draft retention and successful rating submission; it fails without the fix and passes with it.

KanbanFlow M28 update pending: record the tab dependency removal, review keyboard fix and verified checks, retaining In Progress and the existing remaining lifecycle/physical acceptance work. Board access remains blocked because the browser cannot verify its admin-enforced access policy.

Verification: Flutter analysis passed and all 18 affected social/booking UI tests passed. The signed main Runner Profile build passed signature verification and was installed and launched on Zero32 Domain. Review submission used a fake API in tests; physical keyboard interaction and live review acceptance remain to be checked.
