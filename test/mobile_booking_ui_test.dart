import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:getprio_mobile/bookings/bookings_page.dart';
import 'package:getprio_mobile/bookings/booking_page.dart';
import 'package:getprio_mobile/bookings/service_selection.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/otp_input.dart';
import 'package:getprio_mobile/navigation/swipe_back_page_route.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: .25);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'service units live in cards and Together synchronizes maximum quantities',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _UnitsApi();
      final services = [
        for (final slug in ['court-a', 'court-b', 'court-c'])
          BookingService.fromJson({
            'slug': slug,
            'name': slug,
            'durationMinutes': 60,
            'priceDisplay': '₱100',
            'allowBookingQuantity': true,
            'bookingQuantityLabel': 'Hours',
            'imageUrl': 'https://example.invalid/court.png',
          }),
        BookingService.fromJson({
          'slug': 'lesson',
          'name': 'Lesson',
          'durationMinutes': 30,
        }),
      ];
      await tester.pumpWidget(
        ShadcnApp(
          home: BookingPage(
            repository: BookingRepository(api),
            vendor: const VendorSummary(
              slug: 'club',
              name: 'Club',
              queueAvailable: false,
            ),
            location: const VendorLocation(
              id: 'main',
              name: 'Main',
              slug: 'main',
            ),
            services: services,
            selected: {'court-a', 'court-b', 'lesson'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      String value(String slug) => tester
          .widget<Text>(find.byKey(ValueKey('service-units-value-$slug')))
          .data!;
      Future<void> press(String key) async {
        final target = find.byKey(ValueKey(key));
        await reveal(tester, target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('service-row-court-a')),
          matching: find.byKey(const ValueKey('service-units-plus-court-a')),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('service-units-plus-lesson')),
        findsNothing,
      );
      final initialRequests = api.requests;
      await press('service-units-plus-court-a');
      expect(api.requests, initialRequests + 1);
      expect(
        [value('court-a'), value('court-b'), value('court-c')],
        ['2', '2', '2'],
      );
      await reveal(tester, find.text('One after another'));
      await tester.tap(find.text('One after another'));
      await tester.pumpAndSettle();
      await press('service-units-plus-court-b');
      await press('service-units-plus-court-b');
      await press('service-units-minus-court-a');
      expect([value('court-a'), value('court-b')], ['1', '4']);
      expect(api.last?['executionMode'], 'sequential');
      await reveal(tester, find.text('Together'));
      await tester.tap(find.text('Together'));
      await tester.pumpAndSettle();
      expect(
        [value('court-a'), value('court-b'), value('court-c')],
        ['4', '4', '4'],
      );
      expect(api.last?['executionMode'], 'parallel');
      expect(api.last?['items'], [
        {'serviceSlug': 'court-a', 'bookingQuantity': 4},
        {'serviceSlug': 'court-b', 'bookingQuantity': 4},
        {'serviceSlug': 'lesson', 'bookingQuantity': 1},
      ]);
      await press('service-toggle-court-c');
      expect((api.last?['items'] as List).last, {
        'serviceSlug': 'lesson',
        'bookingQuantity': 1,
      });
      expect((api.last?['items'] as List)[2], {
        'serviceSlug': 'court-c',
        'bookingQuantity': 4,
      });
      for (var i = 0; i < 4; i++) {
        await press('service-units-minus-court-b');
      }
      expect(
        [value('court-a'), value('court-b'), value('court-c')],
        ['1', '1', '1'],
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('service-units-minus-court-b')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('service thumbnail opens zoom viewer without selecting service', (
    tester,
  ) async {
    final service = BookingService.fromJson({
      ..._service,
      'imageUrl': 'https://example.com/service.png',
    });
    expect(service.imageUrl, 'https://example.com/service.png');
    var toggles = 0;
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: ServiceSelection(
            services: [
              service,
              const BookingService(slug: 'plain', name: 'No image'),
            ],
            selected: {},
            onToggle: (_) => toggles++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('service-thumbnail-plain')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('service-thumbnail-consult')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking-image-viewer')), findsOneWidget);
    expect(toggles, 0);
    await tester.tap(find.byKey(const Key('booking-image-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking-image-viewer')), findsNothing);
    expect(
      find.byKey(const ValueKey('service-toggle-consult')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('booking footer remains above the keyboard on a phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShadcnApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewInsets: EdgeInsets.only(bottom: 320),
            padding: EdgeInsets.only(top: 44),
          ),
          child: BookingPage(
            repository: BookingRepository(_BookingApi()),
            vendor: const VendorSummary(
              slug: 'clinic',
              name: 'Clinic',
              queueAvailable: false,
              bookingAvailable: true,
            ),
            location: const VendorLocation(
              id: 'primary',
              name: 'Main',
              slug: 'primary',
            ),
            services: [BookingService.fromJson(_service)],
            selected: {'consult'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.text('Verify email to continue')).dy,
      lessThanOrEqualTo(524),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Lists cards open Tickets and Bookings and return to Lists', (
    tester,
  ) async {
    await tester.pumpWidget(const ShadcnApp(home: CustomerShell()));
    await tester.tap(find.text('Lists'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lists-tickets')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tickets-page')), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lists-bookings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bookings-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('primary location selects services and switching clears them', (
    tester,
  ) async {
    final api = _BookingApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: VendorDetailPage(
          vendor: const VendorSummary(
            slug: 'clinic',
            name: 'Clinic',
            queueAvailable: false,
          ),
          repository: DirectoryRepository(_DirectoryApi()),
          bookingRepository: BookingRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.paths.first, contains('/locations/primary/services'));
    await reveal(tester, find.byKey(const ValueKey('service-toggle-consult')));
    await tester.tap(find.byKey(const ValueKey('service-toggle-consult')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 services selected'), findsOneWidget);
    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('booking-form-page')), findsOneWidget);
    expect(
      ModalRoute.of(tester.element(find.byType(BookingPage))),
      isA<SwipeBackPageRoute<CustomerBooking>>(),
    );
    await tester.tap(find.bySemanticsLabel('Back').last);
    await tester.pumpAndSettle();
    expect(find.byType(BookingPage), findsNothing);
    expect(find.textContaining('1 services selected'), findsOneWidget);
    await reveal(tester, find.byKey(const ValueKey('vendor-location-other')));
    await tester.tap(find.byKey(const ValueKey('vendor-location-other')));
    await tester.pumpAndSettle();
    expect(find.textContaining('services selected'), findsNothing);
    expect(api.paths.last, contains('/locations/other/services'));
    final join = tester.widget<OutlineButton>(
      find.byType(OutlineButton).last,
    ); // footer Book is outline
    expect(join.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('location selection keeps the vendor page scroll position', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShadcnApp(
        home: VendorDetailPage(
          vendor: const VendorSummary(
            slug: 'clinic',
            name: 'Clinic',
            queueAvailable: false,
          ),
          repository: DirectoryRepository(_LongLocationsApi()),
          bookingRepository: BookingRepository(_ManyServicesApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final other = find.byKey(const ValueKey('vendor-location-other'));
    await reveal(tester, other);
    final scrollable = find.descendant(
      of: find.byKey(const Key('vendor-details-scroll')),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    final offset = position.pixels;
    final headerTop = tester.getTopLeft(other).dy;
    expect(offset, greaterThan(200));
    await tester.tap(other);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(other).dy, closeTo(headerTop, 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'booking list separates upcoming from history and handles retry',
    (tester) async {
      final api = _BookingApi()..failList = true;
      await tester.pumpWidget(
        ShadcnApp(home: BookingsPage(repository: BookingRepository(api))),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not load bookings'), findsOneWidget);
      api.failList = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Upcoming Vendor'), findsOneWidget);
      expect(find.text('Past Vendor'), findsNothing);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.byType(RefreshTrigger), findsNothing);
      expect(find.text('Past Vendor'), findsOneWidget);
      expect(find.text('Upcoming Vendor'), findsNothing);
    },
  );
  testWidgets(
    'booking page uses OTP-bound payload, blocks duplicates and completes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _BookingApi()..createGate = Completer<void>();
      CustomerBooking? created;
      final service = BookingService.fromJson(_service);
      await tester.pumpWidget(
        ShadcnApp(
          home: DrawerOverlay(
            child: Scaffold(
              child: Builder(
                builder: (context) => PrimaryButton(
                  onPressed: () async {
                    created = await Navigator.of(context).push<CustomerBooking>(
                      SwipeBackPageRoute<CustomerBooking>(
                        builder: (_) => BookingPage(
                          repository: BookingRepository(api),
                          vendor: const VendorSummary(
                            slug: 'clinic',
                            name: 'Clinic',
                            queueAvailable: false,
                            bookingAvailable: true,
                          ),
                          location: const VendorLocation(
                            id: 'primary',
                            name: 'Main',
                            slug: 'primary',
                          ),
                          services: [service],
                          selected: {'consult'},
                          customer: const AuthUser(
                            id: 'customer',
                            email: 'customer@example.com',
                            profileName: 'Customer',
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open booking'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open booking'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('09:00'));
      await tester.tap(find.text('09:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify email to continue'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('booking-otp-drawer')), findsOneWidget);
      expect(find.text('Verify email'), findsOneWidget);
      final detailsAction = find.byKey(const Key('booking-otp-details'));
      final submitAction = find.byKey(const Key('booking-otp-submit'));
      expect(
        tester.getTopLeft(detailsAction).dy,
        tester.getTopLeft(submitAction).dy,
      );
      expect(
        tester.getCenter(detailsAction).dx,
        lessThan(tester.getCenter(submitAction).dx),
      );
      final resend = find.byKey(const Key('booking-otp-resend'));
      expect(
        tester.getCenter(resend).dy,
        closeTo(tester.getCenter(find.byType(InputOTP)).dy, 1),
      );

      expect(api.otpPayload?['locationSlug'], 'primary');
      expect(api.otpPayload?['bundleItems'], [
        {'serviceSlug': 'consult', 'bookingQuantity': 1},
      ]);
      await reveal(tester, find.byType(InputOTP));
      await tester.enterText(
        find
            .descendant(
              of: find.byType(GetPrioOtpInput),
              matching: find.byType(EditableText),
            )
            .last,
        '123456',
      );
      await tester.pumpAndSettle();
      await tester.pump();
      expect(api.createCount, 1);
      final action = tester.widget<PrimaryButton>(
        find
            .ancestor(
              of: find.text('Please wait...'),
              matching: find.byType(PrimaryButton),
            )
            .first,
      );
      expect(action.onPressed, isNull);
      api.createGate!.complete();
      await tester.pumpAndSettle();
      expect(api.createCount, 1);
      expect(api.createPayload?['bookingVerificationToken'], 'verified');
      expect(created?.id, 'new-booking');
      expect(tester.takeException(), isNull);
    },
  );
}

const _service = {
  'slug': 'consult',
  'name': 'Consultation',
  'description': 'A consultation.',
  'priceDisplay': '₱100',
  'priceAmountCents': 10000,
  'durationMinutes': 30,
};

class _BookingApi implements BookingApi {
  final paths = <String>[];
  bool failList = false;
  int createCount = 0;
  Completer<void>? createGate;
  Map<String, dynamic>? otpPayload, createPayload;
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    paths.add(path);
    if (path.endsWith('/services')) {
      return {
        'services': [_service],
      };
    }
    if (path.endsWith('/slots')) {
      return {
        'slots': [
          {
            'startAt': '2030-01-01T09:00:00+08:00',
            'endAt': '2030-01-01T09:30:00+08:00',
            'isAvailable': true,
            'remainingCapacity': 1,
          },
        ],
      };
    }
    if (failList) throw StateError('offline');
    return {
      'bookings': [
        {
          'id': 'upcoming',
          'tenantName': 'Upcoming Vendor',
          'status': 'confirmed',
        },
        {'id': 'past', 'tenantName': 'Past Vendor', 'status': 'completed'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path.endsWith('/booking-otp')) {
      otpPayload = body;
      return {
        'otpId': 'otp',
        'deliveryTarget': 'customer@example.com',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
        'resendAvailableAt': DateTime.now().toIso8601String(),
      };
    }
    if (path.endsWith('/verify')) {
      return {'bookingVerificationToken': 'verified'};
    }
    createCount++;
    createPayload = body;
    if (createGate != null) await createGate!.future;
    return {
      'booking': {'id': 'new-booking', 'status': 'pending'},
    };
  }
}

class _DirectoryApi implements DirectoryApi {
  @override
  Future<Map<String, dynamic>> loadVendors({
    String? search,
    int limit = 20,
  }) async => {};
  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async => {
    'slug': 'clinic',
    'name': 'Clinic',
    'capabilities': {'booking': true, 'queue': false},
    'locations': [
      {
        'id': 'other',
        'slug': 'other',
        'name': 'Other',
        'openStatus': {'isOpen': true},
      },
      {
        'id': 'primary',
        'slug': 'primary',
        'name': 'Main',
        'isPrimary': true,
        'openStatus': {'isOpen': true},
      },
    ],
  };
}

class _LongLocationsApi extends _DirectoryApi {
  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async {
    final data = await super.loadVendor(tenantSlug);
    data['locations'] = (data['locations'] as List).reversed.toList();
    return data;
  }
}

class _ManyServicesApi extends _BookingApi {
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    if (path.endsWith('/services')) {
      return {
        'services': [
          for (var i = 0; i < 12; i++) {..._service, 'slug': 'service-$i'},
        ],
      };
    }
    return super.get(path, query: query);
  }
}

class _UnitsApi extends _BookingApi {
  Map<String, dynamic>? last;
  int requests = 0;
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (path.endsWith('/composed-slots')) {
      requests++;
      last = body;
      return {'slots': []};
    }
    return super.post(path, body);
  }
}
