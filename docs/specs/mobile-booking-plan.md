# Customer mobile booking plan

Approved in chat on 9 October 2026. Primary development device: Zero32 (`00008120-001A3D101E68C01E`), switched from Zero32 Domain on 9 October 2026.

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

## Appearance and matching booking rows

Profile → Settings now contains Appearance. Its bottom sheet offers Light, Dark and System using phone previews and a selected outline/badge. System is the default and follows device brightness changes. The choice is stored locally through the existing secure-storage dependency; it is independent of the signed-in account and preserved across relaunches. Failed saves retain the prior mode and show an inline retry message. A late preference read cannot overwrite a newer choice.

The root supplies both shadcn themes and changes appearance without recreating API/session repositories. Custom surfaces, borders, text, OTP cells, navigation, headers, detail passes, sheets, service rows and loading placeholders now use shared context-aware colors. Dark mode uses warm dark surfaces, light text and readable status badges; the existing dark logo asset is used on dark surfaces. Barcode/QR scan surfaces retain black codes on white. Brand artwork remains image content rather than being recolored.

The shell’s safe-area top spacing is now 20 logical pixels for Home, Explore, Lists and Profile. Booking rows and queue history rows share the same plain-row component, with a leading icon, details and trailing status/chevron area; booking and payment statuses remain separate. The complete row is an accessible shadcn button, including whitespace, and booking rows retain line separators. Status width is bounded so long labels cannot squeeze the details out on small phones.

KanbanFlow M28 synchronization remains pending: add the Appearance setting, persisted theme behavior, shared booking rows and 20-pixel spacing, plus final verification. Preserve In Progress, estimates/labels and remaining booking lifecycle/physical acceptance work. Browser access is blocked by admin-enforced policy verification.

Verification: Flutter analysis passed and the complete 316-test suite passed. After tightening the late-read guard for an explicit System selection, all seven affected Appearance/navigation tests passed again. The signed main Runner Profile build passed signature verification and was installed and launched on Zero32 Domain. Device screenshots and physical visual/light-dark/relaunch acceptance remain to be checked; tests use a fake preference store and fake APIs. No production review, booking, payment proof or arrival was submitted.

## Dark ticket barcode and Settings ordering

Queue ticket details now invert the barcode surface in effective dark appearance: white bars on black, including when System follows a dark device setting. Light appearance retains the existing dark bars on white. This supersedes the earlier fixed-white queue barcode surface; barcode data, quiet-zone padding and payment/MFA QR images are unchanged. Profile Settings places Appearance directly after Notifications, separated by a divider.

Verification: Flutter analysis and all 30 affected ticket-details, Appearance and Profile tests passed. KanbanFlow M28 update remains pending because the browser cannot verify the admin-enforced access policy; batch these two presentation refinements with the pending Appearance update and preserve In Progress.

The signed main Runner Profile build passed signature verification and was installed and launched on Zero32 Domain. Physical dark-mode barcode viewing/scanning acceptance remains pending.

## Tickets Active/History tabs

Tickets and Bookings now share `ListFilterTabs`, using the same full-width shadcn `Tabs`/`TabItem` styling and selected semantics. Tickets defaults to Active and displays only the selected status group, with separate empty-state messages. Pending invitations appear in Active. Active ticket cards, lightweight history rows, detail navigation, cancellation, retries and pull-to-refresh remain available. Refresh signals retain the selected tab.

Verification: Flutter analysis and all 52 affected widget, ticket-detail, invitation and booking-UI tests passed, including switching both directions and preserving History selection after a repository refresh. KanbanFlow M28 synchronization remains blocked by browser admin-policy verification; add this tab refinement and verification to the pending update, preserving In Progress.

The signed main Runner Profile build passed signature verification and was installed and launched on Zero32 Domain. Physical tab interaction acceptance remains pending.

## Test device switch to Zero32

On 9 October 2026, the user switched the main-app test target to Zero32 (`00008120-001A3D101E68C01E`). The current signed main Runner Profile build, including Active/History ticket tabs, was installed and launched successfully on Zero32. Subsequent device work should use this device; earlier Zero32 Domain verification records remain historical. Physical feature acceptance on Zero32 remains pending.

## Shared Lists ticket rows and service lifecycle presentation — 9 October 2026

Lists Active queue tickets now uses the same TicketListRow as Tickets History, including vendor, ticket number, location, joined date, uppercase status badge, icon and full-row navigation with a chevron. The previous duplicated overview markup is removed.

Checked the API's current mainline service timing contract: Start service retains called and sets serviceStartedAt; Complete service records completed and changes called to served; Interrupt service records interrupted and changes called to unserved with service_interrupted. Queue closure can terminate the queue ticket without ending actual service. Mobile preserves the persisted queue status for grouping/permissions, and presents Confirmed, In service, Completed or Interrupted from timing/outcome fields. Older tickets retain their existing labels; interruption reasons remain readable when timing fields are absent.

The model parses and preserves serviceStartedAt, serviceEndedAt and serviceOutcome through enrichment. Shared badges and Home/Tickets progress use these display states; details show service timestamps and guidance, and suppress the called/arrival alert once service starts. Detail polling runs every 15 seconds only while foreground and the current route, skips overlapping requests and preserves the last successful details on errors. Existing shell polling now runs every 30 seconds while active tickets exist; push and foreground refresh continue.

API dependency: current account overview/history and queue focusTicket omit service progress. A separate additive backend fix is prepared in web-app/worktrees/mobile-ticket-service-fields, branch codex/mobile-ticket-service-fields, exposing nullable timing/outcome fields (snake_case for first-party mobile ticket resources). This fix has not been deployed. Until released, the mobile app can identify interrupted tickets from statusReason but cannot consistently distinguish Confirmed from In service.

Verification: flutter analyze reports no issues; all 318 mobile tests pass, including visible detail polling from In service to Interrupted, lifecycle parsing/copying/legacy fallback, list navigation/filtering, and history scroll retention. All 24 affected API integration/snapshot tests pass and changed backend files pass syntax checks.

KanbanFlow update pending: M28 remains In Progress. Record the shared Lists rows, service lifecycle presentation and refresh behavior, 318 mobile/24 API checks, and the separate API response deployment dependency. Board access is blocked because the admin-enforced browser policy could not be verified; do not bypass its security controls. Remaining lifecycle/release acceptance work stays open.

Device verification: the signed main Runner Profile build with production API defines passed codesign verification, installed and launched as com.getprio.getprioMobile on Zero32 (00008120-001A3D101E68C01E). Live vendor-driven service acceptance remains pending API deployment; installation/launch is not that acceptance. Backend response fix commit: 9ecf6838 (local, not pushed/deployed).

## Dark appearance artwork compatibility — 9 October 2026

Added dark RGBA illustrations for login, Home's empty active-ticket card, and the vendor fallback cover. They preserve the original hand-drawn scenes and orange accents with charcoal shading, ivory outlines and transparent surroundings; the original light-mode assets remain in place. The login dark scene deliberately omits the generated central logo and overlays the existing logo-dark.svg at the original brand position to preserve its exact shape.

GetPrioArtwork centralizes selection from the effective Shadcn theme so Light, Dark and System appearance changes update the graphics immediately. Vendor profile logo placeholders and failed-logo loads use the existing dark SVG; the logo ring also uses a subdued dark-theme border. Directory tiles, ticket details and booking details inherit the shared vendor components. Customer-provided images are preserved.

Assets: assets/branding/login-biometric-scene-dark.png, assets/illustrations/dashboard-empty-dark.png, assets/illustrations/hero-queue-scene-dark-transparent.png. Generated with the built-in imagegen tool; final prompt set is saved in assets/dark-artwork-prompts.md. All three assets are bundled explicitly in pubspec.yaml and verified as 1536x1024 RGBA with alpha transparency.

Verification: flutter analyze reports no issues; all 55 affected tests pass, covering theme switching on login with draft preservation, Home empty artwork, vendor cover/logo fallback selection, appearance controls, ticket details, booking details and navigation.

KanbanFlow update pending for M28: record dark illustrations, theme-aware fallback logos/ring, asset bundling and verification. Keep In Progress and preserve remaining lifecycle/API/release acceptance dependencies. Board access remains blocked because the admin-enforced browser policy could not be verified; no security workaround was used.

Device verification: the signed main Runner Profile build with production API defines passed codesign verification, contains all three dark assets in its Flutter bundle, and installed/launched successfully as com.getprio.getprioMobile on Zero32 (00008120-001A3D101E68C01E). Physical visual acceptance remains with the customer.

## Standard form keyboard resizing — 9 October 2026

Aligned standard forms with the resizing Scaffold + SafeArea + scrollable content pattern. Login retains explicit resizeToAvoidBottomInset true and scrolling with drag-to-dismiss; its redundant inner keyboard inset padding is removed. Registration/email verification and password recovery explicitly enable Scaffold resizing, protect the body with SafeArea below the appbar, and use the shared scroll view without reserving the keyboard height again. Full-screen security/MFA follows the same rule. Security sheets keep the shared keyboard reservation because overlays do not reliably resize.

KeyboardAwareScrollView now has reserveKeyboardSpace (default true for existing overlay consumers), with false reserved for screen bodies already resized by their Scaffold. KeyboardAwareField/Input continue to keep focused inputs within the actual scroll viewport and above the keyboard. Regression coverage checks both resized-screen focus visibility without duplicate padding and unresized-overlay keyboard reservation.

Verification: flutter analyze reports no issues; all 75 affected keyboard, validation, registration, MFA, appearance, booking, social/review and navigation tests pass. KanbanFlow M28 update pending: record standard form resizing/safe-area consistency and duplicate-padding fix with this evidence, retaining In Progress and existing remaining work. Board access is blocked by the unavailable admin-enforced browser policy check; no workaround was used.

Device verification: signed production-configured main Runner Profile build passed codesign verification, installed and launched on Zero32 (00008120-001A3D101E68C01E). Physical keyboard interaction acceptance remains pending customer testing.

## Login repeated-tap scrolling fix — 9 October 2026

Reproduced the reported login issue in phone-sized widget tests with a 300-pixel keyboard: the second tap placed both the identifier and password input above the screen. The login-specific tap handler measured the validated wrapper, including the shared keyboard spacer (675/677 pixels instead of the input's 39/41 pixels), then scrolled the input out of view. Removed that duplicate handler, retry timer and unused private tap forwarding; login and MFA fields retain shared focus visibility handling and native editing/selection behavior.

Regression tests exercise first focus, keyboard opening, repeated taps, filled-input double taps and keyboard dismissal for both login fields. All 50 affected login, biometric, keyboard, validation, appearance, MFA and registration tests pass; Flutter analysis reports no issues. No live authentication requests were made by these tests.

KanbanFlow M28 update pending: record the reproduced oversized-wrapper scroll cause, removed duplicate login handler and 50-test/analysis verification. Keep In Progress and preserve remaining work, labels and estimates. Normal browser access failed because the admin-enforced policy could not be verified; no workaround was used.

Device verification: signed main Runner Profile build with production API configuration passed codesign verification, installed and launched on Zero32 (00008120-001A3D101E68C01E). Physical repeated-tap keyboard interaction remains for customer acceptance; install/launch does not establish interactive device QA.

## Booking list empty card — 9 October 2026

Bookings now matches the Tickets list's empty-state card: a 40-pixel calendar icon, heading and short hint with the same vertical spacing. Upcoming shows “No upcoming bookings” and “Choose a vendor to plan a visit.” History uses the same card with past-booking copy. Existing loading, error/retry and populated-list behavior remain intact; shadcn Card follows the effective appearance theme.

Verification: all seven existing mobile booking UI tests pass and Flutter analysis reports no issues. KanbanFlow M28 update pending: record the matching booking empty-state cards and this verification while retaining In Progress and remaining work. Browser access remains blocked because the admin-enforced policy could not be verified; no workaround was used.

Device verification: signed production-configured main Runner Profile build passed signature verification, installed and launched on Zero32. Physical visual acceptance remains pending.

## List tab spacing and textarea dismissal — 9 October 2026

Tickets and Bookings share listPagePadding (20 left/right/bottom, 10 top), aligning the AppBar-to-tabs gap and preventing drift. Audited every editable multiline field: vendor reviews already explicitly unfocus on outside taps; vendor contact messages now do the same. Both retain their entered text and multiline editing. Contact-message regression coverage reproduced retained focus/visible keyboard before the fix and now verifies outside-tap blur, hidden keyboard, preserved message and successful submission. Existing rating coverage verifies the same dismissal behavior and submission.

Verification: all 54 affected navigation, booking, social/rating and Lists tests pass; Flutter analysis reports no issues. KanbanFlow M28 update pending: record shared list spacing and complete multiline outside-tap dismissal with regression evidence. Preserve In Progress, remaining work, labels and estimates. Browser access remains blocked by the unavailable admin-enforced policy check; no workaround was used.

Device verification: signed production-configured main Runner Profile build passed signature verification, installed and launched on Zero32. Physical spacing and keyboard interaction acceptance remain pending.
