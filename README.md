# GetPrio Mobile

Customer-facing Flutter app for GetPrio queue flows.

The app uses [`shadcn_flutter`](https://pub.dev/packages/shadcn_flutter) for its UI layer and is currently focused on the iOS-first customer MVP:

- Home dashboard
- Explore vendor directory
- QR-code queue joining entry point
- Active and historical tickets
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

Sandbox flavor setup is documented in [`docs/setup/sandbox-mobile-runtime-configuration.md`](docs/setup/sandbox-mobile-runtime-configuration.md).
