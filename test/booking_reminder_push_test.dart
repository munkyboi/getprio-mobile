import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/bookings/bookings_page.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/push/push_coordinator.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';

import 'queue_repository_test.dart' show FakeAuthApiForTransport;

PushSignal reminder({
  bool opened = true,
  String route = '/account/bookings/booking-1',
}) => PushSignal(
  eventType: 'customer_booking_reminder_1h',
  notificationId: 'booking-stage-1',
  route: route,
  opened: opened,
);

void main() {
  test(
    'booking links require explicit tap and safe relative account route',
    () {
      expect(bookingIdForPush(reminder()), 'booking-1');
      expect(bookingIdForPush(reminder(opened: false)), isNull);
      for (final route in [
        'https://evil.test/account/bookings/1',
        '//evil.test/account/bookings/1',
        '/account/bookings/a%2Fb',
        '/account/bookings/1?x=1',
        '/account/bookings/1#x',
        '/vendor/bookings/1',
      ]) {
        expect(bookingIdForPush(reminder(route: route)), isNull);
      }
      final payload = {
        'eventType': 'customer_booking_reminder_24h',
        'notificationId': 'stage',
        'route': '/account/bookings/1',
        'opened': true,
      };
      expect(PushSignal.fromData(payload).opened, isFalse);
      expect(bookingIdForPush(openedPushPayload(jsonEncode(payload))!), '1');
      expect(openedPushPayload('not json'), isNull);
    },
  );

  testWidgets('late booking response cannot open under a replacement account', (
    tester,
  ) async {
    final auth = AuthRepository(
      api: FakeAuthApiForTransport(),
      tokenStore: MemoryTokenStore(),
    );
    await auth.signIn(identifier: 'customer', password: 'password');
    final gate = Completer<http.Response>();
    final client = AuthenticatedApiClient(
      baseUrl: 'https://api.example.test',
      authRepository: auth,
      client: MockClient(
        (request) async => request.url.path.contains('/account/bookings/')
            ? gate.future
            : http.Response('{"vendors":[]}', 200),
      ),
    );
    final directory = DirectoryRepository(RestDirectoryApi(client));
    final push = ValueNotifier<PushSignal?>(reminder());
    Widget shell(String user) => ShadcnApp(
      home: CustomerShell(
        user: AuthUser(id: user, email: '$user@example.test'),
        directoryRepository: directory,
        pushSignal: push,
      ),
    );
    await tester.pumpWidget(shell('one'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(shell('two'));
    await tester.pumpAndSettle();
    gate.complete(
      http.Response(
        jsonEncode({
          'booking': {
            'id': 'booking-1',
            'reference': 'BKG-OLD',
            'status': 'confirmed',
            'paymentStatus': 'paid',
          },
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BookingDetailPage), findsNothing);
    expect(find.text('BKG-OLD'), findsNothing);
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    push.dispose();
  });

  for (final coldStart in [false, true]) {
    testWidgets(
      'reminder opens authenticated booking only on tap, coldStart=$coldStart',
      (tester) async {
        final auth = AuthRepository(
          api: FakeAuthApiForTransport(),
          tokenStore: MemoryTokenStore(),
        );
        await auth.signIn(identifier: 'customer', password: 'password');
        final requests = <String>[];
        final client = AuthenticatedApiClient(
          baseUrl: 'https://api.example.test',
          authRepository: auth,
          client: MockClient((request) async {
            if (request.url.path.contains('/account/bookings/')) {
              requests.add(request.url.path);
              expectSync(
                request.headers['authorization'],
                startsWith('Bearer '),
              );
              return http.Response(
                jsonEncode({
                  'booking': {
                    'id': 'booking-1',
                    'reference': 'BKG-REMINDER',
                    'status': 'confirmed',
                    'paymentStatus': 'paid',
                    'tenantName': 'Clinic',
                    'scheduledStartAt': '2026-10-20T09:00:00Z',
                  },
                }),
                200,
              );
            }
            return http.Response('{"vendors":[]}', 200);
          }),
        );
        final push = ValueNotifier<PushSignal?>(coldStart ? reminder() : null);
        await tester.pumpWidget(
          ShadcnApp(
            home: CustomerShell(
              directoryRepository: DirectoryRepository(
                RestDirectoryApi(client),
              ),
              pushSignal: push,
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!coldStart) {
          push.value = reminder(opened: false);
          await tester.pumpAndSettle();
          expect(find.byType(BookingDetailPage), findsNothing);
          expect(requests, isEmpty);
          push.value = reminder();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();
        }
        expect(
          requests,
          isNotEmpty,
          reason:
              'tap must fetch booking; pending signal=${push.value?.opened}',
        );
        expect(find.byType(BookingDetailPage), findsOneWidget);
        expect(find.text('BKG-REMINDER'), findsOneWidget);
        expect(requests, contains('/api/v1/account/bookings/booking-1'));
        expect(push.value, isNull);
        final fetched = requests.length;
        push.value = reminder();
        await tester.pumpAndSettle();
        expect(find.byType(BookingDetailPage), findsOneWidget);
        expect(requests.length, fetched);
        await tester.pumpWidget(
          ShadcnApp(
            home: CustomerShell(
              user: const AuthUser(id: 'other', email: 'other@example.test'),
              directoryRepository: DirectoryRepository(
                RestDirectoryApi(client),
              ),
              pushSignal: push,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BookingDetailPage), findsNothing);
        expect(push.value, isNull);
        await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
        push.dispose();
      },
    );
  }
}
