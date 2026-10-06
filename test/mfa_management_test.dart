import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/security_repository.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'queue_repository_test.dart' show FakeAuthApiForTransport;
import 'security_repository_test.dart' show FakeSecurityApi;

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'sends current code for replacement and verification for removal',
    () async {
      final auth = AuthRepository(
        api: FakeAuthApiForTransport(),
        tokenStore: MemoryTokenStore(),
      );
      await auth.signIn(identifier: 'customer', password: 'password');
      final requests = <http.Request>[];
      final repository = SecurityRepository(
        RestSecurityApi(
          AuthenticatedApiClient(
            baseUrl: 'https://api.example.test',
            authRepository: auth,
            client: MockClient((request) async {
              requests.add(request);
              return http.Response(
                jsonEncode(
                  request.url.path.endsWith('/start')
                      ? {
                          'secret': 'key',
                          'otpAuthUri': 'otpauth://totp/GetPrio?secret=key',
                        }
                      : {'success': true},
                ),
                200,
              );
            }),
          ),
        ),
      );
      await repository.startMfaEnrollment(currentCode: '123456');
      await repository.cancelMfaEnrollment();
      await repository.disableMfa(
        password: 'password',
        recoveryCode: 'ABCDE-12345',
      );
      expect(requests.map((r) => r.url.path), [
        '/api/v1/auth/mfa/enrollment/start',
        '/api/v1/auth/mfa/enrollment/cancel',
        '/api/v1/auth/mfa/disable',
      ]);
      expect(jsonDecode(requests[0].body), {'currentCode': '123456'});
      expect(jsonDecode(requests[2].body), {
        'password': 'password',
        'recoveryCode': 'ABCDE-12345',
      });
    },
  );

  for (final cancel in [false, true]) {
    testWidgets(
      'replacement keeps active MFA until confirmation or cancellation: $cancel',
      (tester) async {
        final api = ManagementApi();
        bool? changed;
        await tester.pumpWidget(
          ShadcnApp(
            home: SecurityPage(
              repository: SecurityRepository(api),
              mfaEnabled: true,
              section: SecuritySection.mfa,
              onMfaChanged: (value) => changed = value,
            ),
          ),
        );
        await tapKey(tester, 'mfa-replace-button');
        await tester.enterText(
          find.byKey(const Key('mfa-current-code')),
          '123456',
        );
        await tapKey(tester, 'mfa-replace-confirm');
        expect(api.currentCode, '123456');
        expect(changed, isNull);
        expect(find.byKey(const Key('mfa-enrollment-qr')), findsOneWidget);
        if (cancel) {
          await tapKey(tester, 'mfa-cancel-enrollment');
          expect(api.cancelled, isTrue);
          expect(changed, isNull);
          expect(find.byKey(const Key('mfa-replace-button')), findsOneWidget);
          expect(find.byKey(const Key('mfa-setup-button')), findsNothing);
        } else {
          await tester.enterText(
            find.byKey(const Key('mfa-enrollment-code')),
            '654321',
          );
          await tapKey(tester, 'mfa-confirm-button');
          expect(changed, isTrue);
          expect(find.byKey(const Key('mfa-recovery-codes')), findsOneWidget);
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
        }
      },
    );
  }

  for (final recovery in [false, true]) {
    testWidgets(
      'removal validates credentials and updates enabled state: recovery=$recovery',
      (tester) async {
        final api = ManagementApi();
        bool? changed;
        await tester.pumpWidget(
          ShadcnApp(
            home: SecurityPage(
              repository: SecurityRepository(api),
              mfaEnabled: true,
              section: SecuritySection.mfa,
              onMfaChanged: (value) => changed = value,
            ),
          ),
        );
        await tapKey(tester, 'mfa-remove-button');
        await tapKey(tester, 'mfa-remove-confirm');
        expect(api.password, isNull);
        await tester.enterText(
          find.byKey(const Key('mfa-management-password')),
          'password',
        );
        if (recovery) await tapKey(tester, 'mfa-toggle-recovery');
        await tester.enterText(
          find.byKey(const Key('mfa-current-code')),
          recovery ? 'ABCDE-12345' : '123456',
        );
        await tapKey(tester, 'mfa-remove-confirm');
        expect(api.password, 'password');
        expect(api.code, recovery ? null : '123456');
        expect(api.recoveryCode, recovery ? 'ABCDE-12345' : null);
        expect(changed, isFalse);
        expect(find.byKey(const Key('mfa-setup-button')), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('failed removal keeps MFA enabled and allows retry', (
    tester,
  ) async {
    final api = ManagementApi()
      ..failure = const ApiException(
        400,
        'MFA_CODE_INVALID',
        'That security code could not be verified.',
      );
    bool? changed;
    await tester.pumpWidget(
      ShadcnApp(
        home: SecurityPage(
          repository: SecurityRepository(api),
          mfaEnabled: true,
          section: SecuritySection.mfa,
          onMfaChanged: (value) => changed = value,
        ),
      ),
    );
    await tapKey(tester, 'mfa-remove-button');
    await tester.enterText(
      find.byKey(const Key('mfa-management-password')),
      'password',
    );
    await tester.enterText(find.byKey(const Key('mfa-current-code')), '123456');
    await tapKey(tester, 'mfa-remove-confirm');
    expect(changed, isNull);
    expect(find.byKey(const Key('mfa-setup-button')), findsNothing);
    expect(
      find.text('That security code could not be verified.'),
      findsOneWidget,
    );
    api.failure = null;
    await tapKey(tester, 'mfa-remove-confirm');
    expect(changed, isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('replacement explains a stale sign-in without changing MFA', (
    tester,
  ) async {
    final api = ManagementApi()
      ..failure = const ApiException(
        403,
        'RECENT_AUTHENTICATION_REQUIRED',
        'Please sign in again before replacing your authenticator.',
      );
    await tester.pumpWidget(
      ShadcnApp(
        home: SecurityPage(
          repository: SecurityRepository(api),
          mfaEnabled: true,
          section: SecuritySection.mfa,
        ),
      ),
    );
    await tapKey(tester, 'mfa-replace-button');
    await tester.enterText(find.byKey(const Key('mfa-current-code')), '123456');
    await tapKey(tester, 'mfa-replace-confirm');
    expect(find.byKey(const Key('mfa-enrollment-qr')), findsNothing);
    expect(
      find.text('Please sign in again before replacing your authenticator.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mfa-replace-confirm')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('required MFA offers replacement but no removal', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: SecurityPage(
          repository: SecurityRepository(ManagementApi()),
          mfaEnabled: true,
          mfaRequired: true,
          section: SecuritySection.mfa,
        ),
      ),
    );
    expect(find.byKey(const Key('mfa-replace-button')), findsOneWidget);
    expect(find.byKey(const Key('mfa-remove-button')), findsNothing);
  });
}

class ManagementApi extends FakeSecurityApi {
  String? currentCode;
  String? password;
  String? code;
  String? recoveryCode;
  bool cancelled = false;
  ApiException? failure;

  @override
  Future<Map<String, dynamic>> startMfaEnrollment({String? currentCode}) async {
    if (failure != null) throw failure!;
    this.currentCode = currentCode;
    return super.startMfaEnrollment();
  }

  @override
  Future<void> cancelMfaEnrollment() async => cancelled = true;

  @override
  Future<void> disableMfa({
    required String password,
    String? code,
    String? recoveryCode,
  }) async {
    if (failure != null) throw failure!;
    this.password = password;
    this.code = code;
    this.recoveryCode = recoveryCode;
  }
}
