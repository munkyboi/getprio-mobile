import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/main.dart';
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
    expect(find.byType(NavigationItem), findsNWidgets(4));
    expect(find.text('Join'), findsNothing);
  });

  testWidgets('opens queue joining from the Home scan action', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(home: const CustomerShell(user: AuthUserForTest.user)),
    );

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
