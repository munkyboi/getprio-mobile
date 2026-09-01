import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/queue/join_ui.dart';
import 'package:getprio_mobile/queue/queue_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('uses the light theme by default', (tester) async {
    await tester.pumpWidget(
      GetPrioApp(
        authRepository: AuthRepository(
          api: UnusedAuthApi(),
          tokenStore: MemoryTokenStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<ShadcnApp>(find.byType(ShadcnApp));
    expect(app.themeMode, ThemeMode.light);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Email or username'), findsOneWidget);
    expect(find.text('you@example.com or username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('labels customer registration fields', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: RegisterPage(
          authRepository: AuthRepository(
            api: UnusedAuthApi(),
            tokenStore: MemoryTokenStore(),
          ),
          onAuthenticated: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('e.g. Carlo Abella'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Create a password'), findsOneWidget);
  });

  testWidgets('labels password recovery field', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: PasswordRecoveryPage(
          authRepository: AuthRepository(
            api: UnusedAuthApi(),
            tokenStore: MemoryTokenStore(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('you@example.com'), findsOneWidget);
  });

  testWidgets('shows the customer home dashboard', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(home: const CustomerShell(user: AuthUserForTest.user)),
    );

    expect(find.text('Good morning, Carlo'), findsOneWidget);
    expect(find.text('Your queue activity at a glance'), findsNothing);
    expect(find.text('Scan to join'), findsOneWidget);
    expect(find.byKey(const Key('home-page')), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('shows five menu items and opens QR joining from the center', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShadcnApp(
        home: const MediaQuery(
          data: MediaQueryData(size: Size(375, 667)),
          child: CustomerShell(user: AuthUserForTest.user),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Join Queue'), findsOneWidget);
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.byType(NavigationItem), findsNWidgets(4));
    expect(find.byType(NavigationButton), findsOneWidget);

    final homeLabel = tester.widget<Text>(find.text('Home'));
    final exploreLabel = tester.widget<Text>(find.text('Explore'));
    final joinLabel = tester.widget<Text>(find.text('Join Queue'));
    expect(homeLabel.style?.fontWeight, exploreLabel.style?.fontWeight);
    expect(homeLabel.style?.fontSize, exploreLabel.style?.fontSize);
    expect(joinLabel.style?.fontSize, homeLabel.style?.fontSize);
    expect(joinLabel.style?.color, GetPrioTheme.orange);

    final joinCircle = find.byKey(const Key('join-queue-menu-circle'));
    final joinLabelKey = find.byKey(const Key('join-queue-menu-label'));
    expect(joinCircle, findsOneWidget);
    expect(joinLabelKey, findsOneWidget);
    expect(
      tester.getBottomLeft(joinCircle).dy,
      lessThan(tester.getTopLeft(joinLabelKey).dy),
    );
    final joinIcon = tester.widget<Icon>(
      find.descendant(of: joinCircle, matching: find.byType(Icon)),
    );
    expect(joinIcon.size, greaterThanOrEqualTo(32));
    expect(
      tester.getTopLeft(find.byKey(const Key('join-queue-menu-action'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('customer-main-menu'))).dy,
      ),
    );

    await tester.tap(find.byKey(const Key('join-queue-menu-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(QrScannerPage), findsOneWidget);
  });

  testWidgets('centers phone action button content', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShadcnApp(
        home: const MediaQuery(
          data: MediaQueryData(size: Size(375, 667)),
          child: CustomerShell(user: AuthUserForTest.user),
        ),
      ),
    );

    final action = find.byKey(const Key('scan-to-join-button'));
    final button = tester.widget<PrimaryButton>(
      find.descendant(of: action, matching: find.byType(PrimaryButton)),
    );
    expect(button.alignment, Alignment.center);
    expect(
      tester.getCenter(find.text('Scan to join')).dx,
      closeTo(tester.getCenter(action).dx, 0.5),
    );
  });

  testWidgets('opens queue joining from the Home scan action', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(home: const CustomerShell(user: AuthUserForTest.user)),
    );

    await tester.ensureVisible(find.byKey(const Key('scan-to-join-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-to-join-button')));
    await tester.pumpAndSettle();

    expect(find.text('Scan to join'), findsOneWidget);
    expect(find.text('Scan QR code'), findsOneWidget);
  });

  testWidgets('switches between customer areas', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(home: const CustomerShell(user: AuthUserForTest.user)),
    );

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    expect(find.text('Explore vendors'), findsOneWidget);
    expect(find.byKey(const Key('explore-page')), findsOneWidget);
  });

  testWidgets('filters the vendor directory by search and category', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: ExplorePage(repository: DirectoryRepository(FakeDirectoryApi())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Open now'), findsOneWidget);
    expect(find.byKey(const ValueKey('vendor-filter-Clinic')), findsOneWidget);
    expect(find.text('City Clinic'), findsOneWidget);
    expect(find.text('Quick Bank'), findsOneWidget);
    expect(find.text('Closed Lab'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vendor-filter-Open now')));
    await tester.pump();

    expect(find.text('City Clinic'), findsOneWidget);
    expect(find.text('Quick Bank'), findsOneWidget);
    expect(find.text('Closed Lab'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('vendor-filter-Bank')));
    await tester.pump();

    expect(find.text('City Clinic'), findsNothing);
    expect(find.text('Quick Bank'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vendor-filter-All')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('vendor-search-field')),
      'clinic',
    );
    await tester.pump();

    expect(find.text('City Clinic'), findsOneWidget);
    expect(find.text('Quick Bank'), findsNothing);
  });

  testWidgets('separates active tickets from lightweight history', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketsPage(
          ticketRepository: QueueTicketRepository(FakeAccountQueueApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('active-ticket-active-1')),
      findsOneWidget,
    );
    expect(find.text('Queue progress'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('tickets-page')),
      const Offset(0, -600),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('History'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('history-ticket-history-1')),
      findsOneWidget,
    );
  });

  testWidgets('refreshes the Home ticket when the repository signals', (
    tester,
  ) async {
    final api = FakeAccountQueueApi();
    final repository = QueueTicketRepository(api);
    await tester.pumpWidget(
      ShadcnApp(
        home: HomePage(
          user: AuthUserForTest.user,
          ticketRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.overviewCalls, 1);

    repository.requestRefresh();
    await tester.pumpAndSettle();

    expect(api.overviewCalls, 2);
    expect(find.text('#101'), findsOneWidget);
  });

  testWidgets('confirms cancellation in a destructive dialog', (tester) async {
    final queueApi = FakeQueueApi();
    await tester.pumpWidget(
      ShadcnApp(
        home: TicketsPage(
          ticketRepository: QueueTicketRepository(FakeAccountQueueApi()),
          queueRepository: QueueRepository(queueApi),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cancel ticket'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel ticket'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cancel-ticket-dialog')), findsOneWidget);
    expect(find.text('Cancel this ticket?'), findsOneWidget);

    await tester.tap(find.text('Keep ticket'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cancel-ticket-dialog')), findsNothing);
    expect(queueApi.cancelCalled, isFalse);
  });

  testWidgets('uses grouped Account rows with one profile card', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(home: const AccountPage(user: AuthUserForTest.user)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Queue alerts unavailable'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });
}

class AuthUserForTest {
  static const user = AuthUser(
    id: 'user-1',
    email: 'customer@example.com',
    profileName: 'Profile name',
    displayName: 'Carlo',
  );
}

class UnusedAuthApi implements AuthApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('This test does not call the auth API.');
}

class FakeDirectoryApi implements DirectoryApi {
  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async => {
    'slug': tenantSlug,
    'name': 'City Clinic',
    'queueAvailable': true,
  };

  @override
  Future<Map<String, dynamic>> loadVendors({
    String? search,
    int limit = 20,
  }) async => {
    'vendors': [
      {
        'slug': 'city-clinic',
        'name': 'City Clinic',
        'category': 'Clinic',
        'queueAvailable': true,
        'locations': [
          {'id': 'clinic-1', 'name': 'Main Clinic', 'queueAvailable': true},
        ],
      },
      {
        'slug': 'quick-bank',
        'name': 'Quick Bank',
        'category': 'Bank',
        'queueAvailable': true,
        'locations': [
          {'id': 'bank-1', 'name': 'Downtown', 'queueAvailable': true},
        ],
      },
      {
        'slug': 'closed-lab',
        'name': 'Closed Lab',
        'category': 'Lab',
        'queueAvailable': true,
        'locations': [
          {'id': 'lab-1', 'name': 'Testing Center', 'queueAvailable': false},
        ],
      },
    ],
  };
}

class FakeAccountQueueApi implements AccountQueueApi {
  int overviewCalls = 0;

  @override
  Future<Map<String, dynamic>> loadOverview() async {
    overviewCalls++;
    return {
      'tickets': [
        {
          'id': 'active-1',
          'lookupCode': 'ACTIVE1',
          'ticketNumber': 101,
          'customerName': 'Carlo',
          'status': 'waiting',
          'position': 3,
          'estimatedWaitMinutes': 12,
          'vendorName': 'City Clinic',
          'locationName': 'Main Clinic',
          'tenantSlug': 'city-clinic',
          'joinedAt': '2026-09-01T01:30:00.000Z',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => {
    'items': [
      {
        'id': 'history-1',
        'lookupCode': 'HISTORY1',
        'ticketNumber': 88,
        'customerName': 'Carlo',
        'status': 'served',
        'vendorName': 'Quick Bank',
        'locationName': 'Downtown',
        'joinedAt': '2026-08-31T01:30:00.000Z',
      },
    ],
  };
}

class FakeQueueApi implements QueueApi {
  bool cancelCalled = false;

  @override
  Future<Map<String, dynamic>> cancelTicket({
    required String tenantSlug,
    required String lookupCode,
    String? locationSlug,
  }) async {
    cancelCalled = true;
    return const {};
  }

  @override
  Future<Map<String, dynamic>> loadQueueSnapshot({
    required String tenantSlug,
    String? locationSlug,
    String? lookupCode,
  }) async => const {};
}
