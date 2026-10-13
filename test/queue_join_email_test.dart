import 'dart:async';

import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/otp_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/queue/join_repository.dart';
import 'package:getprio_mobile/queue/join_ui.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets(
    'stalled direct join times out and ignores late result after cancel',
    (tester) async {
      final api = _StalledEmailApi();
      await tester.pumpWidget(
        ShadcnApp(
          home: CustomerShell(
            joinRepository: JoinRepository(api),
            directoryRepository: DirectoryRepository(_JoinDirectoryApi()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clinic').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vendor-join-queue-button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This is taking too long. Check your tickets before trying again.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      api.gate.complete(api.challenge('late'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vendor-join-queue-button')), findsOneWidget);
      expect(find.byKey(const Key('queue-join-otp-drawer')), findsNothing);
      expect(find.byType(TicketDetailsPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('vendor Join queue opens only OTP drawer then ticket details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _EmailApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: CustomerShell(
          joinRepository: JoinRepository(api),
          directoryRepository: DirectoryRepository(_JoinDirectoryApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clinic').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vendor-join-queue-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('queue-join-otp-drawer')), findsOneWidget);
    expect(find.byKey(const Key('direct-join-flow-shell')), findsNothing);
    expect(find.byType(JoinPage), findsNothing);
    expect(find.byType(TicketDetailsPage), findsNothing);
    expect(api.directCalls, 1);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vendor-join-queue-button')), findsOneWidget);
    expect(api.verifyCalls, 0);
    await tester.tap(find.byKey(const Key('vendor-join-queue-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find
          .descendant(
            of: find.byKey(const Key('queue-join-otp')),
            matching: find.byType(EditableText),
          )
          .first,
      '123456',
    );
    await tester.pumpAndSettle();
    expect(api.directCalls, 2);
    expect(api.verifyCalls, 1);
    expect(find.byKey(const Key('queue-join-otp-drawer')), findsNothing);
    expect(find.byType(TicketDetailsPage), findsOneWidget);
    await tester.tap(find.byKey(const Key('ticket-details-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vendor-join-queue-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
  });

  testWidgets(
    'direct join verifies email before delivering the selected location ticket',
    (tester) async {
      final api = _EmailApi();
      QueueTicket? joined;
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: JoinPage(
              repository: JoinRepository(api),
              allowedHosts: const {},
              customerName: 'Customer',
              directTenantSlug: 'clinic',
              directLocationSlug: 'cebu',
              onJoined: (ticket) => joined = ticket,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.location, 'cebu');
      expect(find.text('Verify your email'), findsOneWidget);
      expect(find.byKey(const Key('queue-join-otp-drawer')), findsOneWidget);
      expect(joined, isNull);
      await tester.enterText(
        find
            .descendant(
              of: find.byKey(const Key('queue-join-otp')),
              matching: find.byType(EditableText),
            )
            .first,
        '123',
      );
      await tester.pump();
      expect(api.verifyCalls, 0);
      await tester.enterText(
        find
            .descendant(
              of: find.byKey(const Key('queue-join-otp')),
              matching: find.byType(EditableText),
            )
            .first,
        '000000',
      );
      await tester.pumpAndSettle();
      expect(find.text('Incorrect code'), findsOneWidget);
      expect(joined, isNull);
      await tester.tap(find.byKey(const Key('queue-join-otp-resend')));
      await tester.pumpAndSettle();
      expect(api.resendCalls, 1);
      await tester.enterText(
        find
            .descendant(
              of: find.byKey(const Key('queue-join-otp')),
              matching: find.byType(EditableText),
            )
            .first,
        '123456',
      );
      await tester.pumpAndSettle();
      expect(api.lastOtpId, '2');
      expect(api.verifyCalls, 2);
      expect(joined?.locationSlug, 'cebu');
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    },
  );

  testWidgets(
    'join OTP drawer blocks outside dismissal and enforces resend cooldown',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _EmailApi()..cooldownSeconds = 2;
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: JoinPage(
              repository: JoinRepository(api),
              allowedHosts: const {},
              customerName: 'Customer',
              directTenantSlug: 'clinic',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final drawer = find.byKey(const Key('queue-join-otp-drawer'));
      expect(drawer, findsOneWidget);
      final resend = find.byKey(const Key('queue-join-otp-resend'));
      final field = find.byType(InputOTP);
      expect(
        tester.getCenter(resend).dy,
        closeTo(tester.getCenter(field).dy, 1),
      );
      expect(
        tester.widget<OtpResendButton>(resend).secondsRemaining,
        greaterThan(0),
      );
      await tester.tap(resend);
      await tester.pump();
      expect(api.resendCalls, 0);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(drawer, findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(drawer, findsNothing);
      expect(api.verifyCalls, 0);
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    },
  );

  testWidgets(
    'payment continuation reuses the verified result without another join',
    (tester) async {
      final api = _EmailApi();
      final payment = PaymentRequired(
        paymentAttemptId: 'existing',
        checkoutUrl: Uri.parse('https://getprio.online/checkout'),
        tenantSlug: 'clinic',
        locationSlug: 'cebu',
      );
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: JoinPage(
              repository: JoinRepository(api),
              allowedHosts: const {},
              customerName: 'Customer',
              directTenantSlug: 'clinic',
              directLocationSlug: 'cebu',
              initialResult: payment,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutBottomSheet), findsOneWidget);
      expect(
        tester
            .widget<CheckoutBottomSheet>(find.byType(CheckoutBottomSheet))
            .payment,
        same(payment),
      );
      expect(api.directCalls, 0);
      expect(api.verifyCalls, 0);
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    },
  );

  test('QR joins return email challenges before ticket creation', () async {
    final result = await JoinRepository(_EmailApi())
        .join(locationQrId: 'qr', customerName: 'Customer');
    expect(result, isA<JoinEmailVerification>());
  });
}

class _EmailApi implements JoinApi, DirectJoinApi, JoinOtpApi {
  String? location;
  String? lastOtpId;
  int verifyCalls = 0;
  int resendCalls = 0;
  int directCalls = 0;
  int cooldownSeconds = 0;
  Map<String, dynamic> challenge(String id) => {
    'otpRequired': true,
    'otpId': id,
    'deliveryTarget': 'customer@example.com',
    'tenantSlug': 'clinic',
    'locationSlug': 'cebu',
    'resendsRemaining': 3,
    if (cooldownSeconds > 0)
      'resendAvailableAt': DateTime.now()
          .add(Duration(seconds: cooldownSeconds))
          .toIso8601String(),
  };
  @override
  Future<Map<String, dynamic>> resolve(String locationQrId) async => {
    'joinable': true,
  };
  @override
  Future<Map<String, dynamic>> join({
    required String locationQrId,
    required String joinAttemptId,
    required String customerName,
  }) async => challenge('1');
  @override
  Future<Map<String, dynamic>> joinDirect({
    required String tenantSlug,
    String? locationSlug,
    required String joinAttemptId,
    required String customerName,
  }) async {
    directCalls++;
    location = locationSlug;
    return challenge('1');
  }

  @override
  Future<Map<String, dynamic>> resendOtp({
    required String otpId,
    required String attemptId,
  }) async {
    resendCalls++;
    return challenge('2');
  }

  @override
  Future<Map<String, dynamic>> verifyOtp({
    required String otpId,
    required String code,
    required String attemptId,
  }) async {
    verifyCalls++;
    lastOtpId = otpId;
    if (code != '123456') {
      throw const ApiException(400, 'INVALID_CODE', 'Incorrect code');
    }
    return {
      'ticket': {
        'id': 'ticket',
        'ticketNumber': 'A001',
        'lookupCode': 'A001',
        'status': 'waiting',
      },
    };
  }
}

class _JoinDirectoryApi implements DirectoryApi {
  final vendor = <String, dynamic>{
    'slug': 'clinic',
    'name': 'Clinic',
    'queueAvailable': true,
    'locations': [
      {
        'id': 'cebu',
        'slug': 'cebu',
        'name': 'Cebu',
        'isPrimary': true,
        'queueAvailable': true,
      },
    ],
  };
  @override
  Future<Map<String, dynamic>> loadVendors({
    String? search,
    int limit = 20,
  }) async => {
    'vendors': [vendor],
  };
  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async => vendor;
}

class _StalledEmailApi extends _EmailApi {
  final gate = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> joinDirect({
    required String tenantSlug,
    String? locationSlug,
    required String joinAttemptId,
    required String customerName,
  }) => gate.future;
}
