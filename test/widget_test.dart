import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_models.dart';
import 'package:getprio_mobile/main.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('shows the customer home dashboard', (tester) async {
    await tester.pumpWidget(
      ShadcnApp(home: const CustomerShell(user: AuthUserForTest.user)),
    );

    expect(find.text('Good morning, Carlo'), findsOneWidget);
    expect(find.text('Scan to join'), findsOneWidget);
    expect(find.byKey(const Key('home-page')), findsOneWidget);
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
