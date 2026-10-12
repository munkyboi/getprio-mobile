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

## Shared AppBar back button — 9 October 2026

GetPrioBackButton provides a consistent circular 48-pixel back action: white background and dark arrow in light appearance, dark card background with visible border and light arrow in dark appearance. It follows the effective theme, including System mode. All AppBar back actions and vendor hero back controls now use this shared component: registration, password recovery, Tickets, Bookings, ticket/booking details, queue joining/scanning, Security/MFA and vendor details. Existing navigation callbacks and detail back keys are preserved.

Verification: Flutter analysis reports no issues and all 62 affected appearance, navigation, booking and ticket-details tests pass. KanbanFlow M28 update pending: record global back-button appearance and this verification, preserving In Progress and remaining work. Browser access remains blocked by the unavailable admin-enforced policy check; no workaround was used.

Device verification: signed production-configured main Runner Profile build passed signature verification, installed and launched on Zero32. Physical light/dark visual acceptance remains pending.

## Queue preview confirmation and service push coordination — 10 October 2026

Reproduced Called-after-confirmation in Home, Lists and Tickets using the actual REST account client and legacy overview payloads. The shared badge/model already presented Confirmed correctly; the account snapshot fallback only handled waiting tickets lacking position. Called tickets with absent canonical confirmation/service keys now resolve a matching live focusTicket. The merge preserves account metadata and copies only present lifecycle/service values. Canonical account payloads (including explicit null values) avoid extra snapshot requests. Failed or wrong-ticket snapshots retain the original ticket rather than inventing confirmation.

Preview coverage now verifies Confirmed and In service in all three destinations. Service push integration tests drive PushCoordinator through CustomerShell and repository refreshes to Home, Lists, Tickets, visible details and History. Event payload status/outcome values cannot override REST state. Completion and interruption move out of Active according to raw served/unserved lifecycle; display labels still use API service outcome/timing. Existing generic push reception already supports these new events without a new whitelist or notification-driven status mutation. Foreground detail polling and app-resume refresh remain fallback paths.

Agreed contract with “Assess multidimensional queue for” (thread 01a100a7-05ba-7fc0-aefd-f0738dca3b4e), explicitly authorized by the customer: eventType customer_queue_service_started / customer_queue_service_completed / customer_queue_service_interrupted; notificationId; route ticket; ticketRef lookupCode (fallback ticket id). Canonical reads include nullable customerConfirmedAt, serviceStartedAt, serviceEndedAt, serviceOutcome; first-party mobile uses snake_case equivalents. The backend thread owns changed-transition-only pushes after commit, avoiding duplicate generic ending pushes, including service endings on already-terminal queue tickets without rewriting their lifecycle. It is integrating the intent of backend serializer commit 9ecf6838. Push triggers/serializers are not confirmed deployed; that thread will report exact release evidence. Mobile worktree remains separate from its backend checkout.

Verification: 69 affected tests pass (the 63-test affected suite plus six additional preview/boundary cases); Flutter analysis reports no issues. Tests use fake APIs and messaging, not live vendor service actions or APNs/FCM delivery. Release acceptance still needs live backend deployment and physical push/status verification on Zero32.

Device verification: signed production-configured main Runner Profile build passed signature verification, installed and launched on Zero32. Physical confirmation/service status and real push delivery acceptance remain pending.

KanbanFlow access recovered on 10 October 2026. M28's description was updated and visibly verified with this queue preview fix, agreed service push contract/dependency, test evidence, and the earlier pending UI/appearance/keyboard/device updates. Existing historical description, In Progress status, labels, estimate and remaining acceptance work were preserved. This resolves the earlier board-sync blockers; it does not mark backend deployment or physical acceptance complete. Screenshot evidence: /tmp/getprio-m28-service-status-sync.png.

## Upcoming booking check-in label — 10 October 2026

The Lists upcoming booking row displayed raw confirmed status even after arrival/check-in. CustomerBooking now derives the shared list label from API check-in evidence (checkedInAt, linkedTicket or queueTicketId), displaying checked-in for upcoming bookings. Lists and Bookings use the same row. Raw lifecycle grouping, payment badges and terminal statuses are preserved.

Verification: the Lists widget regression failed before the fix and passes afterward. All 21 affected booking, check-in, payment and Lists tests pass, including evidence-source and terminal-status boundaries; Flutter analysis reports no issues. Signed production-configured main Runner Profile build passed signature verification, installed and launched com.getprio.getprioMobile on Zero32. Physical visual acceptance remains pending.

KanbanFlow M28 description was updated and visibly verified, preserving In Progress, previous history, labels, estimates and remaining release work. Screenshot evidence: /tmp/getprio-m28-booking-check-in.png.

## Barcode inversion reverted — 10 October 2026

The customer reported that inverted dark-mode queue ticket barcodes were unreadable by scanners. Restored the original dark ink bars on a white background for Light, Dark and System appearance. Barcode data, size and surrounding appearance remain unchanged. This supersedes the earlier dark barcode inversion requirement.

Verification: all 16 affected ticket-details and appearance tests pass; Flutter analysis is clean. KanbanFlow M28 was updated and visibly verified while preserving In Progress, labels, estimates, history and remaining acceptance work. Screenshot: /tmp/getprio-m28-barcode-revert.png. Physical scanner acceptance remains pending.

Device verification: signed production-configured main Runner Profile build passed signature verification, installed and launched com.getprio.getprioMobile on Zero32.

## White barcode section — 10 October 2026

Expanded the white background to the entire queue-ticket barcode section: instruction, barcode, verification code and surrounding padding. Dark ink text/bars are explicit in all appearance modes. DetailPassCard supports an optional full-width footer clipped to its rounded bottom corners; booking cards retain their existing padding. Ticket cancellation/review actions keep their original order and themed background.

Verification: all 23 affected ticket-details, appearance and booking UI tests pass; Flutter analysis is clean. Signed production-configured main Runner Profile build passed signature verification and installed/launched on both Zero32 and wirelessly connected Zero32 Domain. Physical visual/scanner acceptance remains pending. KanbanFlow M28 updated and visibly verified, preserving history, In Progress, labels, estimates and remaining work. Screenshot: /tmp/getprio-m28-white-barcode-section.png.

White barcode section follow-up: removed the dashed divider immediately above it, retaining 20 pixels of space and the other ticket separators. All 11 ticket-detail tests pass; Flutter analysis is clean. This is a small visual follow-up to the preceding M28 barcode section update; include it in the next significant board synchronization.

Follow-up device verification: signed main Runner Profile build installed and launched on Zero32 and Zero32 Domain. Physical visual acceptance remains pending.

## Barcode modal and temporary brightness — 10 October 2026

Tapping the queue ticket barcode opens a modal with a blurred backdrop and white rounded panel. Code 128 bars are 160 pixels high with dark ink, white quiet space and the verification code (lookup code fallback). Close, outside tap and navigator dismissal preserve the ticket. The panel scrolls in short viewports.

Application brightness uses screen_brightness 2.1.11 (https://pub.dev/documentation/screen_brightness/latest/screen_brightness/ScreenBrightness-class.html), temporarily setting 1 while visible. Close/dispose and background restore system brightness or an existing application override; resume boosts while the modal remains open. Native calls are serialized so a delayed read/boost is followed by restoration after disposal. Brightness failures do not prevent display/dismissal. No permanent system brightness setting is changed.

Verification: all 20 affected viewer, ticket-details and appearance tests pass; analysis is clean. Tests cover actual ticket barcode tapping/data, close and outside dismissal, white/dark barcode rendering, backdrop blur, background/resume, prior override restoration, delayed reads after close and brightness failure. KanbanFlow M28 description updated and visibly verified, including the preceding dashed divider removal; In Progress, history, labels, estimates and remaining release work preserved. Screenshot: /tmp/getprio-m28-barcode-viewer.png. Physical brightness/blur/scanner acceptance remains pending.

Device verification: signed main Runner Profile build with production API configuration passed signature verification, installed and launched on Zero32 and Zero32 Domain. The native screen-brightness plugin compiled through the existing Flutter Swift Package integration.

## Personal Info drawer backdrop — 10 October 2026

Enabled shadcn_flutter's built-in transformBackdrop on the Profile Personal Info drawer, applying the zoom-out effect from the drawer example (https://sunarya-thito.github.io/shadcn_flutter/#/components/drawer). Other drawers retain their current behavior. All 20 Profile/appearance tests pass; analysis is clean. Physical animation/keyboard acceptance remains pending. Include this small visual refinement in the next significant M28 synchronization.

Device verification: signed main Runner Profile build passed signature verification and installed on Zero32 and Zero32 Domain. Launch succeeded on Zero32; Zero32 Domain launch was denied because the device is locked.

## All drawers zoom-out backdrop — 10 October 2026

All 12 app drawer entry points now explicitly enable transformBackdrop, extending the Personal Info effect to Appearance/Profile settings, vendor content/contact, booking, queue joining, favorites, reviews and service descriptions. This supersedes the preceding Personal Info-only scope. Drawer contents, constraints, dismissal and form behavior remain intact.

Verification: all 52 affected Profile, appearance, vendor social, mobile booking, location/join, email, keyboard and navigation tests pass; analysis is clean. Signed production-configured main Runner Profile build passed signature verification. KanbanFlow M28 updated and visibly verified, preserving history, In Progress, labels, estimates and remaining work. Screenshot: /tmp/getprio-m28-all-drawer-zoom.png. Physical animation/keyboard acceptance remains pending.

Device verification: main Runner Profile build installed and launched successfully on Zero32 and Zero32 Domain.

## Global grabber/title spacing — 10 October 2026

All 12 drawer entry points use shared openAppDrawer (lib/navigation/app_drawer.dart). It uses the public shadcn openRawDrawer/DrawerWrapper APIs with gapAfterDragger: 0, preserving theme options, drag/dismiss settings, constraints and the zoom-out backdrop. Additional title top padding is zero for Booking, Appearance and service descriptions, matching the existing shared Profile/social/checkout/vendor header padding. The standard space above the grabber remains intact.

Verification: all 52 affected Profile, appearance, vendor social, booking, join/location/email, keyboard and navigation tests pass; Flutter analysis is clean. KanbanFlow M28 updated and visibly verified, preserving history, In Progress, labels, estimates and remaining release work. Screenshot: /tmp/getprio-m28-drawer-gap.png. Physical spacing/keyboard acceptance remains pending.

Device verification: signed production-configured main Runner Profile build passed signature verification, installed and launched successfully on Zero32 and Zero32 Domain.

## Global bottom drawer styling — 10 October 2026

All bottom drawers share AppDrawerTitle with the Personal Info h3 typography. The shared grabber-to-title gap is now 8 pixels, superseding the zero-gap entry above. Drawer header close buttons are removed. Inner vendor contact, operating-hours and checkout backgrounds now match the Personal Info drawer background in Light/Dark/System; other drawers inherit that shared theme background. The zoom-out backdrop remains enabled.

Booking now allows swipe/backdrop dismissal and navigator dismissal while idle. Its former close-button draft-discard confirmation is removed along with the close button; durable interrupted drafts remain pending. Submission still blocks navigator popping while busy. Full-screen image/barcode modal close controls are unchanged.

Verification: all 52 affected Profile, appearance, social, booking, join/location/email, keyboard and navigation tests pass; Flutter analysis is clean. Signed production-configured main Runner Profile build passed signature verification, installed and launched on Zero32. Zero32 Domain wireless installation failed with a tunnel timeout; one retry acquired a connection but also timed out, so installation/launch of this update on that device is unverified. Physical visual/keyboard/dismissal acceptance remains pending.

KanbanFlow M28 updated and visibly verified, preserving In Progress, full history, labels, estimates and remaining release work. Screenshot: /tmp/getprio-m28-bottom-drawer-style.png.

## Obscured OTP and automatic verification — 10 October 2026

All numeric OTP fields use the shadcn_flutter Obscured Example display, with six masked digits in 3–3 groups (https://sunarya-thito.github.io/shadcn_flutter/#/components/input_otp). Shared GetPrioOtpInput uses one shadcn TextField editor underneath the InputOTP display, retaining numeric filtering, a six-digit limit, paste, autofill hints, deletion and accessible obscured input. Direct per-digit InputOTP editing produced incorrect pasted values during testing; its initialValue also does not reset existing digit state, so the read-only display remounts when the shared controller changes. The pinput dependency is removed.

Completion dismisses the keyboard and invokes the existing server verification flow once per edited complete code. Registration, sign-in MFA, Profile email changes, phone changes, MFA enrollment/replacement/removal, queue joining and booking all use this behavior. Password-required phone changes/MFA removal submit only if their password is already entered; otherwise the existing manual action completes the form. Recovery codes remain separate text inputs. Partial codes, unchanged complete codes and disabled/busy/expired inputs do not auto-submit. Manual buttons remain available for retrying rejected codes. Booking completion continues through the existing verified booking creation and manual-payment continuation.

Verification: all 340 tests pass; Flutter analysis is clean. Shared tests cover obscured display/editor, autofill configuration, pasted filtering/length limits, incomplete/duplicate completion, clear/edit/re-completion, validation reset and disabled/narrow layouts. Flow tests cover automatic registration/Profile/MFA/queue/booking progression and duplicate booking prevention. Previously stale drawer-close test expectations now use backdrop dismissal. Signed production-configured MAIN Runner Profile build passed signature verification, installed and launched on Zero32 and Zero32 Domain. Physical OTP autofill/interaction and live server acceptance remain pending; tests use fake APIs.

KanbanFlow M28 updated and visibly verified, preserving In Progress, full history, labels, estimates and remaining release work. Screenshot: /tmp/getprio-m28-obscured-otp.png.

## Centered OTP alignment — 10 October 2026

Shared GetPrioOtpInput now centers the intrinsic-width masked display and its editor together, instead of allowing stretched form constraints to align digits to the left. Labels are centered too. Applies to Scan to join, email verification, booking and every other shared OTP flow; paste/autofill and automatic verification remain intact.

Verification: all 40 affected OTP/queue/Profile/registration/booking/MFA tests pass; the two shared OTP tests also pass after adding a horizontal center-coordinate assertion. Flutter analysis is clean. Signed production-configured MAIN Runner Profile build passed signature verification, installed and launched on Zero32 and Zero32 Domain. Physical visual acceptance remains pending. KanbanFlow M28 updated and visibly verified, preserving In Progress, history, labels, estimates and remaining work. Screenshot: /tmp/getprio-m28-centered-otp.png.

## Rotating pre-confirmation barcode — 11 October 2026

MAIN customer ticket details request authenticated server barcodes for active tickets only, before customer confirmation and before service starts/ends. TicketBarcodeState owns the token and deadline shared by the white card footer and enlarged blurred modal. Both show the same barcode and countdown, refresh after expiry and stop rotating when canonical confirmation/lifecycle fields change. Status polling continues while the barcode modal is open. Confirmed/history ticket references and Sandbox retain their existing non-rotating display.

Agreed with the GetPrio v1 thread “Assess multidimensional queue for”: POST /api/v1/account/queue/tickets/{ticketId}/barcode (empty JSON body) returns barcodeToken (QB plus 32 uppercase hexadecimal characters), issuedAt, expiresAt and serverNow. Tokens have a 120-second server-clock lifetime; repeated reads before expiry return the same token. Issuance checks ownership, production environment and lifecycle. The vendor scanner validates expiry under existing confirmation locks, rejects static-code bypass for enrolled active/unconfirmed tickets and rejects replay after confirmation. Guest/unenrolled legacy flows remain supported by that API contract. Sandbox issuance is out of scope.

Mobile validates response shape/lifetime, uses server-relative TTL minus the request round trip and a monotonic elapsed clock. No eligible ticket falls back to its static reference if issuance fails. Expired tokens disappear in both views, with retry available; automatic retries occur while foregrounded. Backgrounding clears the token and invalidates pending responses; resume refetches. Confirmation, disposal and ticket changes invalidate late requests.

Verification: all 349 mobile tests pass; Flutter analysis is clean. Tests cover exact expiry/shared views, offline expiry and retry, background/resume, deduplicated loading, malformed/overlong tokens, authenticated versioned routing, lifecycle exclusions and confirmation while the modal remains open. Signed production-configured MAIN Runner Profile build passed signature verification, installed and launched on Zero32 and Zero32 Domain. Backend API/scanner implementation is being verified in the coordinating thread; merge/deployment and physical live scanner acceptance remain pending. Until that endpoint is deployed, eligible production tickets show barcode unavailable rather than an insecure fallback.

KanbanFlow M28 updated and visibly verified, preserving In Progress, full history, labels, estimates and remaining work. Screenshot: /tmp/getprio-m28-rotating-barcode.png.

API review follow-up: issuance persists rotating enrollment, so the request uses POST rather than GET. Response/token/TTL semantics are unchanged. The mobile transport test asserts POST, empty JSON and JSON content type. All 24 affected barcode/API/viewer/details tests pass, Flutter analysis is clean and the signed production-configured MAIN Runner Profile build passed. API/scanner PR: https://github.com/munkyboi/getprio/pull/369; review fixes include this method change and rotating credentials in the authenticated web view. Merge, deployment and live scan acceptance remain pending.

POST follow-up device verification: signed MAIN Runner Profile build passed signature verification, installed and launched on Zero32 and Zero32 Domain. KanbanFlow M28 records the method correction and PR #369 review/deployment dependency. Screenshot: /tmp/getprio-m28-barcode-post.png.

## Conservative barcode expiry across sleep — 11 October 2026

Follow-up to API/scanner PR #369 review: the shared mobile controller now keeps wall-clock and monotonic deadlines and displays the shorter remaining lifetime. Request latency subtracts the larger elapsed duration from the two clocks. Thus an OS sleep that pauses the monotonic clock cannot extend the displayed credential. A backward wall-clock change invalidates the credential until fresh issuance; the old token cannot reappear while that refresh is pending. Existing background/resume clearing, generation guards and shared card/modal state remain intact. POST and response semantics are unchanged.

Verification: all 28 affected API/state/viewer/details tests pass; Flutter analysis is clean. Four new regressions cover sleep with paused monotonic time, request latency during sleep, backward clock change with an existing token and backward change during issuance. Signed production-configured MAIN Runner Profile build passed. Backend PR #369 is under review and remains unmerged/undeployed; physical live scan and real device sleep acceptance remain pending.

Clock follow-up device proof: signed MAIN Runner Profile build passed signature verification, installed and launched on Zero32 and Zero32 Domain. KanbanFlow M28 updated with the dual-clock guards and verification, preserving In Progress/history/labels/estimates. Screenshot: /tmp/getprio-m28-barcode-sleep.png.

## Rotating credential scan sizing and offline validity — 11 October 2026

The 34-character rotating payload is rendered as a compact plain black-on-white QR rather than a horizontally compressed Code128. Ticket card QR is 180px square with 24px white quiet padding; enlarged modal targets 240px square with 32px quiet padding and shrinks uniformly to its available width. Both continue using one token/countdown/deadline state. Existing non-rotating confirmed/history/Sandbox references retain Code128. The vendor scanner in API/scanner PR #369 supports QR with the same QB token payload; POST contract is unchanged.

A loaded still-valid token remains visible after an offline refresh fails, until its conservative expiry. Expired tokens remain hidden without a static fallback; pending-response lifecycle guards, pause/resume refetch and retry remain. Added an explicit offline validity regression and a 320px light/dark QR layout test using the actual 34-character payload. All 30 affected API/state/viewer/details tests pass; Flutter analysis is clean. Physical camera scan/quiet-zone acceptance remains pending alongside backend merge/deployment.

QR follow-up device proof: signed MAIN production-configured Runner Profile build passed signature verification, installed and launched on Zero32 and Zero32 Domain. KanbanFlow M28 updated with QR sizing/offline verification, preserving history, In Progress, labels and estimates. Screenshot: /tmp/getprio-m28-barcode-qr.png.

## GetPrio branded queue ticket QR — 11 October 2026

All queue-ticket credential displays now use shared BrandedTicketQr, including non-rotating references and the standalone enlarged viewer. It adds the existing GetPrio monogram in a small white center patch and an orange border, with black modules, white quiet space and high QR error correction. Card targets180px and modal up to240px; the logo patch is18% of the inner QR width. The finder patterns and quiet zone remain unobstructed. This supersedes the preceding non-rotating Code128 presentation. Payload/rotation eligibility, shared token/deadline, offline validity and modal brightness behavior are unchanged.

Verification: all28 affected viewer/details/state tests pass; Flutter analysis is clean. Existing narrow320px light/dark tests now check branding in both synchronized QR views; standalone viewer tests check branded QR for legacy data. Actual rendered card and modal previews with the34-character production-format mock token both decode to that exact token using Apple Vision VNDetectBarcodesRequest. Preview files: /tmp/getprio-branded-qr-card.png and /tmp/getprio-branded-qr-modal.png. These are synthetic local QR previews, not live credentials. Signed production-configured MAIN Runner Profile build passed signature verification, installed and launched on Zero32 and Zero32 Domain. Physical vendor-camera acceptance and API/scanner PR#369 merge/deployment remain pending.

KanbanFlow M28 updated and visibly verified, preserving In Progress, history, labels and estimates. Screenshot: /tmp/getprio-m28-branded-qr.png.

## Smooth QR dialog and ticket perforations — 11 October 2026

Queue ticket QR rendering now uses pretty_qr_code with PrettyQrSmoothSymbol, high error correction, explicit black modules/white quiet space and the existing SVG GetPrio logo in a small white center patch. Removed the inline QR/footer section. A60px bottom-right circular QR action opens the dialog. The dialog always uses the light theme and full white background, without a surrounding card or QR frame. It fits the QR to the available width up to560px and scrolls in short viewports. Close/back dismissal and existing serialized maximum application brightness/restoration remain.

Token state now starts when the QR dialog opens and is disposed when it closes. The main ticket screen does not issue/renew QR tokens. It continues existing ticket status refresh while visible and while the QR dialog is open, so canonical confirmation/cancellation/service transitions update the dialog state. Dual-clock expiry, latency compensation, offline validity, stale response guards, pause/resume refetch and no static fallback for eligible unconfirmed tickets remain. The dialog alone owns the QR renewal lifetime; reopening issues/refetches the current server token.

Queue ticket cards use optional segmented rendering around DetailPassDivider: transparent semicircular cut-outs and outlined arcs at both edges meet the dashed separator. Other DetailPassCard consumers retain their layout. Existing cancellation/review actions remain below details. Extra list bottom padding keeps content clear of the floating action.

Verification: all356 mobile tests pass; Flutter analysis is clean. A regression checks no token requests during three minutes on the ticket screen, one request on dialog open, no renewal after close and fresh issuance on reopening. Existing tests cover dialog confirmation updates, narrow light/dark QR rendering and brightness restoration/races. Synthetic390px dark ticket and light dialog previews were visually checked; Apple Vision decoded the smooth logo-overlaid QR to the exact34-character mock token. Preview screenshots use Flutter test fonts and are not physical device UI evidence. Signed production-configured MAIN Runner Profile build passed signature verification, installed and launched on Zero32 and Zero32 Domain. Live camera/brightness/visual acceptance remains pending. API/scanner contract is unchanged; coordinating thread has verified#369/#370 deployed.

KanbanFlow M28 updated and visibly verified, preserving In Progress/history/labels/estimates. Screenshot: /tmp/getprio-m28-pretty-dialog.png.


## Hide arrival QR after confirmation — 11 October 2026

Queue ticket details omit the QR action after canonical customerConfirmedAt is set, and guard against opening the dialog for confirmed tickets. An open QR dialog listens to the shared ticket state and dismisses its own route after server confirmation, restoring application brightness and disposing the token controller. Existing push-triggered refetch and 15-second details polling deliver the confirmation; camera capture alone does not close the dialog. Failed confirmation leaves the dialog usable. The rotating API contract remains unchanged.

Verification: all357 mobile tests pass; analysis is clean; signed MAIN production-configured Profile build succeeds. Regressions cover confirmation closing the dialog/hiding the action, already-confirmed details without a QR action, and automatic dismissal restoring prior brightness while preserving the underlying route. Physical scan-to-dismiss timing acceptance remains pending.


## Check-in countdown label — 11 October 2026

Booking details show days, hours and minutes remaining until the15-minute-before-start check-in window, e.g. Check-in available in5days4hrs15mins (with spaces between units in UI). Whole minutes round up, zero units are omitted and singular units use day/hr/min. Button text is centered, including wrapped labels. All6 check-in tests and Flutter analysis pass; signed production-configured MAIN Profile build succeeds. Physical visual acceptance remains pending.


## Booking card cut-outs — 11 October 2026

Booking details enable the shared DetailPassCard ticket cut-outs. Each dashed divider has transparent semicircular notches on both card edges, matching queue ticket details in light/dark appearance. All17 affected booking presentation, live refresh, check-in and payment tests pass; analysis clean. Physical visual acceptance remains pending.


## Global keyboard focus and scrolling — 11 October 2026

App-wide touch-outside unfocus covers text/password/textarea/OTP editors without clearing values. Removed twice-keyboard-height per-field spacing, reduced shared scroll margin from96px to24px, removed duplicate Explore/Profile/booking keyboard padding, and made bottom drawer content consume the keyboard inset already reserved by DrawerWrapper. Focus correction is minimal, ignores blurred editors, and leaves tall textarea caret visibility to Flutter. Source audit: keyboard-focus-audit.md. All365 tests pass; analysis clean; signed MAIN production-configured Profile build succeeds. Physical interaction review of every screen remains pending.


### Branded MFA setup QR — 11 October 2026

MFA enrollment now renders through shared `BrandedQrCode` using pretty_qr_code, smooth black modules, a standard white quiet zone, high error correction and the centered GetPrio SVG logo. Queue ticket rendering delegates to the same component with its existing sizes and test keys. MFA stays at up to220 logical pixels and shrinks to its available width; QR surface stays white in light/dark mode. The API-provided otpauth URI is passed through unchanged, and manual-key/copy and OTP confirmation remain available. Removed the now-unused barcode_widget/barcode dependency. Light/dark MFA regressions check payload, renderer, branding and manual key; all367 tests pass and analysis is clean. Signed MAIN production Profile build succeeds and is installed/launched on Zero32. Physical authenticator-camera enrollment acceptance remains pending; no live MFA enrollment was initiated for verification.


### Queue ticket card/history refinement — 12 October 2026

All ticket details use the vendor business name as the card heading with an inline status badge and location subtitle; Customer now appears before the first dashed/cut-out separator. History status alerts omit live queue metrics and currently-serving text; served tickets use exactly “This ticket has already been served.” Other terminal outcomes retain their accurate messages. The QR FAB and its open handler exclude inactive/history tickets. Active unconfirmed tickets retain their QR action.

History details replace Estimated wait with Total waiting time, calculated from joinedAt to authoritative serviceStartedAt in elapsed whole minutes. Missing or reversed timestamps show Unavailable; confirmation and service completion timestamps are not substitutes for service start. Active ticket estimates retain their current behavior. Regressions cover served history with a live snapshot, all terminal QR states, heading/badge/location/customer placement and invalid historical timing. All373 tests pass; analysis clean; signed MAIN production Profile build verified, installed and launched on Zero32. Physical visual acceptance remains pending. No backend or live ticket records changed.


### Ticket grid, duration format and spacing — 12 October 2026

Actual waiting time now uses compact hours/minutes, e.g. 1hr20mins (displayed with a space between units), with singular/plural units and zero-hour omission. Ticket number and Customer share equal columns with a vertical divider. A solid divider separates the vendor subtitle from that grid. Detail values, including Joined and Total waiting time, share equal left-aligned value columns and semibold weight. Page bottom padding is20px when the QR FAB is absent; the100px clearance remains only when it is visible.

Coordinated with Assess multidimensional queue for and inspected deployed backend commit1a5ec189: accountRoutes.js exports serviceStartedAt and createdAt, consumed by the mobile joinedAt??createdAt parser; queueSnapshotHelpers.js exports serviceStartedAt and joinedAt. No serializer gap was found. Service timing defaults off, and legacy served transitions can finish tickets without a recorded start; migration preserves historical unknown starts. This explains how Unavailable can arise. The user's specific production ticket records were not inspected, so null service starts for those exact records remain unconfirmed. Missing actual waits are not fabricated from called, confirmed or served times; no API/data changes made.

All374 tests pass and analysis is clean, including duration boundaries, grid geometry, consistent value alignment/weight and reduced history padding. Signed MAIN production Profile verified, installed and launched on Zero32. Physical visual acceptance remains pending.


### Friendly completion alert — 12 October 2026

A ticket opened while active now displays “Thank you for your business! We hope to see you again soon.” after authoritative served status or completed service outcome arrives. Tickets opened from history retain “This ticket has already been served.” Interrupted and other terminal outcomes retain their existing messages. Completed tickets omit live queue stats and QR actions. Fresh completed account data cannot be overwritten by a delayed waiting/live queue snapshot.

Two regression tests cover completion during 15-second polling from the snapshot and from account history while the snapshot remains waiting. All376 tests pass; final29 ticket details/QR viewer tests pass and analysis is clean. Signed MAIN production Profile build verified and installed on Zero32. Physical live completion acceptance remains pending; no production tickets modified.

### Zero32 live completion acceptance — 12 October 2026

Tested the MAIN customer app on Zero32 against Berdugo Barber Salon → Ayala Center Cebu, as authorized by the user. BB002 reproduced a separate stale post-join banner: the ticket became Served but the original “You are in the queue” notice remained. Completed tickets now replace that notice with the thank-you alert, without duplicating the lower status alert. Snapshot/account completion regressions now exercise the post-join route and assert the original notice disappears.

All376 tests pass and analysis is clean. The corrected signed production Profile build was verified, installed and launched on Zero32. Fresh BB003 stayed on its original Ticket Details screen through called, arrival confirmed and served transitions. At the first observation approximately25 seconds after the vendor's Serve customer action, Served and the thank-you alert were already visible behind the optional rating prompt. Dismissing “Do it later” exposed the updated details; no reopening, navigation away or manual refresh was needed. The QR dialog also closed automatically after arrival confirmation. Proof: /tmp/getprio-zero32-completion-automatic.png and /tmp/getprio-zero32-completion-passed.png.

This verifies automatic live refresh, without isolating push from polling. Service timing was disabled, so this used Serve customer rather than the timed Start/Complete service workflow. QR arrival confirmation used the exact displayed token through the dashboard's manual input; physical camera scanning was not tested. The unused BB001 walk-in test ticket was cancelled; BB002 and BB003 remain served audit records. After verifying no waiting/current ticket, the test queue was closed with zero carry-over, expired, unserved or skipped recovery outcomes. Cleanup proof: /tmp/getprio-zero32-completion-vendor-closed.png.

### Preserve ticket details and pause idle updates — 12 October 2026

Reproduced a confirmed/in-service ticket reverting to its original Waiting state and exposing the QR FAB when the next snapshot omitted focusTicket. Refresh now starts from the last successful ticket rather than the original route argument. Failed manual and repository-signal refreshes no longer replace the displayed future with an errored future; the last successful ticket and vendor remain visible with an update-error message. Vendor profile metadata is fetched once successfully per details visit, preserving imagery and removing repeated directory requests. Successful vendor loading is retried if the first attempt failed. The user's suspected production rate-limit trigger was not independently confirmed from network evidence.

Ticket and booking details share a five-minute inactivity timer. Touch/scroll interaction postpones the timeout; automatic polling does not. At timeout, detail polling stops issuing requests, ticket repository refresh signals are ignored, and a top inline alert explains the pause with a Refresh and resume action. Successful manual refresh resets the timer and enables polling; failed refresh keeps the pause and previous data. Booking resume-from-background also respects the pause, and its per-second UI clock stops rebuilding while paused. This pauses detail requests, not unrelated app-level refresh or QR credentials explicitly opened in the QR dialog.

All379 tests pass; final24 ticket tests pass after strengthening vendor-cache coverage; Flutter analysis is clean. Regressions cover omitted focus data, simulated429 failures/manual refresh, retained QR eligibility, one successful vendor request, five-minute pause, interaction postponement, no idle requests, failure staying paused and successful refresh restarting both detail loops. Signed production MAIN Profile build succeeds and passes signature verification; installed and launched on Zero32 and Zero32 Domain (devicectl JSON evidence /tmp/getprio-idle-zero32-install.json, /tmp/getprio-idle-zero32-launch.json, /tmp/getprio-idle-domain-install.json and /tmp/getprio-idle-domain-launch.json). Physical five-minute inactivity acceptance remains pending; no live ticket mutations were performed for this change.

### Dedicated booking OTP and Manual Payment drawers — 12 October 2026

Booking form submission requests the email challenge and opens a separate Verify email drawer. It owns centered obscured OTP entry, automatic verification/submission on six digits, expiry/resend countdown, errors and booking creation retries using the verified token. The OTP-bound payload is captured before opening; the underlying form stays disabled until verification finishes or Edit booking details returns to it and reloads availability. Busy actions block duplicates. Successful OTP booking creation closes both booking drawers and opens Booking Details; newly created bookings eligible for manual proof automatically open the Manual Payment drawer. Bookings without a proof requirement skip that drawer.

Booking Details no longer embeds the payment form. Its payment section provides a Manual Payment action for eligible bookings, retaining submitted-proof/status summaries otherwise. The shared payment drawer contains destination/account details, amount, tappable QR image with enlarged viewer, reference and receipt submission. Successful submission closes the drawer and updates details, without stale in-flight polling reverting the proof. Authoritative refresh also closes an open payment drawer if proof is no longer eligible. Errors retain the draft while the drawer stays open. Both drawers use shared title/background/grabber styling, zoom backdrop and keyboard-aware scrolling.

All381 mobile tests pass; analysis is clean. Coverage checks separate OTP drawer, immutable bound payload/automatic submission/duplicate blocking, automatic manual-payment continuation and no-payment skip, action-only details with drawer reopening, payment draft retention through errors, live verification closing the drawer, and submitted proof winning over stale polling. Physical drawer/keyboard/QR/receipt flow acceptance remains pending; no live booking/payment submission was made for this change.

Signed MAIN production Profile build for d10f606 verified, installed and launched on Zero32 and Zero32 Domain. Device evidence: /tmp/getprio-booking-drawers-zero32-install.json, /tmp/getprio-booking-drawers-zero32-launch.json, /tmp/getprio-booking-drawers-domain-install.json and /tmp/getprio-booking-drawers-domain-launch.json.

### Grabber-free bottom drawer spacing — 12 October 2026

Shared openAppDrawer adds20px above content/title when a bottom drawer has no visible grabber, either because draggable=false or DrawerTheme.showDragHandle=false. Grabber-present drawers retain the existing8px gap. The library hides its grabber entirely for non-draggable drawers, so both conditions are checked centrally. All22 affected drawer keyboard/booking/payment tests pass and analysis is clean. Physical spacing acceptance remains pending.

### Manual Payment pinned action — 12 October 2026

Manual Payment drawer now uses a bounded column: expanded keyboard-aware scrolling for the QR/destination/reference/receipt fields, and a separate fixed footer for Submit payment proof. Footer respects the bottom safe area and shares the drawer background; keyboard resizing remains owned by the shared drawer wrapper. Validation, busy/duplicate guards and API submission remain unchanged. All19 affected payment/live detail/keyboard tests pass; analysis clean. Physical footer/keyboard spacing acceptance remains pending.

### Booking form sliding screen — 12 October 2026

Book from Vendor Details now pushes BookingPage on the same SwipeBackPageRoute used by Join queue. A centered bold Plan your visit AppBar and shared Back button replace the drawer title/grabber. Vendor/location context, selection, quantities, availability, contact fields and fixed verification footer are preserved. Scaffold owns keyboard resizing once; the form scrolls above the footer. Back returns to the vendor's selected services. Busy verification prevents exiting the page; OTP remains a separate drawer hosted within the page. Successful creation closes OTP and returns the booking from the screen, then opens Booking Details and eligible Manual Payment continuation as before. This supersedes the earlier booking-form drawer presentation.

All26 focused booking UI/payment/live refresh/global keyboard tests pass and Flutter analysis is clean. Coverage includes actual vendor Book navigation/back with selection retained, phone keyboard/footer geometry, and complete OTP-bound creation returning from the pushed page. Physical sliding-page/keyboard acceptance remains pending; no live booking/payment submitted.

### QR access after detail inactivity — 12 October 2026

Opening and retrying the ticket QR now reconcile authoritative ticket status before token issuance. The five-minute detail pause permits status polling/repository signals while the explicitly opened QR dialog is visible, so vendor confirmation still closes it. Closing the dialog restores the existing latched pause; QR renewal itself does not reset the idle timer. A refreshed ticket that no longer needs arrival confirmation closes the dialog without another token request, including service/terminal transitions. API errors appear in the QR view instead of being hidden behind generic Barcode unavailable wording; successful retry clears the error. Token expiry, offline fail-closed behavior, brightness restoration and dialog-only rotation remain intact.

All49 focused ticket details/QR state/viewer/account repository tests pass; analysis is clean. Timed regression exposed missing status reconciliation on Retry after pause and verifies token recovery plus automatic confirmation dismissal. Another covers a stale paused ticket becoming confirmed before Retry, without further issuance. Simulated transient QR failure recovered even before the fix; the user's exact Zero32 Domain API failure has not yet been captured, so no production rate-limit or authentication root cause is claimed. Direct device reproduction/acceptance remains pending.

Physical follow-up: verified iPhone Mirroring target changed from Zero32 to Zero32 Domain (iPhone13ProMax). Updated MAIN build opened on Domain. Existing called Berdugo/Ayala ticket BB007 displayed a valid QR before inactivity. Left details untouched from10:45:24UTC until the five-minute pause alert appeared (~10:50UTC), then opened the QR and observed a fresh branded token with1:59 remaining. Closed it and verified the pause notice remained; repeated opening successfully displayed the still-valid current token. No ticket status/payment mutations performed. The reported unavailable error did not reproduce on this updated build; transient-error Retry and confirmation dismissal after pause are covered by automated regressions, not a forced live network failure or vendor scan. Evidence: /tmp/getprio-domain-qr-after-idle.png. Zero32 Domain is the requested test target moving forward; do not infer Zero32 proof as Domain proof.

Fresh-join follow-up (12 October 2026): user authorized a new ticket at Berdugo/Ayala. Opened Join queue on Zero32 Domain; the current email code was rejected once, so the user completed verification directly and returned the phone locked on the automatically opened BB010 details screen (~19:02 Manila). Observed this same post-join screen without taps, QR opening, manual refresh or route changes until its five-minute pause alert appeared (~19:07). Mirroring briefly showed Connection Paused on the attempted first tap; resumed mirroring, preserving the app's same paused details route, then opened the QR (~19:08). A fresh branded QR and valid countdown displayed successfully; closing retained the pause notice. Error not reproduced on the current e061067 implementation build. Mirroring reconnection is a limitation of this run, so uninterrupted direct-device interaction remains a separate check. No vendor call/confirmation/service/cancellation actions performed; BB010 left active. Screenshots: /tmp/getprio-domain-fresh-bb010-details.png, /tmp/getprio-domain-fresh-bb010-paused.png, /tmp/getprio-domain-fresh-bb010-qr.png.

### Global transparent scroll-aware AppBars — 12 October 2026

Shared ScrollAwareAppBar now uses a transparent background with no surface blur. Its centered bold title translates upward by its own height in direct proportion to the primary vertical content offset from0 to100px, clipped out completely at100px. Scrolling back restores it. Leading/trailing actions and header bounds stay fixed; hidden titles are excluded from accessibility semantics. Nested and horizontal scroll notifications and inactive page routes do not affect title movement. Ticket Details, Booking Details and Booking form now use a shared ScrollAwareScaffold scope; existing observer-based pages inherit the same AppBar behavior. Image viewers without content scrolling retain their visible title and gain transparency.

All53 affected header/navigation/ticket/booking/keyboard tests pass; Flutter analysis is clean. Light/dark geometry checks cover0/50/100/200px and return to top, plus unchanged Back geometry. Physical visual acceptance pending. No queue/booking/payment changes made.

### Transparent AppBar overlay correction — 12 October 2026

The earlier transparent header still occupied a separate Scaffold row, clipping scrolled content at its bottom edge. All shared AppBar screens now use ScrollAwareScaffold with floatingHeader enabled: header controls stay fixed while the full-height content viewport passes beneath them. ScrollAwareHeaderSpace places initial clearance inside the primary scroll content instead of outside the viewport, preserving initial spacing without a permanent cut-off. Ticket/booking lists and details, registration/recovery/security forms and the booking form use this clearance. The booking vendor/location context now scrolls with its form. Scanner media extends behind the header; the image viewer retains safe header clearance. The existing 100px title animation remains unchanged.

All67 affected header/navigation/details/booking/keyboard/join/scanner tests pass; Flutter analysis and diff checks are clean. Light/dark geometry verifies initial clearance, content passing beneath the fixed header, full-height viewport and unchanged back-button bounds. Signed MAIN production Profile build succeeded, passed signature verification and was installed on Zero32 Domain. Physical visual acceptance remains pending; no ticket/booking/payment mutations performed.
