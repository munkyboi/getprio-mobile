import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_queue_api.dart';

class PaymentReturn {
  const PaymentReturn({required this.reference, this.providerStatus});

  final String reference;
  final String? providerStatus;

  factory PaymentReturn.parse(Uri uri, {required Set<String> allowedHosts}) {
    final hosts = allowedHosts.map((host) => host.toLowerCase()).toSet();
    final reference =
        uri.queryParameters['reference'] ??
        uri.queryParameters['paymentRef'] ??
        uri.queryParameters['payment'];
    if (uri.scheme != 'https' ||
        !hosts.contains(uri.host.toLowerCase()) ||
        uri.path != '/payment/return' ||
        reference == null ||
        reference.trim().isEmpty ||
        uri.fragment.isNotEmpty) {
      throw const PaymentReturnException(
        'This payment return link is not trusted.',
      );
    }
    return PaymentReturn(
      reference: reference,
      providerStatus:
          uri.queryParameters['status'] ??
          uri.queryParameters['payment_status'],
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

abstract interface class PaymentLinkSource {
  Stream<Uri> get linkStream;
}

class AppPaymentLinkSource implements PaymentLinkSource {
  AppPaymentLinkSource({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Stream<Uri> get linkStream => _appLinks.uriLinkStream;
}

class ExternalPaymentBrowser implements PaymentBrowser {
  @override
  Future<bool> open(Uri checkoutUrl) =>
      launchUrl(checkoutUrl, mode: LaunchMode.externalApplication);
}

abstract interface class PaymentApi {
  Future<Map<String, dynamic>> sync({
    required String paymentAttemptId,
    required String tenantSlug,
    String? locationSlug,
  });
}

class RestPaymentApi implements PaymentApi {
  RestPaymentApi(this.client);

  final AuthenticatedApiClient client;

  @override
  Future<Map<String, dynamic>> sync({
    required String paymentAttemptId,
    required String tenantSlug,
    String? locationSlug,
  }) {
    return client.post('/api/mobile/queue-join/$paymentAttemptId/sync', {
      'tenantSlug': tenantSlug,
      ...?locationSlug == null ? null : {'locationSlug': locationSlug},
    });
  }
}
