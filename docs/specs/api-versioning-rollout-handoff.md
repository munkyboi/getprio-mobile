# First-party API versioning and mobile rollout

Status: implementation in progress, 2026-09-15. Source: Developer API planning task `01a07c3f-6b88-7772-8d98-cb98bf03ed07`.

Implementation completed in this pass: the backend mounts the existing auth,
account, public, billing, platform, vendor, push, queue, OAuth, and mobile push
routers under `/api/v1/*` aliases while retaining the unversioned overlap. The
Flutter transport now versions authenticated requests, uploads, SSE queue
streams, password/session requests, and OAuth start/exchange URLs. No database
or response contract changes were made. Backend mobile contract tests,
middleware normalization tests, a local mounted-app smoke (`/api/v1` OAuth
start returns 400 without query parameters; protected queue and push routes
return 401), Flutter analysis, and the full Flutter test suite pass locally.
Live deployment, production route probes, device acceptance, and removal of the
legacy aliases remain unverified.

## Accepted contract

- Updated first-party clients use `/api/v1/*`. Mobile-specific routes use `/api/v1/mobile/*`.
- Existing shared auth/account routes remain shared under the versioned prefix (for example, `/api/auth/*` becomes `/api/v1/auth/*`, and `/api/account/*` becomes `/api/v1/account/*`). Do not move shared endpoints into the mobile namespace merely because Flutter calls them.
- Mobile-specific `/api/mobile/*` routes become `/api/v1/mobile/*`, including OAuth, queue joining/payment synchronization, and push registration.
- Preserve the current production database and all existing test accounts, vendors, bookings, queues, tickets, billing records, and audit history. Route versioning must not reset, reseed, replace, or discard that data.

| App | Planned version | Mobile-specific API target |
| --- | --- | --- |
| GetPrio production | `1.0.2+4` | `https://api.getprio.online/api/v1/mobile/*` |
| GetPrio Sandbox | Initially `1.0.0+1`, independent sequence | `https://sandbox-api.getprio.online/api/v1/mobile/*` |

The handoff reports the distributed production TestFlight build as `1.0.1 (3)` and the observed local pubspec as `1.0.1+2`. These are handoff observations, not a fresh App Store Connect audit. Reconcile actual build state before future release work. Do not change pubspec or app identity as part of this planning task. Sandbox requires its own app identity; exact identifiers and configuration must be verified during implementation.

## Required rollout order

1. Add and verify the versioned backend routes, with existing authentication, authorization, response contracts, and data preserved. Backend readiness is a prerequisite to mobile distribution.
2. Update and test all affected Flutter request paths and environment configuration. Audit shared APIs as well as mobile-only APIs, avoiding duplicated `/api/v1` prefixes. Verify production and Sandbox cannot accidentally use each other's host or app identity.
3. When separately authorized, distribute production `1.0.2+4` only after versioned-route verification. Sandbox uses its separate identity and version sequence.
4. Allow only the brief rollout overlap needed for controlled testers to update. Record the tester-update evidence and agreed cutoff; no calendar cutoff is invented here.
5. Remove unversioned application routes after that controlled update window. Verify updated clients continue working and production data remains intact. Do not prematurely remove routes still required by the distributed build.

## Mobile acceptance and release dependency

- Exercise registration/login, refresh/logout, password recovery, MFA, account/profile, vendor reads, QR resolve/join, ticket reads/cancellation/history, payment return/sync, and push registration using the versioned contracts.
- Verify cold start, authenticated app resume, OAuth callbacks and notification links on a physical iPhone where appropriate.
- Preserve existing customer identities and records across the update; no account recreation is required merely to change API paths.
- Record backend route verification evidence, mobile test evidence, selected app identity/host/version, controlled-tester update evidence, and unversioned-route removal verification separately. None is established by this handoff.
- M24 (TestFlight delivery) depends on this migration and verified backend routes. M25 (ticket invitation blocking) must use the versioned contract agreed with its backend implementation.
- Track migration as M26 with `Mobile`, `API Integration`, `Sprint 9`, Blue, and an 8-hour estimate. The card is In Progress while local implementation and verification are recorded; keep it open until backend deployment, live route checks, and mobile/device acceptance are complete. M25's current description estimates 6 hours, so the candidate work remains within the 20-hour weekly capacity and normally 16 planned hours plus 4 reserve. M26 must precede M24 distribution; M24 remains blocked pending M23/M26 and release readiness.

## Scope of this handoff

This document records the accepted target and the current implementation
boundary. It does not assert that the aliases are deployed or that a release is
available. Existing documents with unversioned examples describe the prior
overlap contract; update them when their endpoint examples are next revised.
