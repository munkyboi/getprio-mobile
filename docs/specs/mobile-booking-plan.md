# Customer mobile booking plan

Approved in chat on 9 October 2026. Primary development device: Zero32 Domain.

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
- The booking sheet additionally implements the first part of stage 2: quantities, composed/single-service slots, contact details, OTP request/verify/resend, and creation through the existing account API. Booking/payment statuses are shown separately in the list and read-only details.
- Booking drafts remain in memory while the sheet is open. Closing requires discard confirmation; backdrop and drag dismissal are disabled. Durable interrupted-draft/session recovery is pending.

## Remaining before booking release

- Native vendor payment instructions/QR/bank information, reference/proof upload, private proof viewing, review outcomes and expired/rejected handling.
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
- Signed iOS `Profile-Sandbox` build: succeeded; signature verification passed.
- Installed and launched `com.getprio.getprioMobile.ios.sandbox` on Zero32 Domain.
- Physical UI/autofill and live booking/payment/vendor acceptance still require review. Installation/launch does not constitute those checks.

The first Flutter device build timed out during Xcode build-settings lookup. The successful profile build used Xcode with explicit Sandbox Dart defines. Ignored CocoaPods build files were restored from the release checkout with the same lockfile, and cached plugin source references were relocated using structured Swift property-list editing. No tracked iOS project files were changed.
