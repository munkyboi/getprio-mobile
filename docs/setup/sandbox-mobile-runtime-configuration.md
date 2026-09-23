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

For physical devices running iOS 26, use Profile mode for device validation:

```bash
flutter run \
  --profile \
  --flavor sandbox \
  --dart-define=GETPRIO_ENVIRONMENT=sandbox \
  --dart-define=GETPRIO_API_BASE_URL=https://sandbox-api.getprio.online \
  --dart-define=GETPRIO_APPROVED_HOSTS=sandbox.getprio.online
```

Flutter debug/JIT launches can terminate with `EXC_BAD_ACCESS`/`SIGBUS` on
physical iOS 26 devices. Profile and release builds use AOT and avoid that
toolchain failure; this is not a Sandbox biometric or API configuration issue.

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
`ios/Runner/GoogleService-Info.plist` are not used by Sandbox builds. The
Sandbox Firebase application identifiers are compiled from
`lib/push/firebase_options.dart`, and the separately provisioned native files
may be kept locally at `android/app/src/sandbox/google-services.json` and
`ios/Runner/Sandbox/GoogleService-Info.plist` for native tooling. Those raw
files are ignored by Git; never copy production Firebase files into the
Sandbox flavor.

The backend must also have the `FCM_SANDBOX_PROJECT_ID`,
`FCM_SANDBOX_CLIENT_EMAIL`, and `FCM_SANDBOX_PRIVATE_KEY` deployment secrets.
The deployment workflow keeps those credentials separate from production and
routes Sandbox ticket notifications through the `getprio-sandbox` Firebase
project. Provisioning, deployment, and real push/device verification remain
separate release gates.
