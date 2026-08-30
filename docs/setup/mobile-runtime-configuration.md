# Mobile runtime configuration

The Flutter client is intentionally configured through build-time values. Do not commit production URLs, Firebase private credentials, OAuth secrets, or payment credentials.

## Required build values

```bash
flutter run \
  --dart-define=GETPRIO_API_BASE_URL=https://api.example.com \
  --dart-define=GETPRIO_APPROVED_HOSTS=app.example.com,enterprise.example.com
```

`GETPRIO_API_BASE_URL` is the trusted GetPrio API origin. `GETPRIO_APPROVED_HOSTS` is the comma-separated HTTPS host allowlist used by QR and payment-return parsing. The scanner never opens a scanned URL.

## Firebase and push notifications

The app uses Firebase Messaging, but Firebase initialization is non-blocking until platform configuration exists. Add the project-specific files through Firebase tooling:

- iOS: `ios/Runner/GoogleService-Info.plist`
- Android: `android/app/google-services.json`
- iOS Xcode capabilities: Push Notifications and Background Modes > Remote notifications
- APNs authentication key/certificate registered in Firebase

Do not commit either platform file if the project policy treats them as environment secrets. Test on a physical iPhone; simulator push behavior is not a substitute for APNs validation.

## Verified links

The OAuth and payment flows require a verified HTTPS universal link. Configure the selected host in:

- iOS Associated Domains (`applinks:<approved-host>`)
- Android App Links when Android is enabled
- the server-side mobile OAuth/payment redirect allowlist

The exact host remains deployment configuration and must match the platform dashboard allowlist.

## Server dependencies

The mobile client expects the existing shared bearer routes plus these mobile-only surfaces:

- `GET /api/mobile/auth/oauth/{provider}/start`
- `POST /api/mobile/auth/oauth/exchange`
- `GET /api/mobile/queue-join/resolve?id=<uuid>`
- `POST /api/mobile/queue-join`
- `PUT /api/mobile/push/registrations/{installationId}`
- `DELETE /api/mobile/push/registrations/{installationId}`

The OAuth start route is documented as a browser redirect, so the client currently opens the provider start URL with `GET`; the backend should preserve that contract while enforcing state, PKCE, and an allowlisted verified redirect.
