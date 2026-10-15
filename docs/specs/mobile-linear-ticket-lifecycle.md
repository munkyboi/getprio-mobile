# Read-only customer queue lifecycle (#462)

Mobile consumes the API owner's `customer-queue-lifecycle-v1.md` contract from Queue commit `75673a98f2c9cefe2a36090b5a439a79b9edbc49`. This is a read-only presentation projection, not a new command API.

The existing account overview/history (`/api/v1/account/overview`, `/api/v1/account/history`) and public tracking `focusTicket` use `queueLifecycle`. The existing mobile ticket list/detail contract uses `queue_lifecycle`; its snake_case list adapter retains the field. No vendor endpoint access or new mobile detail endpoint is introduced.

A supported value is `{version: 1, state, resourceWait: null}`. Supported states are `waiting`, `called`, `in_service`, `terminal`, `recovery`, and `pending_carry_over`. Mobile preserves the projection through ticket copies and account-to-live enrichment. Shared ticket labels feed Home, Lists, Tickets, quickstats, and details. Existing confirmation and specific completed/interrupted/terminal outcome labels are retained. Explicit unfinished service takes display precedence even if queue closure made raw status terminal; raw status, active/history membership, timestamps, cancellation and arrival eligibility are unchanged. Version 1 identifies a schema and is never used to order refreshes.

Missing, malformed, unknown-version and unknown-state projections fall back to existing ticket presentation. Developer tickets do not claim this projection. Published is a vendor plan state and is not exposed as a distinct issued customer state; mobile must not manufacture that label. No durable customer resource-wait evidence exists: `resourceWait: null` means unavailable, not available capacity or proof that there is no resource wait. No resource reason or countdown is synthesized. Supporting a future non-null reason requires an authoritative expanded contract.

Scope excludes customer ticket creation, service editing, offline behavior, station controls, allocation, and production activation. The existing QR/cancellation commands are not expanded by this change.

## Acceptance boundary

Focused contract/widget checks cover all six projection states and raw terminal outcomes, legacy/unsupported responses, unfinished service during queue closure, metadata copies, camelCase account and live fallback, snake_case list mapping, shared row/quickstats/detail presentation, and existing QR rules.

The canonical local API `:5007` has public lookup proof at commit 75673a98, but populated customer/physical acceptance is blocked: all 23 existing tickets have no linked customer owner, and API5007/UI5187 bind loopback only. Queue owner confirmed these conditions without modifying data. Do not relink any of those tickets or use a vendor token. Populated acceptance needs explicitly scoped new disposable customer-owned fixtures and an approved device-reachable transport, using normal customer authentication. Zero32 is the only authorized device. No physical result, provider delivery, production deployment, or store availability is claimed by local tests.
