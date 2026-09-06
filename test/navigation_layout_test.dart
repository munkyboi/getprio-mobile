import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('keeps the customer shell vertically compact', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ShadcnApp(
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(375, 667),
            padding: EdgeInsets.only(top: 24, bottom: 34),
          ),
          child: CustomerShell(
            user: AuthUser(
              id: 'user-1',
              email: 'customer@example.com',
              displayName: 'Carlo',
            ),
          ),
        ),
      ),
    );

    final navigationBar = tester.widget<NavigationBar>(
      find.byKey(const Key('customer-main-menu')),
    );
    expect(navigationBar.padding, const EdgeInsets.fromLTRB(12, 0, 12, 0));

    final homePage = tester.widget<ListView>(
      find.byKey(const Key('home-page')),
    );
    expect(homePage.padding, const EdgeInsets.fromLTRB(20, 0, 20, 20));

    for (final key in const ['explore-page', 'tickets-page', 'account-page']) {
      final page = tester.widget<ListView>(
        find.byKey(Key(key), skipOffstage: false),
      );
      expect(page.padding, const EdgeInsets.fromLTRB(20, 0, 20, 20));
    }
  });

  testWidgets('opens the profile area from the customer navigation bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShadcnApp(
        home: CustomerShell(
          user: AuthUser(
            id: 'user-1',
            email: 'customer@example.com',
            displayName: 'Carlo',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-page')), findsOneWidget);
    expect(find.text('Manage your profile and app preferences.'), findsOneWidget);
  });
}
