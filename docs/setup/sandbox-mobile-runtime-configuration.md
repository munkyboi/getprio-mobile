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

Android production builds use the explicit production flavor so adding the
Sandbox dimension does not remove the existing production artifact:

```bash
flutter run \
  --flavor production \
  --dart-define=GETPRIO_ENVIRONMENT=production \
  --dart-define=GETPRIO_API_BASE_URL=https://api.getprio.online \
  --dart-define=GETPRIO_APPROVED_HOSTS=getprio.online
```

The Sandbox Dart runtime rejects an empty, non-HTTPS, production, or otherwise
different API origin. Keep the defines explicit in local scripts and CI so a
developer cannot accidentally point a Sandbox binary at production.

## Authentication boundary

Sandbox login, refresh, and logout requests use the versioned private mobile
routes:

```text
/api/v1/mobile/auth/login
/api/v1/mobile/auth/refresh
/api/v1/mobile/auth/logout
```

The Sandbox client does not expose customer registration, email verification,
forgotten-password recovery, OAuth, or MFA flows. It accepts only credentials
for portal-generated project-scoped Sandbox test users. The corresponding
backend routes and server-side project, environment, expiry, session, and
device enforcement must be deployed before real Sandbox credentials can log in.

## Firebase boundary

The production `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist` are not used by Sandbox builds. Sandbox
Google services processing is enabled by the separately provisioned
`android/app/src/sandbox/google-services.json`. The iOS Sandbox target uses
`ios/Runner/Sandbox/GoogleService-Info.plist`, copied into the app bundle as
the default `GoogleService-Info.plist` resource for Sandbox configurations.

Both apps belong to the `getprio-sandbox` Firebase project:

| Platform | Firebase app ID | Package/bundle ID |
| --- | --- | --- |
| Android | `1:47224988144:android:c2e325fdb92f0e02e67d35` | `com.getprio.getprioMobile.android.sandbox` |
| iOS | `1:47224988144:ios:148ea5282d382205e67d35` | `com.getprio.getprioMobile.ios.sandbox` |

The project is currently on the Firebase Spark plan. Never copy production
Firebase files into the Sandbox flavor or commit placeholder credentials.
Provisioning and real push/device verification remain separate release gates.
