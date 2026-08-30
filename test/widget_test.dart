import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/main.dart';

void main() {
  testWidgets('shows the customer home dashboard', (tester) async {
    await tester.pumpWidget(const GetPrioApp());

    expect(find.text('Good morning, Carlo'), findsOneWidget);
    expect(find.text('Scan to join'), findsOneWidget);
    expect(find.byKey(const Key('home-page')), findsOneWidget);
  });

  testWidgets('switches between customer areas', (tester) async {
    await tester.pumpWidget(const GetPrioApp());

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    expect(find.text('Explore vendors'), findsOneWidget);
    expect(find.byKey(const Key('explore-page')), findsOneWidget);
  });
}
