import 'package:url_launcher/url_launcher.dart';

class PaymentReturn {
  const PaymentReturn({required this.reference, this.providerStatus});

  final String reference;
  final String? providerStatus;

  factory PaymentReturn.parse(Uri uri, {required Set<String> allowedHosts}) {
    final hosts = allowedHosts.map((host) => host.toLowerCase()).toSet();
    final reference =
        uri.queryParameters['reference'] ?? uri.queryParameters['paymentRef'];
    if (uri.scheme != 'https' ||
        !hosts.contains(uri.host.toLowerCase()) ||
        reference == null ||
        reference.trim().isEmpty ||
        uri.fragment.isNotEmpty) {
      throw const PaymentReturnException(
        'This payment return link is not trusted.',
      );
    }
    return PaymentReturn(
      reference: reference,
      providerStatus: uri.queryParameters['status'],
    );
  }
}

class PaymentReturnException implements Exception {
  const PaymentReturnException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class PaymentBrowser {
  Future<bool> open(Uri checkoutUrl);
}

class ExternalPaymentBrowser implements PaymentBrowser {
  @override
  Future<bool> open(Uri checkoutUrl) =>
      launchUrl(checkoutUrl, mode: LaunchMode.externalApplication);
}
