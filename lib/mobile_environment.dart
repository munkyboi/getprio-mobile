enum GetPrioEnvironment { production, sandbox, unknown }

class MobileEnvironmentConfig {
  const MobileEnvironmentConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.approvedHosts,
  });

  static const productionApiHost = 'api.getprio.online';
  static const sandboxApiHost = 'sandbox-api.getprio.online';
  static const productionAppName = 'GetPrio Mobile';
  static const sandboxAppName = 'GetPrio Sandbox';

  final GetPrioEnvironment environment;
  final String apiBaseUrl;
  final String approvedHosts;

  factory MobileEnvironmentConfig.fromCompileTime() =>
      MobileEnvironmentConfig.fromValues(
        rawEnvironment: const String.fromEnvironment('GETPRIO_ENVIRONMENT'),
        rawFlavor: const String.fromEnvironment('FLUTTER_APP_FLAVOR'),
        apiBaseUrl: const String.fromEnvironment('GETPRIO_API_BASE_URL'),
        approvedHosts: const String.fromEnvironment('GETPRIO_APPROVED_HOSTS'),
      );

  factory MobileEnvironmentConfig.fromValues({
    required String rawEnvironment,
    required String rawFlavor,
    required String apiBaseUrl,
    required String approvedHosts,
  }) {
    final sandboxFlavor = rawFlavor == 'sandbox';
    final environment = switch (rawEnvironment) {
      '' when sandboxFlavor => GetPrioEnvironment.sandbox,
      '' => GetPrioEnvironment.production,
      'production' when sandboxFlavor => GetPrioEnvironment.unknown,
      'production' => GetPrioEnvironment.production,
      'sandbox' => GetPrioEnvironment.sandbox,
      _ => GetPrioEnvironment.unknown,
    };

    return MobileEnvironmentConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl.isEmpty && sandboxFlavor
          ? 'https://$sandboxApiHost'
          : apiBaseUrl,
      approvedHosts: approvedHosts.isEmpty && sandboxFlavor
          ? sandboxApiHost
          : approvedHosts,
    );
  }

  bool get isSandbox => environment == GetPrioEnvironment.sandbox;

  String get appName => isSandbox ? sandboxAppName : productionAppName;

  String get expectedApiHost => isSandbox ? sandboxApiHost : productionApiHost;

  Set<String> get approvedHostSet {
    final hosts = approvedHosts
        .split(',')
        .map((host) => host.trim().toLowerCase())
        .where((host) => host.isNotEmpty)
        .toSet();
    final baseHost = Uri.tryParse(apiBaseUrl)?.host;
    if (baseHost != null && baseHost.isNotEmpty) hosts.add(baseHost);
    return hosts;
  }

  String? get configurationError {
    if (environment == GetPrioEnvironment.unknown) {
      return 'GETPRIO_ENVIRONMENT must be production or sandbox and match the selected build flavor.';
    }

    if (apiBaseUrl.isEmpty) {
      if (!isSandbox) return null;
      return 'Sandbox API URL is missing. Launch with '
          '--dart-define=GETPRIO_API_BASE_URL=https://$sandboxApiHost.';
    }

    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.scheme != 'https') {
      if (!isSandbox) return null;
      return 'Sandbox builds must use https://$sandboxApiHost.';
    }
    if (isSandbox && uri.host != sandboxApiHost) {
      return 'Sandbox builds must use https://$sandboxApiHost.';
    }
    if (!isSandbox && uri.host == sandboxApiHost) {
      return 'Production builds must not use https://$sandboxApiHost.';
    }
    return null;
  }
}
