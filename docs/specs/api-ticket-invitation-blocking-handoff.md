# API ticket invitation blocking — mobile handoff

Status: accepted v1 scope; not implemented or verified. Added 2026-09-11.

## Purpose

Customers can choose “Block invitations from this application” to stop unwanted API ticket invitations. Application means the developer API project, not every application owned by that developer and not a vendor location. Include this behavior in the production GetPrio app and project-isolated sandbox tester app.

## Accepted behavior

- One invitation per ticket; retried API requests do not generate duplicate invitation pushes.
- Apply invitation rate limits per sending project and recipient. Numeric limits remain to specify.
- Provide the mobile blocking action. Enforce the persisted recipient/application preference server-side for future invitation creation and dispatch, not just by hiding notifications locally.
- Blocking does not cancel existing tickets, unlink already accepted tickets, or disable ordinary tracking and queue alerts for those tickets. It blocks future invitations and their invitation pushes from that application.
- Other applications remain unaffected. Sandbox blocks are scoped to the test user, project, and environment; never touch production recipients.
- The API must not expose whether an email has a GetPrio account or reveal the recipient's private blocking preference through a distinct delivery response.

## Dependencies and implementation boundaries

Requires API invitation creation/status, authenticated block preference storage, and backend dispatch enforcement. Routes and exact response schemas remain to finalize; do not invent working endpoints. Reuse existing notification settings, FCM registration, and task UI where suitable. This is new mobile work, not covered by previous push or ticket UI completion.

Customers can unblock an application in Settings. Blocking dismisses its pending invitations, preventing later acceptance without cancelling their underlying tickets. Unblocking allows future invitations only; never restore or resend old dismissed invitations. No reporting/moderation suite is implied. Already dispatched pushes cannot be recalled.

## Acceptance checklist

- [ ] Customer can block the selected application, with clear scope and loading/error feedback.
- [ ] Future invitations and invitation pushes from it are suppressed server-side across the customer's devices.
- [ ] Other applications and existing accepted tickets continue to work.
- [ ] Blocking dismisses pending invitations without cancelling tickets; stale acceptance requests fail.
- [ ] Unblock in Settings allows future invitations without restoring or resending dismissed invitations.
- [ ] Duplicate API retries do not produce repeat invitation pushes; recipient rate limits cannot be bypassed by key rotation.
- [ ] Cross-account/project/environment requests cannot read or change another recipient's preferences.
- [ ] Verify production and sandbox behavior, OS notifications denied, app restart, offline/retry failure, and dispatch/block races.

Planning source: [API mobile linking decisions](../../../dev/.scratch/developer-queue-api/issues/06-mobile-ticket-linking.md).
Backlog: M25 — Block ticket invitations from an application, Product Backlog. Estimate: provisional 6 mobile hours, excluding backend implementation; Sprint 9 candidate sequence, not selected sprint work. Dependencies must be ready before scheduling. No implementation or test results claimed.
