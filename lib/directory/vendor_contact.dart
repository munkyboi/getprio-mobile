import 'package:url_launcher/url_launcher.dart';

abstract interface class VendorContactLauncher {
  Future<bool> openEmail({
    required String recipient,
    required String subject,
    required String message,
  });
}

class ExternalVendorContactLauncher implements VendorContactLauncher {
  const ExternalVendorContactLauncher();

  @override
  Future<bool> openEmail({
    required String recipient,
    required String subject,
    required String message,
  }) {
    return launchUrl(
      Uri(
        scheme: 'mailto',
        path: recipient,
        queryParameters: {'subject': subject, 'body': message},
      ),
      mode: LaunchMode.externalApplication,
    );
  }
}
