import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/network/api_paths.dart';

void main() {
  test('versions unversioned API paths exactly once', () {
    expect(versionedApiPath('/api/auth/login'), '/api/v1/auth/login');
    expect(
      versionedApiPath('/api/mobile/queue-join'),
      '/api/v1/mobile/queue-join',
    );
    expect(
      versionedApiPath('/api/v1/account/overview'),
      '/api/v1/account/overview',
    );
    expect(versionedApiPath('/api/v1'), '/api/v1');
    expect(versionedApiPath('/join/acme'), '/join/acme');
  });
}
