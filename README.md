# GetPrio Mobile

Customer-facing Flutter app for GetPrio queue flows.

The app uses [`shadcn_flutter`](https://pub.dev/packages/shadcn_flutter) for its UI layer and is currently focused on the iOS-first customer MVP:

- Home dashboard
- Explore vendor directory
- QR-code queue joining entry point
- Lists with active/historical tickets and customer bookings
- Account, notification, security, and MFA entry points

The navigation shell and customer queue foundation are in `lib/main.dart`. The app uses bearer authentication, QR resolution, authenticated queue joins, hosted-payment recovery, FCM registration, and REST refetches after queue push signals. Platform credentials and deployment-specific callback/host values remain environment setup documented in `docs/setup/`.

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

For a configured run, provide the API origin and approved QR/payment hosts:

```bash
flutter run \
  --dart-define=GETPRIO_API_BASE_URL=https://api.example.com \
  --dart-define=GETPRIO_APPROVED_HOSTS=app.example.com
```

Firebase, FCM, OAuth callback, verified-host, and backend migration setup is documented in [`docs/setup/mobile-runtime-configuration.md`](docs/setup/mobile-runtime-configuration.md).

Product decisions and implementation contracts are kept in [`CONTEXT.md`](CONTEXT.md) and [`docs/`](docs/).

## Customer booking work

The approved flow, implementation boundary, and remaining release work are in [the mobile booking plan](docs/specs/mobile-booking-plan.md). This work targets the main GetPrio app, using the iOS `Runner` scheme and production API configuration on Zero32 Domain. The native booking flow is under development; manual payment evidence and complete lifecycle actions remain pending.

## Upcoming API integration work

- [API versioning rollout handoff](docs/specs/api-versioning-rollout-handoff.md) — implemented local `/api/v1` client and backend overlap, with production `1.0.2+4`, separate Sandbox identity/version sequence, and deployment/device verification still pending.
- [Ticket invitation blocking handoff](docs/specs/api-ticket-invitation-blocking-handoff.md) — accepted v1 mobile scope; implementation and backend dependencies pending.

For this booking branch on Zero32 Domain, run the main app without a Sandbox flavor:

```bash
flutter run --profile -d 00008110-000A04301E2B801E \
  --dart-define=GETPRIO_ENVIRONMENT=production \
  --dart-define=GETPRIO_API_BASE_URL=https://api.getprio.online \
  --dart-define=GETPRIO_APPROVED_HOSTS=api.getprio.online,getprio.online
```
