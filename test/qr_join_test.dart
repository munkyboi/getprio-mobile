import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';
import 'package:getprio_mobile/queue/join_repository.dart';
import 'package:getprio_mobile/queue/queue_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const hosts = {'app.getprio.test', 'enterprise.example.com'};
  const validId = '123e4567-e89b-42d3-a456-426614174000';

  test('accepts a canonical QR URL and keeps only trusted join data', () {
    final payload = QrJoinPayload.parse(
      'https://app.getprio.test/join/acme/makati?source=qr&id=$validId',
      allowedHosts: hosts,
    );

    expect(payload.locationQrId, validId);
    expect(payload.vendorSlug, 'acme');
    expect(payload.locationSlug, 'makati');
    expect(payload.host, 'app.getprio.test');
  });

  test('rejects an unapproved host, wrong source, and malformed id', () {
    for (final raw in [
      'https://evil.example/join/acme/makati?source=qr&id=$validId',
      'https://app.getprio.test/join/acme/makati?source=web&id=$validId',
      'https://app.getprio.test/join/acme/makati?source=qr&id=not-a-uuid',
    ]) {
      expect(
        () => QrJoinPayload.parse(raw, allowedHosts: hosts),
        throwsA(isA<QrValidationException>()),
      );
    }
  });

  test('accepts an enterprise QR URL without readable slugs', () {
    final payload = QrJoinPayload.parse(
      'https://enterprise.example.com/join?source=qr&id=$validId',
      allowedHosts: hosts,
    );

    expect(payload.vendorSlug, isNull);
    expect(payload.locationSlug, isNull);
  });

  test('recognizes a printed Sandbox ticket verification QR', () {
    final payload = QrScanPayload.parse('ab12cd34', allowedHosts: hosts);

    expect(payload, isA<QrTicketClaimPayload>());
    expect((payload as QrTicketClaimPayload).verificationCode, 'AB12CD34');
  });

  test(
    'claims a printed Sandbox ticket and maps tenant and location context',
    () async {
      final api = _TicketClaimApi();
      final ticket = await JoinRepository(api)
          .claimTicket(const QrTicketClaimPayload('AB12CD34'));

      expect(api.lastCode, 'AB12CD34');
      expect(ticket.ticketNumber, 'QUEUE-0001');
      expect(ticket.vendorName, 'Sandbox profile');
      expect(ticket.locationName, 'Sandbox queue');
      expect(ticket.position, 4);
      expect(ticket.estimatedWaitMinutes, 20);
      expect(ticket.queueLength, 6);
      expect(ticket.queueUpdatedAt, DateTime.parse('2026-09-23T00:05:00.000Z'));
      expect(ticket.status, TicketStatus.waiting);
    },
  );

  test(
    'paid join result exposes checkout URL without claiming a ticket',
    () async {
      final api = FakeJoinApi(
        preview: {
          'locationQrId': validId,
          'vendorName': 'Acme Clinic',
          'locationName': 'Makati',
          'joinable': true,
          'fee': 150,
          'currency': 'PHP',
        },
        joinResponse: {
          'paymentRequired': true,
          'paymentAttemptId': 'attempt-1',
          'checkoutUrl': 'https://paymongo.example/checkout/opaque',
        },
      );
      final repository = JoinRepository(api);

      final result = await repository.join(
        locationQrId: validId,
        customerName: 'Preferred name',
      );

      expect(result, isA<PaymentRequired>());
      expect((result as PaymentRequired).paymentAttemptId, 'attempt-1');
      expect(api.lastJoinAttemptId, isNotEmpty);
    },
  );

  test('enriches a joined ticket from the returned queue snapshot', () async {
    final api = FakeJoinApi(
      preview: {
        'locationQrId': validId,
        'vendorName': 'BOSS LOT',
        'vendorSlug': 'bosslot',
        'locationName': 'Main location',
        'locationSlug': 'main',
        'joinable': true,
      },
      joinResponse: {
        'ticket': {
          'id': 'joined-1',
          'lookupCode': 'PB007',
          'ticketNumber': 'PB007',
          'status': 'waiting',
        },
        'snapshot': {
          'tenant': {'name': 'BOSS LOT', 'slug': 'bosslot'},
          'location': {'name': 'Main location', 'slug': 'main'},
          'focusTicket': {
            'id': 'joined-1',
            'lookupCode': 'PB007',
            'ticketNumber': 'PB007',
            'status': 'waiting',
            'position': 7,
            'estimatedWaitMinutes': 35,
            'joinedAt': '2026-09-02T08:40:00Z',
          },
        },
      },
    );

    final result = await JoinRepository(api)
        .join(locationQrId: validId, customerName: 'Preferred name');

    final ticket = (result as JoinedTicket).ticket;
    expect(ticket.vendorName, 'BOSS LOT');
    expect(ticket.tenantSlug, 'bosslot');
    expect(ticket.locationName, 'Main location');
    expect(ticket.locationSlug, 'main');
    expect(ticket.joinedAt, DateTime.parse('2026-09-02T08:40:00Z'));
    expect(ticket.position, 7);
    expect(ticket.estimatedWaitMinutes, 35);
  });

  test('queue resolve preserves the scanned vendor profile', () {
    final preview = JoinPreview.fromJson({
      'locationQrId': validId,
      'vendorName': 'BOSS LOT',
      'vendorSlug': 'bosslot',
      'locationName': 'Main location',
      'locationSlug': 'main',
      'joinable': true,
      'vendorProfile': {
        'slug': 'bosslot',
        'name': 'Boss Lot Wellness',
        'category': 'Health and Wellness',
        'description': 'Fast, friendly service.',
        'queueAvailable': true,
        'businessProfileTheme': {
          'theme': {
            'logoUrl': 'https://cdn.example.com/logo.webp',
            'logoFit': 'contain',
            'backgroundImageUrl': 'https://cdn.example.com/cover.webp',
            'backgroundImageFit': 'cover',
          },
        },
        'locations': [
          {
            'id': 'location-15',
            'name': 'Main location',
            'slug': 'main',
            'city': 'Quezon City',
            'country': 'Philippines',
            'queueAvailable': true,
          },
        ],
      },
    });

    expect(preview.vendorProfile?.name, 'Boss Lot Wellness');
    expect(preview.vendorSlug, 'bosslot');
    expect(preview.locationSlug, 'main');
    expect(preview.vendorProfile?.category, 'Health and Wellness');
    expect(preview.vendorProfile?.logoUrl, 'https://cdn.example.com/logo.webp');
    expect(preview.vendorProfile?.logoFit, JoinProfileImageFit.contain);
    expect(
      preview.vendorProfile?.coverImageUrl,
      'https://cdn.example.com/cover.webp',
    );
    expect(preview.vendorProfile?.coverImageFit, JoinProfileImageFit.cover);
    expect(preview.vendorProfile?.locations.single.name, 'Main location');
    expect(preview.vendorProfile?.locations.single.slug, 'main');
    expect(
      preview.vendorProfile?.locations.single.address,
      'Quezon City, Philippines',
    );
  });

  test('queue resolve preserves safe current queue details', () {
    final preview = JoinPreview.fromJson({
      'locationQrId': validId,
      'vendorName': 'BOSS LOT',
      'locationName': 'Main location',
      'joinable': true,
      'snapshot': {
        'stats': {
          'waitingCount': 4,
          'currentTicketNumber': 12,
          'estimatedWaitMinutes': 20,
        },
        'current': {'ticketNumber': 12},
      },
    });

    expect(preview.queueDetails?.waitingCount, 4);
    expect(preview.queueDetails?.currentTicketNumber, '12');
    expect(preview.queueDetails?.estimatedWaitMinutes, 20);
  });

  test('public profile image falls back as the vendor logo', () {
    final preview = JoinPreview.fromJson({
      'locationQrId': validId,
      'vendorName': 'Neighborhood Clinic',
      'locationName': 'Main location',
      'joinable': true,
      'vendorProfile': {
        'slug': 'neighborhood-clinic',
        'name': 'Neighborhood Clinic',
        'imageUrl': 'https://cdn.example.com/profile.webp',
      },
    });

    expect(
      preview.vendorProfile?.logoUrl,
      'https://cdn.example.com/profile.webp',
    );
    expect(preview.vendorProfile?.coverImageUrl, isNull);
  });

  test('server rejection replaces a stale available preview', () {
    const preview = JoinPreview(
      locationQrId: validId,
      vendorName: 'BOSS LOT',
      locationName: 'Main location',
      joinable: true,
    );

    final unavailable = preview.asUnavailable('The queue was just paused.');

    expect(unavailable.joinable, isFalse);
    expect(unavailable.unavailableReason, 'The queue was just paused.');
    expect(unavailable.vendorName, preview.vendorName);
  });

  test('authoritative POST queue-state closures become unavailable', () async {
    for (final code in const [
      'QUEUE_JOIN_UNAVAILABLE',
      'QUEUE_INTAKE_PAUSED',
      'QUEUE_DAY_UNOPENED',
      'QUEUE_DAY_OVERDUE',
      'QUEUE_DAY_CLOSED',
      'QUEUE_OUTSIDE_EFFECTIVE_HOURS',
      'QUEUE_STATE_CHANGED',
      'ALLOWANCE_QUEUE_TICKETS_EXHAUSTED',
      'SUBSCRIPTION_INACTIVE',
      null,
    ]) {
      final api = FakeJoinApi(
        preview: {
          'locationQrId': validId,
          'vendorName': 'BOSS LOT',
          'locationName': 'Main location',
          'joinable': true,
        },
        joinResponse: const {},
        joinError: ApiException(
          code == null ? 403 : 409,
          code,
          'The queue was just paused.',
        ),
      );

      await expectLater(
        JoinRepository(api)
            .join(locationQrId: validId, customerName: 'Preferred name'),
        throwsA(
          isA<JoinUnavailableException>().having(
            (error) => error.message,
            'message',
            'The queue was just paused.',
          ),
        ),
        reason: code ?? 'code-less 403',
      );
    }
  });

  test('REST resolve reuses the public vendor profile endpoint', () async {
    final auth = AuthRepository(
      api: _NoopAuthApi(),
      tokenStore: MemoryTokenStore(),
    );
    await auth.completeLoginResponse({
      'token': 'access-token',
      'refreshToken': 'refresh-token',
      'sessionExpiresAt': '2026-09-30T00:00:00Z',
      'user': {'id': 'customer-1', 'email': 'customer@example.com'},
    });
    final requestedPaths = <String>[];
    final resolveHeaders = <String, String>{};
    final client = AuthenticatedApiClient(
      baseUrl: 'https://api.getprio.test',
      authRepository: auth,
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.url.path == '/api/v1/mobile/queue-join/resolve') {
          resolveHeaders.addAll(request.headers);
          return http.Response(
            jsonEncode({
              'locationQrId': validId,
              'vendorName': 'BOSS LOT',
              'vendorSlug': 'bosslot',
              'locationName': 'Main location',
              'joinable': true,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'vendor': {
              'slug': 'bosslot',
              'name': 'Boss Lot Wellness',
              'category': 'Health and Wellness',
            },
          }),
          200,
        );
      }),
    );

    final response = await RestJoinApi(client).resolve(validId);

    expect(requestedPaths, [
      '/api/v1/mobile/queue-join/resolve',
      '/api/v1/public/vendors/bosslot',
    ]);
    expect(
      resolveHeaders['Cache-Control'] ?? resolveHeaders['cache-control'],
      'no-cache',
    );
    expect(
      (response['vendorProfile'] as Map<String, dynamic>)['name'],
      'Boss Lot Wellness',
    );
  });

  test(
    'REST resolve keeps queue data when the public profile is unavailable',
    () async {
      final auth = AuthRepository(
        api: _NoopAuthApi(),
        tokenStore: MemoryTokenStore(),
      );
      await auth.completeLoginResponse({
        'token': 'access-token',
        'refreshToken': 'refresh-token',
        'sessionExpiresAt': '2026-09-30T00:00:00Z',
        'user': {'id': 'customer-1', 'email': 'customer@example.com'},
      });
      final requestedPaths = <String>[];
      final client = AuthenticatedApiClient(
        baseUrl: 'https://api.getprio.test',
        authRepository: auth,
        client: MockClient((request) async {
          requestedPaths.add(request.url.path);
          if (request.url.path == '/api/v1/mobile/queue-join/resolve') {
            return http.Response(
              jsonEncode({
                'locationQrId': validId,
                'vendorName': 'BOSS LOT',
                'vendorSlug': 'bosslot',
                'locationName': 'Main location',
                'locationSlug': 'main',
                'joinable': true,
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'code': 'VENDOR_NOT_FOUND',
              'message': 'Vendor profile is unavailable.',
            }),
            404,
          );
        }),
      );

      final response = await RestJoinApi(client).resolve(validId);

      expect(requestedPaths, [
        '/api/v1/mobile/queue-join/resolve',
        '/api/v1/public/vendors/bosslot',
      ]);
      expect(response['joinable'], isTrue);
      expect(response['vendorName'], 'BOSS LOT');
      expect(response['vendorProfile'], isNull);
    },
  );
}

class FakeJoinApi implements JoinApi {
  FakeJoinApi({
    required this.preview,
    required this.joinResponse,
    this.joinError,
  });

  final Map<String, dynamic> preview;
  final Map<String, dynamic> joinResponse;
  final Object? joinError;
  String? lastJoinAttemptId;

  @override
  Future<Map<String, dynamic>> resolve(String locationQrId) async => preview;

  @override
  Future<Map<String, dynamic>> join({
    required String locationQrId,
    required String joinAttemptId,
    required String customerName,
  }) async {
    lastJoinAttemptId = joinAttemptId;
    if (joinError != null) throw joinError!;
    return joinResponse;
  }
}

class _TicketClaimApi implements JoinApi, TicketClaimApi {
  String? lastCode;

  @override
  Future<Map<String, dynamic>> claimTicket(String verificationCode) async {
    lastCode = verificationCode;
    return {
      'ticket': {
        'id': '123e4567-e89b-42d3-a456-426614174000',
        'ticket_number': 'QUEUE-0001',
        'verification_code': 'AB12CD34',
        'status': 'waiting',
        'profile': {
          'queue_name': 'Sandbox profile',
          'location_name': 'Sandbox queue',
          'location_slug': 'main',
        },
        'queue_position': {
          'position': 4,
          'people_ahead': 3,
          'as_of': '2026-09-23T00:05:00.000Z',
        },
        'queue_length': 6,
        'estimated_wait_minutes': 20,
        'queue_updated_at': '2026-09-23T00:05:00.000Z',
        'issued_at': '2026-09-23T00:00:00.000Z',
        'updated_at': '2026-09-23T00:00:00.000Z',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> resolve(String locationQrId) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> join({
    required String locationQrId,
    required String joinAttemptId,
    required String customerName,
  }) => throw UnimplementedError();
}

class _NoopAuthApi implements AuthApi {
  @override
  Future<Map<String, dynamic>> checkUsernameAvailability(String username) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> logout(String refreshToken) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> refresh(String refreshToken) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String username,
    required String email,
    String? phone,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> requestPasswordReset(String email) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> verifyMfa({
    required String challengeToken,
    String? code,
    String? recoveryCode,
  }) => throw UnimplementedError();
}
