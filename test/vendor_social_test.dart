import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/account/ticket_repository.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:getprio_mobile/social/vendor_social_repository.dart';
import 'package:getprio_mobile/social/vendor_social_widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class SocialClient implements AuthenticatedApiClient {
  final vendors = List.generate(
    6,
    (i) => {'slug': 'vendor-$i', 'name': 'Business $i', 'category': 'Clinic'},
  );
  bool failDelete = false;
  int? rating;
  String? comment;
  int lastPage = 0;
  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? additionalHeaders,
  }) async {
    if (path.endsWith('/favorites')) return {'vendors': vendors};
    if (path.endsWith('/rating')) {
      return {
        'eligible': true,
        'rating': rating == null ? null : {'stars': rating},
      };
    }
    lastPage = int.parse(queryParameters!['page']!);
    final size = int.parse(queryParameters['pageSize']!);
    return {
      'rating': {'average': 4.5, 'count': 10000},
      'pagination': {'totalItems': 16, 'totalPages': (16 / size).ceil()},
      'reviews': List.generate(
        lastPage == 1 ? size : 6,
        (i) => {
          'id': '$lastPage-$i',
          'stars': 5,
          'comment': 'Review $lastPage-$i',
          'created_at': '2026-08-25T00:00:00Z',
          'customer_display_name': 'Mark S***h',
        },
      ),
    };
  }

  @override
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? additionalHeaders,
  }) async {
    if (failDelete) throw Exception('offline');
    vendors.removeWhere((vendor) => path.endsWith('/${vendor['slug']}'));
    return {'favorite': false};
  }

  @override
  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? additionalHeaders,
  }) async => {'favorite': true};
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? additionalHeaders,
  }) async {
    rating = body['stars'] as int;
    comment = body['comment'] as String;
    return {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'favorites persist only after successful deletion and notify all consumers',
    () async {
      final client = SocialClient();
      final repository = VendorSocialRepository(client);
      await repository.loadFavorites();
      client.failDelete = true;
      await expectLater(
        repository.setFavorite(repository.favorites!.first, false),
        throwsException,
      );
      expect(repository.favorites, hasLength(6));
      expect(repository.isPending('vendor-0'), isFalse);
      client.failDelete = false;
      await repository.setFavorite(repository.favorites!.first, false);
      expect(repository.contains('vendor-0'), isFalse);
      expect(repository.favorites, hasLength(5));
    },
  );
  testWidgets(
    'home shows at most five favorites and editor removes the sixth',
    (tester) async {
      final repository = VendorSocialRepository(SocialClient());
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: DrawerOverlay(
              child: SingleChildScrollView(
                child: FavoritesList(repository: repository, onOpen: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Business 4'), findsOneWidget);
      expect(find.text('Business 5'), findsNothing);
      expect(find.byIcon(LucideIcons.trash2), findsNothing);
      await tester.tap(find.text('View all favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Business 5'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('delete-favorite-vendor-5')),
      );
      await tester.tap(find.byKey(const ValueKey('delete-favorite-vendor-5')));
      await tester.pumpAndSettle();
      expect(repository.contains('vendor-5'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('review sheet requests the next page', (tester) async {
    final client = SocialClient();
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: VendorReviews(
            repository: VendorSocialRepository(client),
            slug: 'clinic',
            paginated: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Review 1-0'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(client.lastPage, 2);
    expect(find.text('Review 2-0'), findsOneWidget);
    expect(find.text('Review 1-0'), findsNothing);
  });
  testWidgets('rating form limits comments to 500 and submits selected stars', (
    tester,
  ) async {
    final client = SocialClient();
    await tester.pumpWidget(
      ShadcnApp(
        home: Scaffold(
          child: Builder(
            builder: (context) => GhostButton(
              onPressed: () => showVendorRatingForm(
                context,
                VendorSocialRepository(client),
                QueueTicket.fromJson({
                  'id': '1',
                  'lookupCode': 'TICKET',
                  'status': 'served',
                  'vendorName': 'Clinic',
                }),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('4 stars'));
    await tester.enterText(find.byType(TextField), 'x' * 510);
    await tester.pump();
    expect(find.text('500/500'), findsOneWidget);
    await tester.tap(find.text('Rate vendor'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(client.rating, 4);
    expect(client.comment, hasLength(500));
    expect(tester.takeException(), isNull);
  });
  test(
    'served notification fires for an observed active visit only once',
    () async {
      final api = TicketApi();
      final repository = QueueTicketRepository(api);
      await repository.loadHistory();
      expect(repository.servedTicket.value, isNull);
      await repository.loadOverview();
      await repository.loadHistory();
      expect(repository.servedTicket.value?.lookupCode, 'TICKET');
      var signals = 0;
      repository.servedTicket.addListener(() => signals++);
      await repository.loadHistory();
      expect(signals, 0);
    },
  );
  for (final size in [
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1280, 600),
  ]) {
    testWidgets('favorites sheet fits ${size.width} by ${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: DrawerOverlay(
              child: Builder(
                builder: (context) => GhostButton(
                  onPressed: () => showFavoritesSheet(
                    context,
                    VendorSocialRepository(SocialClient()),
                  ),
                  child: const Text('Open favorites'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open favorites'));
      await tester.pumpAndSettle();
      expect(find.text('Favorites'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'review carousel advances every ten seconds, tracks swipes and wraps',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: VendorReviews(
              repository: VendorSocialRepository(SocialClient()),
              slug: 'clinic',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final carousel = find.byType(PageView);
      PageController controller() =>
          tester.widget<PageView>(carousel).controller!;
      expect(controller().page, 0);
      expect(find.bySemanticsLabel('Review 1 of 5'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      expect(controller().page, 0);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(controller().page, 1);
      expect(find.bySemanticsLabel('Review 2 of 5'), findsOneWidget);
      await tester.drag(carousel, const Offset(-700, 0));
      await tester.pumpAndSettle();
      expect(controller().page, 2);
      expect(find.bySemanticsLabel('Review 3 of 5'), findsOneWidget);
      await tester.pump(const Duration(seconds: 9));
      expect(controller().page, 2);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
      }
      expect(controller().page, 0);
      expect(find.bySemanticsLabel('Review 1 of 5'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 20));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'reviews sheet trims top padding without inherited list padding',
    (tester) async {
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: DrawerOverlay(
              child: Builder(
                builder: (context) => GhostButton(
                  onPressed: () => showReviewsSheet(
                    context,
                    VendorSocialRepository(SocialClient()),
                    'clinic',
                  ),
                  child: const Text('Open reviews'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open reviews'));
      await tester.pumpAndSettle();
      final sheet = tester.widget<SocialSheet>(find.byType(SocialSheet));
      expect(sheet.topPadding, 0);
      expect(sheet.headerSpacing, 8);
      expect(
        tester.widget<ListView>(find.byType(ListView)).padding,
        EdgeInsets.zero,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test('rating count uses compact thousands', () {
    expect(compactRatingCount(10000), '10k');
    expect(compactRatingCount(1500), '1.5k');
  });
}

class TicketApi implements AccountQueueApi {
  @override
  Future<Map<String, dynamic>> loadOverview() async => {
    'tickets': [
      {'id': '1', 'lookupCode': 'TICKET', 'status': 'waiting'},
    ],
  };
  @override
  Future<Map<String, dynamic>> loadHistory({
    required int page,
    required int limit,
  }) async => {
    'tickets': [
      {'id': '1', 'lookupCode': 'TICKET', 'status': 'served'},
    ],
  };
}
