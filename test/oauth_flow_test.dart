import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/oauth_flow.dart';

void main() {
  test('generates an S256 PKCE challenge from the verifier', () {
    final pair = PkcePair.generate();

    expect(pair.state, isNotEmpty);
    expect(pair.verifier, isNotEmpty);
    expect(pair.challenge, isNot(pair.verifier));
    expect(pair.challenge, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
  });

  test('accepts a successful verified-link callback', () {
    final callback = OAuthCallback.parse(
      Uri.parse(
        'https://app.getprio.test/oauth/mobile/callback?code=one-time&state=state-1',
      ),
    );

    expect(callback.code, 'one-time');
    expect(callback.state, 'state-1');
    expect(callback.error, isNull);
  });

  test('surfaces provider cancellation without accepting a token', () {
    final callback = OAuthCallback.parse(
      Uri.parse(
        'https://app.getprio.test/oauth/mobile/callback?error=access_denied&state=state-1',
      ),
    );

    expect(callback.code, isNull);
    expect(callback.error, 'access_denied');
  });

  test('rejects callback state mismatch', () {
    expect(
      () => OAuthFlow.validateCallback(
        OAuthCallback.parse(
          Uri.parse(
            'https://app.getprio.test/oauth/mobile/callback?code=one&state=other',
          ),
        ),
        expectedState: 'expected',
      ),
      throwsA(isA<OAuthException>()),
    );
  });
}
