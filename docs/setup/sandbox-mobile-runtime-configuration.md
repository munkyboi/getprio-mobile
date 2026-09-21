# GetPrio Sandbox mobile runtime

The Sandbox build is an isolated flavor of the existing Flutter application. It
must never use production API, deep-link, application-identity, or Firebase
resources.

## Runtime targets

| Setting | Sandbox value |
| --- | --- |
| Display name | `GetPrio Sandbox` |
| Android application ID | `com.getprio.getprioMobile.android.sandbox` |
| iOS bundle ID | `com.getprio.getprioMobile.ios.sandbox` |
| API origin | `https://sandbox-api.getprio.online` |
| Approved link host | `sandbox.getprio.online` |
| Custom URL scheme | `getprio-sandbox` on Android; `getprio-sandbox` on iOS |
| Firebase project | `getprio-sandbox` when provisioned |

## Local run

```bash
flutter run \
  --flavor sandbox \
  --dart-define=GETPRIO_ENVIRONMENT=sandbox \
  --dart-define=GETPRIO_API_BASE_URL=https://sandbox-api.getprio.online \
  --dart-define=GETPRIO_APPROVED_HOSTS=sandbox.getprio.online
```

The Sandbox Dart runtime rejects an empty, non-HTTPS, production, or otherwise
different API origin. Keep the defines explicit in local scripts and CI so a
developer cannot accidentally point a Sandbox binary at production.

## Firebase boundary

The production `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist` are not used by Sandbox builds. Sandbox
Google services processing is enabled only when the separately provisioned
`android/app/src/sandbox/google-services.json` exists. Until the GetPrio-owned
Sandbox Firebase project is provisioned, the app runs without Firebase push
registration and remains usable for non-push local validation.

Do not create placeholder credentials or copy production Firebase files into
the Sandbox flavor. Provisioning and real push/device verification are separate
release gates.
