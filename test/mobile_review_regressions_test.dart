import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:getprio_mobile/network/drawer_request.dart';
import 'package:getprio_mobile/notifications/notification_inbox.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/account/profile_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import 'profile_test.dart' show FakeAccountProfileApi, FakeAccountSettingsApi;

import 'package:getprio_mobile/account/account_settings_repository.dart';

import 'booking_payment_test.dart' show pumpImageWork;
import 'notification_inbox_test.dart' show InboxApi, notification;

class PendingTickets implements AccountQueueApi {
  final requests = <Completer<Map<String, dynamic>>>[];
  @override
  Future<Map<String, dynamic>> loadOverview() {
    final gate = Completer<Map<String, dynamic>>();
    requests.add(gate);
    return gate.future;
  }

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => {};
}

class StalledInbox extends InboxApi {
  final mutation = Completer<void>();
  @override
  Future<void> markRead(String id) => mutation.future;
  @override
  Future<void> markAllRead(String cutoff) => mutation.future;
  @override
  Future<void> clear(String cutoff) => mutation.future;
}

class RetryAvatar extends FakeAccountProfileApi {
  bool fail = true;
  int uploads = 0;
  @override
  Future<Map<String, dynamic>> uploadAvatar({
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    uploads++;
    if (fail) throw StateError('offline');
    return super.uploadAvatar(
      fileName: fileName,
      contentType: contentType,
      bytes: bytes,
    );
  }
}

void main() {
  for (final failure in [false, true]) {
    test(
      'old account overview ${failure ? 'failure' : 'success'} cannot change new account',
      () async {
        final api = PendingTickets();
        final repo = QueueTicketRepository(api);
        final old = repo.loadOverview();
        final assertion = expectLater(old, throwsA(isA<StateError>()));
        repo.clearSession();
        final current = repo.loadOverview();
        api.requests[1].complete({
          'tickets': [
            {'id': 'new', 'lookupCode': 'NEW', 'status': 'waiting'},
          ],
          'ticketStats': {'joined': 2, 'served': 1},
        });
        await current;
        if (failure) {
          api.requests[0].completeError(StateError('old error'));
        } else {
          api.requests[0].complete({
            'tickets': [
              {'id': 'private', 'lookupCode': 'OLD', 'status': 'waiting'},
            ],
            'ticketStats': {'joined': 99, 'served': 9},
          });
        }
        await assertion;
        expect(repo.overviewTickets.value.single.id, 'new');
        expect(repo.ticketStats.value!.joined, 2);
        expect(repo.servedTicket.value, isNull);
      },
    );
  }
  test('completed/interrupted called tickets are historical and never request arrival', () {
    for (final outcome in ['completed', 'interrupted']) {
      final ticket = QueueTicket.fromJson({
        'id': 't',
        'lookupCode': 'T',
        'status': 'called',
        'serviceOutcome': outcome,
      });
      expect(ticket.isActive, isFalse);
      expect(ticket.needsArrival, isFalse);
      expect(ticket.progressRank, 4);
    }
    final booking = CustomerBooking({
      'status': 'confirmed',
      'queueTicketId': 'ticket',
      'scheduledStartAt': '2026-10-20T00:00:00Z',
      'customerSelfCheckInEnabled': true,
    });
    expect(booking.checkInLabel(DateTime(2026, 10, 13)), 'Checked in');
    expect(booking.nextStep, contains('checked in'));
  });
  for (final action in ['read', 'all', 'clear']) {
    testWidgets('stalled inbox $action reconciles and releases controls', (
      tester,
    ) async {
      final api = StalledInbox()..rows.add(notification('a'));
      final inbox = NotificationInboxController(api);
      await inbox.refresh();
      final operation = switch (action) {
        'read' => inbox.markRead(inbox.items.first),
        'all' => inbox.markAllRead(),
        _ => inbox.clear(),
      };
      await tester.pump(const Duration(seconds: 21));
      await operation;
      expect(inbox.mutating, isFalse);
      expect(inbox.loading, isFalse);
      expect(api.loads, 2);
      expect(inbox.items.single.id, 'a');
      expect(inbox.error, contains('Could not update'));
      api.mutation.complete();
      await tester.pump();
      inbox.dispose();
    });
  }
  testWidgets(
    'drawer timeout releases navigation and reconciles original late result once',
    (tester) async {
      final gate = Completer<int>();
      var timedOut = false;
      final late = <int>[];
      final request = awaitDrawerRequest(
        gate.future,
        onTimeout: () => timedOut = true,
        onLateSuccess: late.add,
        onLateFailure: (_) {},
      );
      final assertion = expectLater(request, throwsA(isA<TimeoutException>()));
      await tester.pump(const Duration(seconds: 21));
      await assertion;
      expect(timedOut, isTrue);
      gate.complete(7);
      await tester.pump();
      expect(late, [7]);
    },
  );
  testWidgets(
    'avatar retry reuses selected original without reopening picker',
    (tester) async {
      final api = RetryAvatar();
      var picks = 0;
      await tester.pumpWidget(
        ShadcnApp(
          home: AccountPage(
            user: api.user,
            profileRepository: AccountProfileRepository(api),
            pickAvatar: () async {
              picks++;
              return XFile.fromData(
                img.encodePng(img.Image(width: 20, height: 20)),
                name: 'photo.png',
                mimeType: 'image/png',
              );
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('profile-avatar-button')));
      await pumpImageWork(tester, () => api.uploads == 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('profile-avatar-retry')), findsOneWidget);
      api.fail = false;
      await tester.tap(find.byKey(const Key('profile-avatar-retry')));
      await pumpImageWork(tester, () => api.uploads == 2);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      expect(picks, 1);
      expect(find.byKey(const Key('profile-avatar-retry')), findsNothing);
    },
  );
  testWidgets('Sandbox retains reachable queue alert settings', (tester) async {
    final api = FakeAccountSettingsApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: AccountPage(
          sandbox: true,
          settingsRepository: AccountSettingsRepository(api),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('profile-notifications')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notification-settings-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('notification-queue-alerts')));
    await tester.pumpAndSettle();
    expect(api.lastQueueAlerts, isFalse);
  });
}
