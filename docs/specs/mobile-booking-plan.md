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

- Private proof viewing, richer review/expiry outcomes, and physical end-to-end vendor payment acceptance. Native payment instructions, reference and proof upload are now implemented.
- Eligible cancellation, linked queue-ticket navigation and complete lifecycle/refund messaging.
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
