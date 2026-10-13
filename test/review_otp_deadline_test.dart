import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/bookings/booking_otp_drawer.dart';
import 'package:getprio_mobile/queue/join_otp_drawer.dart';
import 'package:getprio_mobile/queue/join_repository.dart';
import 'package:getprio_mobile/navigation/app_drawer.dart';
import 'package:getprio_mobile/otp_input.dart';

class OtpBookingApi implements BookingApi {
  OtpBookingApi(this.phase);
  final String phase;
  final gate = Completer<Map<String, dynamic>>();
  int creates = 0, verifies = 0, resends = 0;
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async => {};
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path.endsWith('/verify')) {
      verifies++;
      return phase == 'verify'
          ? gate.future
          : {'bookingVerificationToken': 'token'};
    }
    if (path.endsWith('/resend')) {
      resends++;
      return gate.future;
    }
    creates++;
    return gate.future;
  }
}

class OtpQueueApi implements JoinApi, JoinOtpApi {
  final gate = Completer<Map<String, dynamic>>();
  int verifies = 0, resends = 0;
  @override
  Future<Map<String, dynamic>> verifyOtp({
    required String otpId,
    required String code,
    required String attemptId,
  }) {
    verifies++;
    return gate.future;
  }

  @override
  Future<Map<String, dynamic>> resendOtp({
    required String otpId,
    required String attemptId,
  }) {
    resends++;
    return gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  for (final phase in ['verify', 'create', 'resend']) {
    testWidgets(
      'booking $phase timeout restores exit and prevents duplicate request; late result reconciles',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final api = OtpBookingApi(phase);
        CustomerBooking? created;
        await tester.pumpWidget(
          ShadcnApp(
            home: DrawerOverlay(
              child: Builder(
                builder: (context) => Scaffold(
                  child: PrimaryButton(
                    child: const Text('Open'),
                    onPressed: () async {
                      created = await openAppDrawer<CustomerBooking>(
                        context: context,
                        position: OverlayPosition.bottom,
                        draggable: false,
                        barrierDismissible: false,
                        builder: (_) => BookingOtpDrawer(
                          repository: BookingRepository(api),
                          base: '/api/public/vendors/clinic',
                          challenge: {
                            'otpId': 'otp',
                            'expiresAt': DateTime.now()
                                .add(const Duration(minutes: 5))
                                .toIso8601String(),
                          },
                          payload: const {'customerEmail': 'test@example.test'},
                        ),
                      ).future;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (phase == 'resend') {
          tester
              .widget<OtpResendButton>(
                find.byKey(const Key('booking-otp-resend')),
              )
              .onPressed!();
        } else {
          await tester.enterText(
            find
                .descendant(
                  of: find.byType(GetPrioOtpInput),
                  matching: find.byType(EditableText),
                )
                .last,
            '123456',
          );
        }
        await tester.pump();
        await tester.pump(const Duration(seconds: 21));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OutlineButton>(
                find.byKey(const Key('booking-otp-details')),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          tester
              .widget<PrimaryButton>(
                find.byKey(const Key('booking-otp-submit')),
              )
              .onPressed,
          isNull,
        );
        expect(created, isNull);
        if (phase == 'create') {
          api.gate.complete({
            'booking': {'id': 'created', 'status': 'pending'},
          });
          await tester.pumpAndSettle();
          expect(created!.id, 'created');
          expect(api.creates, 1);
        } else if (phase == 'verify') {
          api.gate.complete({'bookingVerificationToken': 'late-token'});
          await tester.pumpAndSettle();
          expect(api.creates, 0);
        } else {
          api.gate.complete({
            'otpId': 'next',
            'expiresAt': DateTime.now()
                .add(const Duration(minutes: 5))
                .toIso8601String(),
          });
          await tester.pumpAndSettle();
          expect(api.resends, 1);
        }
        await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
      },
    );
  }
  for (final phase in ['verify', 'resend']) {
    testWidgets(
      'queue $phase timeout restores cancel without duplicate or late reopen',
      (tester) async {
        final api = OtpQueueApi();
        await tester.pumpWidget(
          ShadcnApp(
            home: Scaffold(
              child: JoinOtpDrawer(
                repository: JoinRepository(api),
                challenge: JoinEmailVerification(
                  otpId: 'otp',
                  email: 'test@example.test',
                  tenantSlug: 'clinic',
                  locationSlug: 'main',
                  resendsRemaining: 3,
                  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
                ),
                messageFor: (e) => '$e',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (phase == 'resend') {
          tester
              .widget<OtpResendButton>(
                find.byKey(const Key('queue-join-otp-resend')),
              )
              .onPressed!();
        } else {
          await tester.enterText(
            find
                .descendant(
                  of: find.byType(GetPrioOtpInput),
                  matching: find.byType(EditableText),
                )
                .last,
            '123456',
          );
        }
        await tester.pump();
        await tester.pump(const Duration(seconds: 21));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OutlineButton>(
                find.widgetWithText(OutlineButton, 'Cancel'),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          tester
              .widget<PrimaryButton>(
                find.byKey(const Key('queue-join-otp-verify')),
              )
              .onPressed,
          isNull,
        );
        expect(phase == 'verify' ? api.verifies : api.resends, 1);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
        api.gate.complete({
          'ticket': {'id': 't', 'lookupCode': 'T', 'status': 'waiting'},
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
