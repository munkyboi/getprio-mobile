# Read-only customer queue lifecycle (#462)

Mobile consumes the API owner's `customer-queue-lifecycle-v1.md` contract from Queue commit `75673a98f2c9cefe2a36090b5a439a79b9edbc49`. This is a read-only presentation projection, not a new command API.

The existing account overview/history (`/api/v1/account/overview`, `/api/v1/account/history`) and public tracking `focusTicket` use `queueLifecycle`. The existing mobile ticket list/detail contract uses `queue_lifecycle`; its snake_case list adapter retains the field. No vendor endpoint access or new mobile detail endpoint is introduced.

A supported value is `{version: 1, state, resourceWait: null}`. Supported states are `waiting`, `called`, `in_service`, `terminal`, `recovery`, and `pending_carry_over`. Mobile preserves the projection through ticket copies and account-to-live enrichment. Shared ticket labels feed Home, Lists, Tickets, quickstats, and details. Existing confirmation and specific completed/interrupted/terminal outcome labels are retained. Explicit unfinished service takes display precedence even if queue closure made raw status terminal; raw status, active/history membership, timestamps, cancellation and arrival eligibility are unchanged. Version 1 identifies a schema and is never used to order refreshes.

Missing, malformed, unknown-version and unknown-state projections fall back to existing ticket presentation. Developer tickets do not claim this projection. Published is a vendor plan state and is not exposed as a distinct issued customer state; mobile must not manufacture that label. No durable customer resource-wait evidence exists: `resourceWait: null` means unavailable, not available capacity or proof that there is no resource wait. No resource reason or countdown is synthesized. Supporting a future non-null reason requires an authoritative expanded contract.

Scope excludes customer ticket creation, service editing, offline behavior, station controls, allocation, and production activation. The existing QR/cancellation commands are not expanded by this change.

## Acceptance boundary

Focused contract/widget checks cover all six projection states and raw terminal outcomes, legacy/unsupported responses, unfinished service during queue closure, metadata copies, camelCase account and live fallback, snake_case list mapping, shared row/quickstats/detail presentation, and existing QR rules.

Queue runtime `4e68e794` includes the customer DTO and preserves all 23 original tickets. After explicit coordination, new customer 3 and disposable owned tickets 24 (terminal), 25 (in service), 26 (called), and 27 (waiting) were created without relinking originals. Queue verified normal customer-authenticated account and mobile list/detail reads. This fixture setup does not establish public joining or payment acceptance. Credentials remain in a private local handoff, never source control.

On Zero32, native test builds installed and launched, but both the USB link-local app request and an unauthenticated LAN health probe failed before any HTTP response with iOS `No route to host` (errno 65). The deny-all LAN probe observed no peer connection and was stopped by its owner. No device login, ticket endpoint, or real-data rendering acceptance passed. Wi-Fi address and Local Network permission checks require human device confirmation before another attempt; do not loosen authentication or expose a public tunnel. Zero32 is the only authorized device. No provider delivery, production deployment, or store availability is claimed.

The integration harness is opt-in via a private `--dart-define-from-file`, using approved local preview origins only. Probe mode compiles no credentials and sends one unauthenticated health GET; full mode uses normal customer authentication and only reads approved ticket IDs. A passing probe is not lifecycle acceptance. Restore the normal main app after a device-test run so the phone is not left running the test harness.
