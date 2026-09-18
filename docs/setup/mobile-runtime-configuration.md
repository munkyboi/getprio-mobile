# Mobile runtime configuration

The Flutter client is intentionally configured through build-time values. Do not commit production URLs, Firebase private credentials, OAuth secrets, or payment credentials.

## Required build values

```bash
flutter run \
  --dart-define=GETPRIO_API_BASE_URL=https://api.example.com \
  --dart-define=GETPRIO_APPROVED_HOSTS=app.example.com,enterprise.example.com \
  --dart-define=GETPRIO_APPLE_SIGN_IN_ENABLED=true
```

`GETPRIO_API_BASE_URL` is the trusted GetPrio API origin. `GETPRIO_APPROVED_HOSTS` is the comma-separated HTTPS host allowlist used by QR and payment-return parsing. The scanner never opens a scanned URL.
`GETPRIO_APPLE_SIGN_IN_ENABLED=true` enables the native iOS Apple button only after
the backend Apple credentials and Apple Developer capability are ready. It should
remain false or omitted in builds that have not completed that setup.

### Physical iPhone testing when debug mode disconnects

If the terminal reports `Lost connection to device` with no Dart exception,
inspect the iPhone's crash report before changing widgets. On Zero32 with iOS
26.6 and Flutter 3.47.1, the September 5 reports contained `EXC_BAD_ACCESS`,
`SIGBUS`, and code `0x32` in Dart JIT-generated memory. This matches the signature
reported in [Flutter issue #184254](https://github.com/flutter/flutter/issues/184254).
It is distinct from a Dart assertion such as the toast overlay ancestry error.

Use a compiled profile build to test this failure without the debug JIT:

```bash
flutter run --profile -t lib/main.dart -d <iphone-device-id> \
  --dart-define=GETPRIO_API_BASE_URL=https://api.example.com \
  --dart-define=GETPRIO_APPROVED_HOSTS=app.example.com,enterprise.example.com
```

Profile mode does not support hot reload. Rebuild after changing the app. This
is a device-testing workaround, not evidence that the upstream debug-runtime
issue is fixed. Keep the same build-time API values as the original test.

During the September 5 device check, a profile build on Zero32 received two direct
FCM tests with the same message IDs returned by Firebase and successfully opened
the Profile menu through a pointer tap. The check used account `51` and its
current installation token. iOS's `getDeliveredNotifications` also returned both
test notifications, although the person testing did not see a banner. Native
settings reported alerts, sound, Lock Screen, and Notification Center enabled,
with Scheduled Summary disabled. If this recurs, check notification grouping
and Focus on that phone before changing registration or presentation code.
This does not prove that every server-stored registration is current.

## Firebase and push notifications

The app uses Firebase Messaging, but Firebase initialization is non-blocking until platform configuration exists. Add the project-specific files through Firebase tooling:

- iOS: `ios/Runner/GoogleService-Info.plist`
- Android: `android/app/google-services.json`
- iOS Xcode capabilities: Push Notifications and Background Modes > Remote notifications
- APNs authentication key/certificate registered in Firebase
- Backend FCM HTTP v1 credentials: `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, and `FCM_PRIVATE_KEY`

The backend stores one registration per authenticated user and installation. Queue
push payloads are only refresh signals; the app refetches the authoritative ticket
state from the API. Missing permission, a missing token, or an unavailable FCM
configuration must not prevent queue reads, joins, or cancellation.

Do not commit either platform file if the project policy treats them as environment secrets. Test on a physical iPhone; simulator push behavior is not a substitute for APNs validation.

## Verified links and OAuth callback

OAuth uses the one-time callback scheme configured by `MOBILE_OAUTH_REDIRECT_URI`
(default `getprio://oauth/callback`). Register that scheme in the iOS and Android
native projects. Paid queue joins return through the verified HTTPS
`/payment/return` universal link; the app uses the link only to identify the
active payment attempt and always confirms status through the authenticated sync
endpoint.

If the deployment uses an HTTPS universal link for OAuth, configure the selected host in:

- iOS Associated Domains (`applinks:<approved-host>`)
- Android App Links when Android is enabled
- the server-side mobile OAuth/payment redirect allowlist

The exact host remains deployment configuration and must match the platform dashboard allowlist.

Google and Facebook remain available on iOS and Android when the corresponding
providers are enabled by the backend. iOS also offers Sign in with Apple through
the native authorization sheet to satisfy Apple's equivalent-login requirement.

Sign in with Apple is now available on iOS through the native Apple authorization
sheet. A paid Apple Developer Program membership is required, and the Apple
Developer account must enable Sign in with Apple for the app's
App ID, and the backend deployment must provide these secret values through its
environment (never through `--dart-define` or source control):

- `APPLE_CLIENT_ID` — the app's bundle identifier
- `APPLE_TEAM_ID` — the Apple Developer team identifier
- `APPLE_KEY_ID` — the Sign in with Apple key identifier
- `APPLE_PRIVATE_KEY` — the downloaded `.p8` key contents, with newlines preserved

The backend validates Apple's identity token against Apple's rotating JWKS and
exchanges the authorization code before creating a GetPrio session. If users can
choose Apple's private relay address, publish the required SPF record for the
relay email domain. The first authorization supplies the user's name; subsequent
authorizations may omit it, so the backend retains the existing profile name.

## Server dependencies

The mobile client expects the existing shared bearer routes plus these mobile-only surfaces:

- `GET /api/mobile/auth/oauth/{provider}/start`
- `POST /api/mobile/auth/oauth/apple`
- `POST /api/mobile/auth/oauth/exchange`
- `GET /api/mobile/queue-join/resolve?id=<uuid>`
- `POST /api/mobile/queue-join`
- `POST /api/mobile/queue-join/{paymentId}/sync`
- `PUT /api/mobile/push/registrations/{installationId}`
- `DELETE /api/mobile/push/registrations/{installationId}`

The OAuth start route is a browser redirect. The backend returns a short-lived,
one-time exchange code to the app callback and releases access/refresh tokens only
after the app proves the PKCE verifier. The platform dashboard maintains the
approved HTTPS host list used by deployment and QR generation.

Apply the backend migration before starting the app. Vendor location responses now
include `queueJoinId`, `qrJoinUrl`, and the existing human-readable `joinUrl`.
Regenerating a location QR id revokes the old QR id without changing existing
tickets.
