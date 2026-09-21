import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/mobile_environment.dart';

void main() {
  test('sandbox config rejects a production API origin', () {
    const config = MobileEnvironmentConfig(
      environment: GetPrioEnvironment.sandbox,
      apiBaseUrl: 'https://api.getprio.online',
      approvedHosts: 'sandbox.getprio.online',
    );

    expect(
      config.configurationError,
      contains('sandbox-api.getprio.online'),
    );
  });

  test('sandbox config accepts the sandbox API origin', () {
    const config = MobileEnvironmentConfig(
      environment: GetPrioEnvironment.sandbox,
      apiBaseUrl: 'https://sandbox-api.getprio.online',
      approvedHosts: 'sandbox.getprio.online',
    );

    expect(config.configurationError, isNull);
    expect(config.appName, 'GetPrio Sandbox');
    expect(config.approvedHostSet, contains('sandbox-api.getprio.online'));
  });

  test('production config keeps the existing missing-url behavior', () {
    const config = MobileEnvironmentConfig(
      environment: GetPrioEnvironment.production,
      apiBaseUrl: '',
      approvedHosts: 'app.getprio.online',
    );

    expect(config.configurationError, isNull);
    expect(config.appName, 'GetPrio Mobile');
  });

  test('production config rejects the sandbox API origin', () {
    const config = MobileEnvironmentConfig(
      environment: GetPrioEnvironment.production,
      apiBaseUrl: 'https://sandbox-api.getprio.online',
      approvedHosts: 'app.getprio.online',
    );

    expect(config.configurationError, contains('must not use'));
  });

  test('unknown config environment is rejected', () {
    const config = MobileEnvironmentConfig(
      environment: GetPrioEnvironment.unknown,
      apiBaseUrl: 'https://api.getprio.online',
      approvedHosts: 'app.getprio.online',
    );

    expect(config.configurationError, contains('production or sandbox'));
  });
}
