import 'package:image/image.dart' as img;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/bookings/booking_page.dart';
import 'package:getprio_mobile/bookings/booking_presentation.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/bookings/bookings_page.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/navigation/lists_page.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:getprio_mobile/queue/queue_repository.dart';
import 'package:getprio_mobile/social/vendor_social_repository.dart';
import 'package:getprio_mobile/social/vendor_social_widgets.dart';

import 'queue_repository_test.dart' show FakeAuthApiForTransport;
import 'ticket_details_test.dart' show FakeQueueApi;
import 'vendor_social_test.dart' show SocialClient;
import 'directory_and_ticket_repository_test.dart' show FakeDirectoryApi;
import 'booking_payment_test.dart' show pumpImageWork, paymentBooking;
import 'booking_detail_presentation_test.dart'
    show PresentationApi, sampleBooking;

class StalledProof extends PresentationApi {
  final gate = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) {
    if (path.endsWith('/payment-proof')) {
      proofRequests++;
      return gate.future;
    }
    return super.get(path, query: query);
  }
}

void main() {
  testWidgets(
    'shell shares booking retry state across routes and resets on account change',
    (tester) async {
      final auth = AuthRepository(
        api: FakeAuthApiForTransport(),
        tokenStore: MemoryTokenStore(),
      );
      await auth.signIn(identifier: 'customer', password: 'password');
      final upload = Completer<http.Response>();
      var uploads = 0;
      final directory = DirectoryRepository(
        RestDirectoryApi(
          AuthenticatedApiClient(
            baseUrl: 'https://api.example.test',
            authRepository: auth,
            client: MockClient((r) async {
              if (r.url.path.endsWith('/image-upload-policy')) {
                return http.Response('{"maxImageBytes":200000}', 200);
              }
              if (r.url.path.endsWith('/uploads/direct')) {
                uploads++;
                return upload.future;
              }
              return http.Response('{"vendors":[],"bookings":[]}', 200);
            }),
          ),
        ),
      );
      const user = AuthUser(id: 'a', email: 'a@example.test');
      Widget shell(AuthUser customer) => ShadcnApp(
        home: CustomerShell(user: customer, directoryRepository: directory),
      );
      await tester.pumpWidget(shell(user));
      await tester.pumpAndSettle();
      ListsPage lists() =>
          tester.widget<ListsPage>(find.byType(ListsPage, skipOffstage: false));
      final original = lists().bookingRepository!;
      final pending = original.submitPaymentProof(
        CustomerBooking(paymentBooking()),
        reference: 'ref',
        bytes: img.encodePng(img.Image(width: 20, height: 20)),
        contentType: 'image/png',
        fileName: 'receipt.png',
      );
      final timeout = expectLater(pending, throwsA(isA<TimeoutException>()));
      await pumpImageWork(tester, () => uploads == 1);
      await tester.pump(const Duration(seconds: 31));
      await timeout;
      expect(original.proofNeedsReconciliation('booking-1'), isTrue);
      lists().onOpenBooking!(
        CustomerBooking({'id': 'a', 'status': 'confirmed'}),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BookingDetailPage>(find.byType(BookingDetailPage))
            .repository,
        same(original),
      );
      Navigator.of(tester.element(find.byType(BookingDetailPage))).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(shell(user.copyWith(displayName: 'Updated')));
      await tester.pumpAndSettle();
      expect(lists().bookingRepository, same(original));
      expect(
        lists().bookingRepository!.proofNeedsReconciliation('booking-1'),
        isTrue,
      );
      lists().onOpenBooking!(
        CustomerBooking({'id': 'a', 'status': 'confirmed'}),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BookingDetailPage>(find.byType(BookingDetailPage))
            .repository,
        same(original),
      );
      Navigator.of(tester.element(find.byType(BookingDetailPage))).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(shell(user.copyWith(id: 'b')));
      await tester.pumpAndSettle();
      expect(lists().bookingRepository, isNot(same(original)));
      upload.complete(http.Response('{}', 200));
      await tester.pump();
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    },
  );

  testWidgets('Book opens with current customer without refreshing auth', (
    tester,
  ) async {
    final authApi = FakeAuthApiForTransport();
    final auth = AuthRepository(api: authApi, tokenStore: MemoryTokenStore());
    await auth.signIn(identifier: 'customer', password: 'password');
    final client = AuthenticatedApiClient(
      baseUrl: 'https://api.example.test',
      authRepository: auth,
      client: MockClient((r) async {
        if (r.url.path.endsWith('/services')) {
          return http.Response(
            '{"services":[{"slug":"consult","name":"Consultation","durationMinutes":30}]}',
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'slug': 'clinic',
            'name': 'Clinic',
            'capabilities': {'booking': true},
            'locations': [
              {'id': 'main', 'slug': 'main', 'name': 'Main', 'isPrimary': true},
            ],
          }),
          200,
        );
      }),
    );
    const customer = AuthUser(
      id: 'a',
      email: 'a@example.test',
      profileName: 'Customer A',
      phone: '09990000000',
    );
    await tester.pumpWidget(
      ShadcnApp(
        home: VendorDetailPage(
          vendor: const VendorSummary(
            slug: 'clinic',
            name: 'Clinic',
            queueAvailable: false,
          ),
          repository: DirectoryRepository(RestDirectoryApi(client)),
          bookingRepository: BookingRepository(RestBookingApi(client)),
          customer: customer,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();
    expect(find.byType(BookingPage), findsOneWidget);
    expect(
      tester.widget<BookingPage>(find.byType(BookingPage)).customer,
      same(customer),
    );
    expect(authApi.refreshCalls, 0);
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
  });

  testWidgets('stalled proof URL restores retry and ignores late URL', (
    tester,
  ) async {
    final api = StalledProof();
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: SingleChildScrollView(
            child: BookingProofSummary(
              booking: CustomerBooking(sampleBooking()),
              repository: BookingRepository(api),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('booking-view-proof')));
    await tester.tap(find.byKey(const Key('booking-view-proof')));
    await tester.pump();
    expect(
      tester
          .widget<OutlineButton>(find.byKey(const Key('booking-view-proof')))
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not open payment proof. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlineButton>(find.byKey(const Key('booking-view-proof')))
          .onPressed,
      isNotNull,
    );
    api.gate.complete({
      'access': {'url': 'https://example.test/late.png'},
    });
    await tester.pumpAndSettle();
    expect(find.byType(BookingProofSummary), findsOneWidget);
    expect(api.proofRequests, 1);
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
  });

  testWidgets(
    'completed called outcome still offers rating after returning later',
    (tester) async {
      final ticket = QueueTicket.fromJson({
        'id': 't',
        'lookupCode': 'T',
        'status': 'called',
        'serviceOutcome': 'completed',
        'tenantSlug': 'clinic',
      });
      await tester.pumpWidget(
        ShadcnApp(
          home: TicketDetailsPage(
            ticket: ticket,
            directoryRepository: DirectoryRepository(
              FakeDirectoryApi(vendors: {'slug': 'clinic', 'name': 'Clinic'}),
              social: VendorSocialRepository(SocialClient()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TicketReviewAction), findsOneWidget);
      expect(find.text('Rate vendor'), findsOneWidget);
      expect(find.byKey(const Key('ticket-qr-fab')), findsNothing);
      await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
    },
  );

  testWidgets('called account ticket survives stale waiting details snapshot', (
    tester,
  ) async {
    final ticket = QueueTicket.fromJson({
      'id': 't',
      'lookupCode': 'T',
      'status': 'called',
      'tenantSlug': 'clinic',
    });
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketDetailsPage(
          ticket: ticket,
          queueRepository: QueueRepository(
            FakeQueueApi(
              snapshot: {
                'focusTicket': {
                  'id': 't',
                  'lookupCode': 'T',
                  'status': 'waiting',
                },
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CALLED'), findsOneWidget);
    expect(find.byKey(const Key('ticket-called-alert')), findsOneWidget);
    await tester.pumpWidget(const ShadcnApp(home: SizedBox()));
  });
}
