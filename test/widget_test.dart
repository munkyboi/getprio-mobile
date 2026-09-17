import 'support/memory_onboarding_store.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/app_theme.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/directory/directory_repository.dart';
import 'package:getprio_mobile/directory/vendor_contact.dart';
import 'package:getprio_mobile/main.dart';
import 'package:getprio_mobile/loading_skeleton.dart';
import 'package:getprio_mobile/queue/join_repository.dart';
import 'package:getprio_mobile/queue/join_ui.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:getprio_mobile/queue/queue_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  test('uses the display name or first profile name in greetings', () {
    expect(
      homeGreetingName(
        const AuthUser(
          id: 'user-1',
          email: 'customer@example.com',
          profileName: 'Ava Reyes',
          displayName: 'Ava R.',
        ),
      ),
      'Ava R.',
    );
    expect(
      homeGreetingName(
        const AuthUser(
          id: 'user-2',
          email: 'customer@example.com',
          profileName: 'Carlo Abella',
        ),
      ),
      'Carlo',
    );
    expect(
      homeGreetingName(
        const AuthUser(id: 'user-3', email: 'customer@example.com'),
      ),
      'there',
    );
  });

  testWidgets('shows the centered logo while the session is restoring', (
    tester,
  ) async {
    await tester.pumpWidget(ShadcnApp(home: const SplashLoadingScreen()));

    final splash = find.byKey(const Key('splash-loading-screen'));
    final logo = find.byKey(const Key('splash-logo'));
    expect(splash, findsOneWidget);
    expect(logo, findsOneWidget);
    expect(
      tester.getCenter(logo).dx,
      closeTo(tester.getCenter(splash).dx, 0.5),
    );
    expect(
      tester.getCenter(logo).dy,
      closeTo(tester.getCenter(splash).dy, 0.5),
    );
  });

  testWidgets('builds the shared skeleton layouts for preload surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: SingleChildScrollView(
          child: Column(
            children: const [
              HomeActiveTicketSkeleton(),
              VendorDirectorySkeleton(itemCount: 2),
              VendorDetailsSkeleton(),
              LiveQueueStatusSkeleton(),
              TicketsSkeleton(),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(GetPrioSkeleton), findsNWidgets(5));
    expect(find.byType(SkeletonBlock), findsWidgets);
    expect(
      find.byKey(const Key('home-active-ticket-skeleton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-active-ticket-progress-skeleton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-active-ticket-action-skeleton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('tickets-active-ticket-progress-skeleton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('tickets-active-ticket-action-skeleton')),
      findsOneWidget,
    );
    for (var index = 0; index < 3; index++) {
      expect(
        find.byKey(ValueKey('tickets-history-skeleton-$index')),
        findsOneWidget,
      );
    }
  });

  testWidgets('uses the light theme by default', (tester) async {
    await tester.pumpWidget(
      GetPrioApp(
        onboardingStore: MemoryOnboardingStore(completed: true),
        authRepository: AuthRepository(
          api: UnusedAuthApi(),
          tokenStore: MemoryTokenStore(),
        ),
      ),
    );
    expect(find.byType(SplashLoadingScreen), findsOneWidget);
    await tester.pumpAndSettle();

    final app = tester.widget<ShadcnApp>(find.byType(ShadcnApp));
    expect(app.themeMode, ThemeMode.light);
    expect(find.byType(SvgPicture), findsNothing);
    expect(
      find.image(const AssetImage('assets/branding/login-biometric-scene.png')),
      findsOneWidget,
    );
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

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('e.g. Carlo Abella'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Create a password'), findsOneWidget);
  });

  testWidgets('auto-generates a username from the display name', (
    tester,
  ) async {
    final api = UsernameAvailabilityAuthApi(available: true);
    await tester.pumpWidget(
      ShadcnApp(
        home: RegisterPage(
          authRepository: AuthRepository(
            api: api,
            tokenStore: MemoryTokenStore(),
          ),
          onAuthenticated: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('register-full-name')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('register-username')));
    await tester.pump();

    final initiallyEmptyUsername = tester.widget<TextField>(
      find.byKey(const Key('register-username')),
    );
    expect(initiallyEmptyUsername.controller?.text, isEmpty);

    await tester.enterText(
      find.byKey(const Key('register-full-name')),
      'Jane Doe',
    );
    await tester.pump();

    final usernameField = tester.widget<TextField>(
      find.byKey(const Key('register-username')),
    );
    expect(usernameField.controller?.text, isEmpty);

    await tester.tap(find.byKey(const Key('register-username')));
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();

    final generatedUsername = tester.widget<TextField>(
      find.byKey(const Key('register-username')),
    );
    expect(generatedUsername.controller?.text, 'jane_doe');
  });

  testWidgets(
    'keeps a manually edited username when the display name changes',
    (tester) async {
      final api = UsernameAvailabilityAuthApi(available: true);
      await tester.pumpWidget(
        ShadcnApp(
          home: RegisterPage(
            authRepository: AuthRepository(
              api: api,
              tokenStore: MemoryTokenStore(),
            ),
            onAuthenticated: (_) {},
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('register-full-name')),
        'Jane Doe',
      );
      await tester.enterText(
        find.byKey(const Key('register-username')),
        'custom_name',
      );
      await tester.enterText(
        find.byKey(const Key('register-full-name')),
        'Another Person',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      final usernameField = tester.widget<TextField>(
        find.byKey(const Key('register-username')),
      );
      expect(usernameField.controller?.text, 'custom_name');
      expect(api.checkedUsernames, ['custom_name']);
    },
  );

  testWidgets('asynchronously verifies the generated username is available', (
    tester,
  ) async {
    final api = UsernameAvailabilityAuthApi(available: true);
    await tester.pumpWidget(
      ShadcnApp(
        home: RegisterPage(
          authRepository: AuthRepository(
            api: api,
            tokenStore: MemoryTokenStore(),
          ),
          onAuthenticated: (_) {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('register-full-name')),
      'Jane Doe',
    );
    await tester.pump();
    expect(find.text('Checking username...'), findsNothing);

    await tester.tap(find.byKey(const Key('register-username')));
    await tester.pump();
    expect(find.text('Checking username...'), findsNothing);

    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();

    expect(api.checkedUsernames, ['jane_doe']);
    expect(find.text('Username is available.'), findsOneWidget);
  });

  testWidgets('does not submit a username that is no longer available', (
    tester,
  ) async {
    final api = UsernameAvailabilityAuthApi(available: false);
    await tester.pumpWidget(
      ShadcnApp(
        home: RegisterPage(
          authRepository: AuthRepository(
            api: api,
            tokenStore: MemoryTokenStore(),
          ),
          onAuthenticated: (_) {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('register-full-name')),
      'Jane Doe',
    );
    await tester.tap(find.byKey(const Key('register-username')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final submitButton = find.byKey(const Key('register-submit'));
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DestructiveBadge), findsNothing);
    expect(find.text('That username is already taken.'), findsOneWidget);
    expect(api.registrationCalls, 0);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shows debounced password strength and requirements', (
    tester,
  ) async {
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

    await tester.enterText(
      find.byKey(const Key('register-password')),
      'Upper!12',
    );
    await tester.pump();
    expect(find.byKey(const Key('register-password-strength')), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('register-password-strength')), findsOneWidget);
    expect(find.text('Strong'), findsOneWidget);
    expect(find.text('At least 2 numbers'), findsOneWidget);
  });

  testWidgets('moves to email OTP verification after valid registration', (
    tester,
  ) async {
    final api = RegistrationOtpAuthApi();
    var authenticated = false;
    await tester.pumpWidget(
      ShadcnApp(
        home: RegisterPage(
          authRepository: AuthRepository(
            api: api,
            tokenStore: MemoryTokenStore(),
          ),
          onAuthenticated: (_) => authenticated = true,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('register-full-name')),
      'Jane Doe',
    );
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('register-username')),
      'jane_doe',
    );
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'jane+signup@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'Upper!12',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pumpAndSettle();

    expect(api.startCalls, 1);
    expect(api.startEmail, 'jane+signup@example.com');
    expect(find.byKey(const Key('register-otp-screen')), findsOneWidget);
    expect(find.textContaining('j***@example.com'), findsOneWidget);
    expect(authenticated, isFalse);

    await tester.enterText(find.byKey(const Key('register-otp')), '123456');
    await tester.tap(find.byKey(const Key('register-otp-submit')));
    await tester.pumpAndSettle();

    expect(authenticated, isTrue);
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

    final greeting = find.textContaining(', Carlo');
    expect(greeting, findsOneWidget);
    final greetingText = tester.widget<Text>(greeting).data!;
    expect(
      homeGreetingOpeners,
      contains(greetingText.replaceFirst(', Carlo', '')),
    );
    expect(find.text('Your queue activity at a glance'), findsNothing);
    expect(find.text('Scan to join'), findsOneWidget);
    expect(find.byKey(const Key('home-page')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('home-page')),
        matching: find.byType(Card),
      ),
      findsOneWidget,
    );
  });

  testWidgets('centers the empty active ticket card contents', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(home: const CustomerShell(user: AuthUserForTest.user)),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('empty-active-ticket-card'));
    final cardCenter = tester.getCenter(card).dx;
    for (final label in const [
      'Active ticket',
      'No active tickets',
      'Scan a vendor QR code when you are ready to join.',
    ]) {
      expect(tester.getCenter(find.text(label)).dx, closeTo(cardCenter, 0.5));
    }
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
    expect(find.text('Profile'), findsOneWidget);
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

  testWidgets('opens the scanner directly from the Home scan action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(home: const CustomerShell(user: AuthUserForTest.user)),
    );

    await tester.ensureVisible(find.byKey(const Key('scan-to-join-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scan-to-join-button')));
    await tester.pumpAndSettle();

    expect(find.byType(QrScannerPage), findsOneWidget);
    expect(find.text('Join a queue'), findsNothing);
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

  testWidgets('pulls down to refresh vendor details with short content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = FakeDirectoryApi();
    final repository = DirectoryRepository(api);

    await tester.pumpWidget(
      ShadcnApp(
        home: VendorDetailPage(
          vendor: const VendorSummary(
            slug: 'city-clinic',
            name: 'City Clinic',
            queueAvailable: true,
            category: 'Clinic',
            locations: [
              VendorLocation(
                id: 'clinic-1',
                name: 'Main Clinic',
                queueAvailable: true,
              ),
            ],
          ),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.vendorDetailCalls, 1);
    expect(find.text('City Clinic'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('vendor-details-scroll')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();

    expect(api.vendorDetailCalls, 2);
    expect(find.text('City Clinic refreshed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'centers the vendor logo over the cover and places contact action',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var joinQueueCalls = 0;

      await tester.pumpWidget(
        ShadcnApp(
          home: VendorDetailPage(
            vendor: const VendorSummary(
              slug: 'city-clinic',
              name: 'City Clinic',
              queueAvailable: true,
            ),
            repository: DirectoryRepository(FakeDirectoryApi()),
            contactLauncher: FakeVendorContactLauncher(),
            onJoinQueue: () => joinQueueCalls++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cover = tester.getRect(
        find.byKey(const Key('vendor-profile-cover')),
      );
      final logo = tester.getRect(find.byKey(const Key('vendor-logo')));
      final surface = tester.getRect(
        find.byKey(const Key('vendor-detail-surface')),
      );
      final contact = tester.getRect(
        find.byKey(const Key('vendor-contact-button')),
      );

      expect(logo.center.dx, closeTo(cover.center.dx, 0.5));
      expect(logo.center.dy, closeTo(cover.center.dy, 0.5));
      expect(surface.top, lessThan(cover.bottom));
      expect(contact.center.dx, greaterThan(surface.center.dx));
      expect(contact.top, lessThan(surface.top + 120));
      expect(find.byKey(const Key('vendor-join-queue-button')), findsOneWidget);
      final actionSurface = tester.widget<Container>(
        find.byKey(const Key('vendor-join-queue-action-surface')),
      );
      expect(actionSurface.color, GetPrioTheme.paper);

      await tester.tap(find.byKey(const Key('vendor-join-queue-button')));
      expect(joinQueueCalls, 1);
    },
  );

  testWidgets(
    'vendor detail Join Queue opens direct secure checkout without scanning',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final joinApi = FakeDirectJoinApi();

      await tester.pumpWidget(
        ShadcnApp(
          home: CustomerShell(
            user: AuthUserForTest.user,
            joinRepository: JoinRepository(joinApi),
            directoryRepository: DirectoryRepository(FakeDirectoryApi()),
            allowedHosts: const {'app.getprio.test'},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('City Clinic'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vendor-join-queue-button')));
      await tester.pumpAndSettle();

      expect(find.byType(QrScannerPage), findsNothing);
      expect(find.byKey(const Key('direct-join-flow-shell')), findsOneWidget);
      expect(find.byKey(const Key('checkout-bottom-sheet')), findsOneWidget);
      expect(find.text('Secure checkout'), findsOneWidget);
      expect(find.text('PHP 20.00'), findsOneWidget);
      expect(joinApi.directJoinCalls, 1);
      expect(joinApi.lastTenantSlug, 'city-clinic');
    },
  );

  testWidgets('opens and submits the vendor contact bottom sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final launcher = FakeVendorContactLauncher();

    await tester.pumpWidget(
      ShadcnApp(
        home: VendorDetailPage(
          vendor: const VendorSummary(
            slug: 'city-clinic',
            name: 'City Clinic',
            queueAvailable: true,
          ),
          repository: DirectoryRepository(FakeDirectoryApi()),
          contactLauncher: launcher,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('vendor-contact-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vendor-contact-sheet')), findsOneWidget);
    expect(find.text('Contact City Clinic'), findsOneWidget);
    expect(find.text('hello@cityclinic.example'), findsOneWidget);
    expect(find.bySemanticsLabel('Close contact form'), findsOneWidget);

    final sheetOverlay = tester.widget<DrawerWrapper>(
      find.byWidgetPredicate((widget) => widget is DrawerWrapper),
    );
    expect(
      sheetOverlay.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(28)),
    );
    final sheetSurface = tester.widget<Container>(
      find.byKey(const Key('vendor-contact-sheet')),
    );
    final sheetDecoration = sheetSurface.decoration! as BoxDecoration;
    expect(
      sheetDecoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(28)),
    );
    expect(sheetSurface.clipBehavior, Clip.antiAlias);

    await tester.enterText(
      find.byKey(const Key('vendor-contact-subject')),
      'Queue hours',
    );
    await tester.enterText(
      find.byKey(const Key('vendor-contact-message')),
      'Are you open this afternoon?',
    );
    await tester.tap(find.byKey(const Key('vendor-contact-continue')));
    await tester.pumpAndSettle();

    expect(launcher.recipient, 'hello@cityclinic.example');
    expect(launcher.subject, 'Queue hours');
    expect(launcher.message, 'Are you open this afternoon?');
    expect(find.byKey(const Key('vendor-contact-sheet')), findsNothing);
  });

  testWidgets('retries unavailable vendor details with the inline action', (
    tester,
  ) async {
    final api = FakeDirectoryApi(failFirstVendorDetail: true);

    await tester.pumpWidget(
      ShadcnApp(
        home: VendorDetailPage(
          vendor: const VendorSummary(
            slug: 'city-clinic',
            name: 'City Clinic',
            queueAvailable: true,
          ),
          repository: DirectoryRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vendor details are unavailable.'), findsOneWidget);
    expect(find.byKey(const Key('retry-vendor-details')), findsOneWidget);

    await tester.tap(find.byKey(const Key('retry-vendor-details')));
    await tester.pumpAndSettle();

    expect(api.vendorDetailCalls, 2);
    expect(find.text('City Clinic refreshed'), findsOneWidget);
    expect(find.text('Vendor details are unavailable.'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('handles a failed vendor detail refresh and offers retry', (
    tester,
  ) async {
    final api = FakeDirectoryApi(failAfterFirstVendorDetail: true);

    await tester.pumpWidget(
      ShadcnApp(
        home: VendorDetailPage(
          vendor: const VendorSummary(
            slug: 'city-clinic',
            name: 'City Clinic',
            queueAvailable: true,
          ),
          repository: DirectoryRepository(api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('vendor-details-scroll')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();

    expect(api.vendorDetailCalls, 2);
    expect(find.text('Vendor details are unavailable.'), findsOneWidget);
    expect(find.byKey(const Key('retry-vendor-details')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
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
    expect(
      find.descendant(
        of: find.byKey(const Key('tickets-page')),
        matching: find.byType(Card),
      ),
      findsOneWidget,
    );

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

  testWidgets('shows a success toast after ticket cancellation', (
    tester,
  ) async {
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
    await tester.tap(find.text('Cancel ticket'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('cancel-ticket-dialog')),
        matching: find.text('Cancel ticket'),
      ),
    );
    await tester.pumpAndSettle();

    expect(queueApi.cancelCalled, isTrue);
    expect(find.text('Ticket cancelled.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('shows an error toast when ticket cancellation fails', (
    tester,
  ) async {
    final queueApi = FakeQueueApi(cancelShouldFail: true);
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
    await tester.tap(find.text('Cancel ticket'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('cancel-ticket-dialog')),
        matching: find.text('Cancel ticket'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not cancel ticket.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
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

class UsernameAvailabilityAuthApi extends UnusedAuthApi {
  UsernameAvailabilityAuthApi({required this.available});

  final bool available;
  final checkedUsernames = <String>[];
  int registrationCalls = 0;

  @override
  Future<Map<String, dynamic>> checkUsernameAvailability(
    String username,
  ) async {
    checkedUsernames.add(username);
    return {
      'username': username,
      'available': available,
      'valid': true,
      'message': available
          ? 'Username is available.'
          : 'That username is already taken.',
    };
  }

  @override
  Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String username,
    required String email,
    String? phone,
    required String password,
  }) async {
    registrationCalls++;
    throw StateError('Registration should be blocked by username checks.');
  }
}

class RegistrationOtpAuthApi extends UnusedAuthApi
    implements CustomerRegistrationApi {
  int startCalls = 0;
  String? startEmail;

  @override
  Future<Map<String, dynamic>> checkUsernameAvailability(
    String username,
  ) async => {
    'username': username,
    'available': true,
    'valid': true,
    'message': 'Username is available.',
  };

  @override
  Future<Map<String, dynamic>> startCustomerRegistration({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    startCalls++;
    startEmail = email;
    return {
      'challengeId': 'registration-challenge',
      'step': 'email_otp',
      'deliveryTarget': 'j***@example.com',
    };
  }

  @override
  Future<Map<String, dynamic>> verifyCustomerRegistration({
    required String challengeId,
    required String code,
  }) async => {
    'token': 'access-otp',
    'refreshToken': 'refresh-otp',
    'sessionExpiresAt': '2026-09-29T10:00:00Z',
    'user': {'id': 'user-1', 'email': 'jane@example.com'},
  };

  @override
  Future<Map<String, dynamic>> resendCustomerRegistrationCode({
    required String challengeId,
  }) async => {
    'challengeId': challengeId,
    'step': 'email_otp',
    'deliveryTarget': 'j***@example.com',
  };
}

class FakeDirectoryApi implements DirectoryApi {
  FakeDirectoryApi({
    this.failFirstVendorDetail = false,
    this.failAfterFirstVendorDetail = false,
  });

  final bool failFirstVendorDetail;
  final bool failAfterFirstVendorDetail;
  int vendorDetailCalls = 0;

  @override
  Future<Map<String, dynamic>> loadVendor(String tenantSlug) async {
    vendorDetailCalls++;
    if (failFirstVendorDetail && vendorDetailCalls == 1) {
      throw StateError('Vendor details request failed.');
    }
    if (failAfterFirstVendorDetail && vendorDetailCalls > 1) {
      throw StateError('Vendor details refresh failed.');
    }
    return {
      'slug': tenantSlug,
      'name': vendorDetailCalls == 1 ? 'City Clinic' : 'City Clinic refreshed',
      'category': 'Clinic',
      'description': '<p>Friendly neighborhood care.</p>',
      'queueAvailable': true,
      'locations': [
        {
          'id': 'clinic-1',
          'slug': 'main',
          'name': 'Main Clinic',
          'queueAvailable': true,
          'contactEmail': 'hello@cityclinic.example',
          'contactPhone': '+63 917 555 0100',
          'addressLine1': '10 Health Street',
          'city': 'Cebu City',
        },
      ],
    };
  }

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

class FakeDirectJoinApi implements JoinApi, DirectJoinApi {
  int directJoinCalls = 0;
  String? lastTenantSlug;

  @override
  Future<Map<String, dynamic>> resolve(String locationQrId) async => const {};

  @override
  Future<Map<String, dynamic>> join({
    required String locationQrId,
    required String joinAttemptId,
    required String customerName,
  }) async => const {};

  @override
  Future<Map<String, dynamic>> joinDirect({
    required String tenantSlug,
    String? locationSlug,
    required String joinAttemptId,
    required String customerName,
  }) async {
    directJoinCalls++;
    lastTenantSlug = tenantSlug;
    return {
      'paymentRequired': true,
      'paymentAttemptId': 'direct-attempt-1',
      'checkoutUrl': 'https://paymongo.example/checkout/direct',
      'tenantSlug': tenantSlug,
      'locationSlug': locationSlug ?? 'main-clinic',
      'queueFee': {'amountCents': 2000, 'currency': 'PHP'},
    };
  }
}

class FakeVendorContactLauncher implements VendorContactLauncher {
  String? recipient;
  String? subject;
  String? message;

  @override
  Future<bool> openEmail({
    required String recipient,
    required String subject,
    required String message,
  }) async {
    this.recipient = recipient;
    this.subject = subject;
    this.message = message;
    return true;
  }
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
  FakeQueueApi({this.cancelShouldFail = false});

  final bool cancelShouldFail;
  bool cancelCalled = false;

  @override
  Future<Map<String, dynamic>> cancelTicket({
    required String tenantSlug,
    required String lookupCode,
    String? locationSlug,
  }) async {
    cancelCalled = true;
    if (cancelShouldFail) throw StateError('cancel failed');
    return const {};
  }

  @override
  Future<Map<String, dynamic>> loadQueueSnapshot({
    required String tenantSlug,
    String? locationSlug,
    String? lookupCode,
  }) async => const {};
}
