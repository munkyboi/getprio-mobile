# iOS MVP Quality, Privacy, and Release Contract

## Test targets

Sprint 1 requires both:

- iOS Simulator for screen sizes, layout, accessibility settings, loading/error states, and repeatable UI tests.
- A physical iPhone for camera QR scanning, universal links, OAuth return, FCM delivery, notification permission, hosted PayMongo return, background/resume, and network transitions.

Simulator-only verification is insufficient for release acceptance.

## Accessibility baseline

- Support Dynamic Type without clipping or overlapping content.
- Support VoiceOver with meaningful labels and logical focus order.
- Maintain at least 4.5:1 contrast for normal text.
- Use touch targets of at least 44 x 44 points.
- Do not communicate queue, payment, or error state by color alone.
- Label QR scanning, ticket position, ETA, cancellation, payment status, and notification settings.
- Verify key flows with Reduce Motion and larger text enabled.

## Privacy and telemetry

The MVP collects only data required for account, queue, ticket, payment, push delivery, and security operations.

- Do not request precise device location, contacts, advertising IDs, raw QR contents, card details, or session recordings.
- Do not include behavioral ad tracking or product analytics in the first release.
- Use only redacted crash and API-error diagnostics for reliability.
- Keep security, payment, and queue audit events server-side.
- Redact names, email addresses, phone numbers, tokens, QR UUIDs, payment references, and other personal data from diagnostic logs.
- Keep telemetry disableable through release configuration.

## Security and data-integrity checks

Before TestFlight acceptance, verify:

- Bearer access tokens are short-lived and refresh tokens remain in platform-secure storage.
- Customer ticket reads and mutations enforce authenticated ownership.
- Tenant and location scope cannot be crossed.
- MFA behavior matches the authentication contract.
- QR host, UUID, slug mismatch, and enterprise-host validation rules hold.
- Duplicate join attempts and payment webhook/sync retries remain idempotent.
- Payment state is never inferred from a client return URL.
- Push payloads contain safe hints only and never secrets or sensitive ticket details.
- No critical queue, payment, auth, privacy, or data-integrity defect remains.

## Offline and lifecycle behavior

- Cache the last successful ticket snapshot for read-only viewing with an “Updated …” timestamp.
- Show a clear stale/offline state.
- Block joins, cancellation, payments, profile changes, and notification-setting changes while offline.
- Refresh the authoritative REST state on app launch, resume, push-tap, and network recovery.
- Securely refresh an expired session or require login again.
- Allow local QR parsing when possible, but require connectivity for resolve and join.

## Release path

- Use local development builds during implementation.
- Use TestFlight for ETEEAP review and physical-device acceptance.
- Defer public App Store release until production domains, OAuth/deep-link configuration, push credentials, privacy disclosures, support contact, payment reconciliation, monitoring, and rollback procedures are verified.

## Sprint 1 acceptance evidence

The Saturday review package must show:

1. Simulator and physical-iPhone test results.
2. Registration, login, password recovery, and optional MFA evidence.
3. Valid QR free join and paid PayMongo return evidence.
4. Pending-payment recovery and duplicate-scan evidence.
5. Ticket view, refresh, called status, and waiting-ticket cancellation evidence.
6. FCM notification deep link and authoritative REST refresh evidence.
7. Offline/resume and network-transition evidence.
8. Accessibility checks for VoiceOver, Dynamic Type, contrast, touch targets, and Reduce Motion.
9. Confirmation that no critical security, privacy, payment, or data-integrity defects remain.

Public App Store publication is not a Sprint 1 acceptance requirement.
