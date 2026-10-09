import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Match bundled artwork to the effective theme, including System appearance.
class GetPrioArtwork {
  const GetPrioArtwork._();

  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static String logo(BuildContext context) => _dark(context)
      ? 'assets/branding/logo-dark.svg'
      : 'assets/branding/logo.svg';

  static String login(BuildContext context) => _dark(context)
      ? 'assets/branding/login-biometric-scene-dark.png'
      : 'assets/branding/login-biometric-scene.png';

  static String emptyTickets(BuildContext context) => _dark(context)
      ? 'assets/illustrations/dashboard-empty-dark.png'
      : 'assets/illustrations/dashboard-empty.png';

  static String vendorCover(BuildContext context) => _dark(context)
      ? 'assets/illustrations/hero-queue-scene-dark-transparent.png'
      : 'assets/illustrations/hero-queue-scene-transparent.png';
}
