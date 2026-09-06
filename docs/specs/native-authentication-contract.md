# Native authentication contract

Date: 2026-08-28  
Scope: iOS-first Flutter customer app, with Android-compatible contracts.  
Authority: shared GetPrio authentication/session services; mobile-only OAuth handoff is the only new auth boundary currently justified.

## Contract decisions

- Flutter uses bearer authentication for API calls. It does not persist or depend on browser cookies and does not send a bearer token together with a cookie.
- The access token is short-lived and held in memory only. The refresh token is stored in iOS Keychain through a Flutter secure-storage abstraction; it is never logged, placed in a URL, included in push data, or stored in ordinary preferences.
- Password registration, password login, refresh, logout, `/me`, password recovery, password change, and TOTP MFA reuse the shared `/api/auth` and `/api/account` routes. Do not duplicate these routes under `/backend/mobile/`.
- OAuth uses the system browser and a verified app/universal link. The browser returns a short-lived one-time authorization code, never access or refresh tokens. Flutter exchanges the code over HTTPS for the same bearer response used by password auth.
- Ordinary customer MFA is optional. When a customer enables TOTP, mobile sign-in must honor it; privileged-role MFA remains server-enforced. Recovery codes are one-time fallback factors.

## Shared bearer transport

For `POST /api/auth/register/customer`, `POST /api/auth/login`, `POST /api/auth/refresh`, and `POST /api/auth/mfa/verify`, Flutter sends:

```http
X-Auth-Compatibility: bearer-v1
Content-Type: application/json
```

The existing server only includes `token` and `refreshToken` when that header is present and bearer compatibility is enabled ([`authRoutes.js:173-190`](/Users/carloabella/Projects/getprio/dev/backend/src/routes/authRoutes.js:173)). The response is the shared `AuthResponse`: `token`, `refreshToken`, `user`, and `sessionExpiresAt`; `csrfToken` may also be present for browser compatibility and is ignored by Flutter ([`shared/types.ts:1470-1476`](/Users/carloabella/Projects/getprio/dev/shared/types.ts:1470)).

Every authenticated mobile request uses:

```http
Authorization: Bearer <access-token>
```

Bearer-only requests bypass the browser-cookie CSRF branch, while the auth middleware rejects a request that presents both bearer and cookie authentication ([`auth.js:9-21`](/Users/carloabella/Projects/getprio/dev/backend/src/middleware/auth.js:9), [`auth.js:38-105`](/Users/carloabella/Projects/getprio/dev/backend/src/middleware/auth.js:38)).

## Registration and password login

### Registration

The mobile customer registration flow uses the email-verification endpoints under
the shared `/api/auth` surface. Call `POST /api/auth/register/customer/otp` with:

```json
{
  "name": "Profile name",
  "username": "customer_handle",
  "email": "customer@example.com",
  "password": "Upper!12"
}
```

`name`, `username`, `email`, and `password` are required. Customer passwords must
contain a special character, at least two numbers, an uppercase letter, and be
6-32 characters long. The response is an email OTP challenge, not an authenticated
session. Verify it with `POST /api/auth/register/customer/otp/verify` using the
challenge ID and six-digit code; only that response returns the bearer session.
`POST /api/auth/register/customer/otp/resend` issues a replacement code for an
active challenge. The app should label `name` as the full name. When a ticket needs
a customer-facing name, use the saved display name first and profile name second.

On success, persist the returned refresh token securely, keep the access token only in memory, retain the returned session expiry, and load the returned user. On `409`, show the server's existing account-conflict message without probing whether a specific email exists.

### Password login

Call `POST /api/auth/login` with `identifier` (email or username) and `password`; the existing route accepts either ([`authRoutes.js:814-915`](/Users/carloabella/Projects/getprio/dev/backend/src/routes/authRoutes.js:814)). Parse the response as a discriminated union:

```json
{
  "mfaRequired": true,
  "challengeToken": "...",
  "expiresAt": "...",
  "methods": ["totp", "recovery"]
}
```

or the normal bearer `AuthResponse`. The shared type defines this union ([`shared/types.ts:1478-1485`](/Users/carloabella/Projects/getprio/dev/shared/types.ts:1478)). Do not treat a successful password check as a signed-in mobile session until the normal response or MFA verification response has been received.

The backend currently emits a login challenge when MFA is enabled for a privileged-role account ([`authRoutes.js:876-895`](/Users/carloabella/Projects/getprio/dev/backend/src/routes/authRoutes.js:876)). Before release, the shared authentication behavior must also challenge an ordinary customer who has voluntarily enabled MFA; otherwise optional customer MFA would protect enrollment but not the next mobile login. This is a shared auth correction, not a reason to create a duplicate mobile login route.

## TOTP MFA

### Login verification

Call `POST /api/auth/mfa/verify` with `challengeToken` and either `code` or `recoveryCode`. The challenge expires after five minutes and is limited to five failed attempts ([`mfaFlowService.js:31-43`](/Users/carloabella/Projects/getprio/dev/backend/src/services/mfaFlowService.js:31), [`mfaFlowService.js:177-205`](/Users/carloabella/Projects/getprio/dev/backend/src/services/mfaFlowService.js:177)). A successful response is a bearer `AuthResponse` when the compatibility header is present.

The client must:

- show a six-digit authenticator-code field and a separate recovery-code path;
- clear the challenge on success, expiry, or terminal failure;
- never store the TOTP secret or recovery codes in analytics/logs; and
- handle `MFA_CODE_INVALID`, `MFA_CHALLENGE_EXPIRED`, and `MFA_CHALLENGE_USED` as recoverable sign-in states with clear retry instructions.

### Enrollment, replacement, and disable

Authenticated Flutter calls reuse:

- `POST /api/auth/mfa/enrollment/start` — returns a secret and `otpauth://` URI;
- `POST /api/auth/mfa/enrollment/confirm` — accepts the current TOTP code and returns recovery codes;
- `POST /api/auth/mfa/enrollment/cancel` — discards pending setup; and
- `POST /api/auth/mfa/disable` — requires the primary password plus TOTP or recovery code.

The routes are authenticated and their current behavior is implemented in [`authRoutes.js:973-1041`](/Users/carloabella/Projects/getprio/dev/backend/src/routes/authRoutes.js:973). The enrollment service encrypts the secret at rest, activates it only after code verification, marks the current session MFA-verified, and revokes other sessions when a factor is enrolled or replaced ([`mfaFlowService.js:46-108`](/Users/carloabella/Projects/getprio/dev/backend/src/services/mfaFlowService.js:46)). A privileged role cannot disable required MFA ([`mfaFlowService.js:116-127`](/Users/carloabella/Projects/getprio/dev/backend/src/services/mfaFlowService.js:116)).

The app should display recovery codes once, require an explicit “saved” acknowledgement before leaving the success state, and make clear that losing all factors requires account recovery/support.

## OAuth deep-link flow

The current shared OAuth start/callback flow validates signed state, exchanges the provider code, creates or finds the user, creates a session, sets browser cookies, and redirects to `APP_BASE_URL/oauth/callback` ([`authRoutes.js:439-512`](/Users/carloabella/Projects/getprio/dev/backend/src/routes/authRoutes.js:439), [`oauthService.js:46-75`](/Users/carloabella/Projects/getprio/dev/backend/src/services/oauthService.js:46)). That is browser-oriented and cannot be used by Flutter as-is.

### Mobile contract

Add a narrowly scoped mobile OAuth handoff under `/backend/mobile/`, while reusing the shared provider configuration, state validation, provider exchange, user creation, and session services:

1. Flutter generates a cryptographically random `state` and PKCE verifier, derives an S256 `code_challenge`, and opens the system browser at `GET /api/mobile/auth/oauth/{provider}/start?intent=login&state={state}&code_challenge={challenge}`. `provider` is `google` or `facebook`; the existing provider availability endpoint remains shared.
2. The mobile start route accepts only configured intents (`login` and `register_customer`), uses a server-configured allowlisted verified redirect URI, binds the client state and PKCE challenge to server-side OAuth state, and redirects to the existing provider authorization flow. The client must not be able to select an arbitrary redirect URI.
3. The shared server callback performs provider exchange and account creation. For mobile state, it creates a short-lived, single-use authorization handoff record and redirects to the configured verified app/universal link with only `code` and the original `state`. On error it returns an error code/message without tokens.
4. Flutter verifies that the returned state equals the pending state, then calls `POST /api/mobile/auth/oauth/exchange` with `{ "code": "...", "codeVerifier": "...", "state": "..." }`.
5. The exchange endpoint consumes the handoff once, validates the verifier and state, and returns the shared bearer `AuthResponse` or the shared MFA challenge response. It never returns a refresh token in the redirect URL.

The exact verified HTTPS universal-link host is deployment configuration, not a hard-coded product domain. iOS Associated Domains must be configured for it; Android App Links can use the same contract later. A custom URL scheme may be retained only as a development fallback, never as the sole production trust mechanism.

If OAuth completion produces a customer with an enabled TOTP factor, the mobile handoff must issue the same five-minute MFA challenge before returning a bearer session. The provider proves identity; it does not bypass the customer's configured second factor.

## Password recovery and password change

Reuse `POST /api/auth/password-reset/request` and `POST /api/auth/password-reset/confirm`. The request response is deliberately generic even when no account exists; the existing reset token expires after 30 minutes by default and the reset operation revokes every active session ([`authRoutes.js:1070-1139`](/Users/carloabella/Projects/getprio/dev/backend/src/routes/authRoutes.js:1070), [`passwordResetService.js:17-24`](/Users/carloabella/Projects/getprio/dev/backend/src/services/passwordResetService.js:17), [`passwordResetService.js:81-117`](/Users/carloabella/Projects/getprio/dev/backend/src/services/passwordResetService.js:81)).

The existing reset link opens the web login route with a `resetToken`. Sprint 1 may complete the reset in the hosted web screen opened by the system browser; after success, return the customer to mobile login. Do not copy the reset token into analytics or logs. A verified password-reset universal link can be added later without changing the confirm API.

For a signed-in password change, reuse `POST /api/account/password` with `currentPassword` and `newPassword`. The current backend revokes all sessions and tells the customer to sign in again ([`accountRoutes.js:903-925`](/Users/carloabella/Projects/getprio/dev/backend/src/routes/accountRoutes.js:903)). Flutter must clear both in-memory and secure-stored tokens after a successful change.

## Session lifecycle

- The current default access-token TTL is 15 minutes. Customer refresh sessions default to 30 days, with a seven-day inactivity window; both are server configuration and the response's `sessionExpiresAt` is authoritative ([`env.js:20-41`](/Users/carloabella/Projects/getprio/dev/backend/src/config/env.js:20), [`sessionService.js:43-72`](/Users/carloabella/Projects/getprio/dev/backend/src/services/sessionService.js:43)).
- On app launch, if no access token is in memory but a refresh token exists, call `POST /api/auth/refresh` once and atomically replace the stored refresh token with the rotated value. Never send the old token again after a successful rotation.
- Before retrying an API request after `401`, use one single-flight refresh operation, then retry the original request once. If refresh returns `REFRESH_ALREADY_ROTATED`, reload secure storage and retry the refresh once so concurrent app requests can converge. If it returns `REFRESH_REUSE_DETECTED` or another terminal `401`, clear local auth and require sign-in.
- `POST /api/auth/logout` sends the refresh token in the JSON body. The server revokes that session and returns success; Flutter clears local tokens even when the network call fails after the user confirms logout ([`authRoutes.js:1141-1171`](/Users/carloabella/Projects/getprio/dev/backend/src/routes/authRoutes.js:1141)).
- On `403 MFA_ENROLLMENT_REQUIRED` or `MFA_VERIFICATION_REQUIRED`, route to the required security flow rather than treating the account as signed out. This server enforcement applies to privileged roles; ordinary customer MFA remains optional but honored when enabled ([`auth.js:81-94`](/Users/carloabella/Projects/getprio/dev/backend/src/middleware/auth.js:81)).

## Error mapping and privacy

| Response | Mobile behavior |
| --- | --- |
| `400` | Show field or flow validation; never retry blindly. |
| `401` | For an authenticated request, attempt one refresh; for login/MFA, show invalid or expired credentials/challenge. |
| `403` | Handle required MFA or deny access without exposing protected data. |
| `409` | Show account conflict, already-used challenge, or refresh race according to the error code. |
| `423` | Show temporary account lockout and do not keep retrying the password. |
| `503` | Mark the OAuth provider unavailable and offer password sign-in when configured. |

Do not record passwords, access tokens, refresh tokens, OAuth codes, PKCE verifiers, MFA secrets, recovery codes, reset tokens, or full provider profiles in logs, crash reports, analytics, or push payloads. Redact authorization headers and query strings before diagnostic reporting.

## Release gates

Before mobile auth is considered ready, verify on an iPhone with a production-like HTTPS backend:

- registration and email/username login produce bearer sessions with no cookie dependency;
- access refresh rotates securely and survives app restart through Keychain storage;
- logout, password change, password reset, and expired sessions cannot reuse old tokens;
- TOTP enrollment, login verification, recovery-code use, replacement, disable, and required-role enforcement behave as specified;
- Google and Facebook OAuth return through the verified link, reject state/PKCE mismatch and replay, and never expose tokens in the URL; and
- provider cancellation, invalid credentials, lockout, offline state, and backend errors produce recoverable mobile states.

No new mobile endpoint is justified for password auth, refresh, logout, profile, password recovery, or MFA. The only mobile-specific backend surface specified here is the OAuth handoff/exchange; the ordinary-customer MFA challenge behavior is a shared authentication correction required to make the settled optional-MFA decision meaningful.
