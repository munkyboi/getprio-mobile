import 'dart:typed_data';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:getprio_mobile/auth/auth_repository.dart';
import 'package:getprio_mobile/queue/auth_queue_api.dart';

import 'queue_repository_test.dart' show FakeAuthApiForTransport;

import 'package:flutter_test/flutter_test.dart';
import 'package:getprio_mobile/uploads/image_upload_policy.dart';
import 'package:getprio_mobile/account/profile_repository.dart';
import 'package:getprio_mobile/bookings/booking_repository.dart';
import 'package:image/image.dart' as img;

import 'profile_test.dart' show FakeAccountProfileApi;
import 'booking_payment_test.dart' show PaymentApi, paymentBooking;

Uint8List largeImage() {
  final encoded = img.encodePng(img.Image(width: 120, height: 80));
  return Uint8List(300 * 1024)..setRange(0, encoded.length, encoded);
}

class ProfilePolicyApi extends FakeAccountProfileApi {
  int limit = 512 * 1024, loads = 0, uploads = 0;
  bool offline = false;
  List<int>? uploaded;
  String? uploadedType, uploadedName;
  @override
  Future<Map<String, dynamic>> loadImageUploadPolicy() async {
    loads++;
    if (offline) throw StateError('offline');
    return {'maxImageBytes': limit};
  }

  @override
  Future<Map<String, dynamic>> uploadAvatar({
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) {
    uploads++;
    uploaded = bytes;
    uploadedType = contentType;
    uploadedName = fileName;
    return super.uploadAvatar(
      fileName: fileName,
      contentType: contentType,
      bytes: bytes,
    );
  }
}

class ReceiptPolicyApi extends PaymentApi {
  int limit = 512 * 1024, loads = 0;
  bool offline = false;
  List<int>? uploaded;
  String? uploadedType, uploadedName;
  @override
  Future<Map<String, dynamic>> loadImageUploadPolicy() async {
    loads++;
    if (offline) throw StateError('offline');
    return {'maxImageBytes': limit};
  }

  @override
  Future<Map<String, dynamic>> uploadProof(
    String path, {
    required List<int> bytes,
    required String contentType,
    required String fileName,
  }) async {
    uploads++;
    uploaded = bytes;
    uploadedType = contentType;
    uploadedName = fileName;
    return {
      'proof': {
        'objectKey': 'private/key',
        'fileName': fileName,
        'contentType': contentType,
        'sizeBytes': bytes.length,
      },
    };
  }
}

void main() {
  test(
    'both REST adapters fetch the authenticated versioned policy endpoint',
    () async {
      final auth = AuthRepository(
        api: FakeAuthApiForTransport(),
        tokenStore: MemoryTokenStore(),
      );
      await auth.signIn(identifier: 'customer', password: 'password');
      var calls = 0;
      final client = AuthenticatedApiClient(
        baseUrl: 'https://api.example.test',
        authRepository: auth,
        client: MockClient((request) async {
          calls++;
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/account/image-upload-policy');
          expect(request.headers['authorization'], startsWith('Bearer '));
          return http.Response(jsonEncode({'maxImageBytes': 512 * 1024}), 200);
        }),
      );
      expect(
        (await RestAccountProfileApi(client)
            .loadImageUploadPolicy())['maxImageBytes'],
        512 * 1024,
      );
      expect(
        (await RestBookingApi(client).loadImageUploadPolicy())['maxImageBytes'],
        512 * 1024,
      );
      expect(calls, 2);
    },
  );

  test('policy validates exact byte limits rather than falling back', () {
    for (final value in [null, 0, 1000, 204800.0, '204800', 8193 * 1024]) {
      expect(
        () => ImageUploadPolicy.fromJson({'maxImageBytes': value}),
        throwsArgumentError,
      );
    }
    expect(
      ImageUploadPolicy.fromJson({'maxImageBytes': 1024}).maxImageBytes,
      1024,
    );
    expect(
      ImageUploadPolicy.fromJson({'maxImageBytes': 8 * 1024 * 1024})
          .maxImageBytes,
      8 * 1024 * 1024,
    );
  });
  test(
    'profile reloads changed platform limit and recompresses original bytes',
    () async {
      final api = ProfilePolicyApi();
      final repo = AccountProfileRepository(api);
      final bytes = largeImage();
      Future<void> upload() => repo.uploadAvatar(
        fileName: 'photo.png',
        contentType: 'image/png',
        bytes: bytes,
      );
      await upload();
      expect(api.uploaded, same(bytes));
      expect(api.uploadedType, 'image/png');
      api.limit = 100 * 1024;
      await upload();
      expect(api.loads, 2);
      expect(api.uploaded!.length, lessThanOrEqualTo(api.limit));
      expect(api.uploadedType, 'image/jpeg');
      expect(api.uploadedName, 'photo.jpg');
      expect(bytes.length, 300 * 1024);
    },
  );
  test(
    'receipt retry reloads changed policy with consistent evidence metadata',
    () async {
      final api = ReceiptPolicyApi();
      final repo = BookingRepository(api);
      final bytes = largeImage();
      Future<void> upload() => repo.submitPaymentProof(
        CustomerBooking(paymentBooking()),
        reference: 'reference',
        bytes: bytes,
        contentType: 'image/png',
        fileName: 'receipt.png',
      );
      await upload();
      expect(api.uploaded, same(bytes));
      api.limit = 100 * 1024;
      await upload();
      expect(api.loads, 2);
      expect(api.uploaded!.length, lessThanOrEqualTo(api.limit));
      expect(api.uploadedType, 'image/jpeg');
      expect(api.submitted!['fileName'], 'receipt.jpg');
      expect(api.submitted!['contentType'], 'image/jpeg');
      expect(api.submitted!['sizeBytes'], api.uploaded!.length);
    },
  );
  test(
    'offline or invalid policy prevents both uploads and evidence submission',
    () async {
      final profile = ProfilePolicyApi()..offline = true;
      final receipt = ReceiptPolicyApi()..offline = true;
      final bytes = largeImage();
      for (final invalid in [false, true]) {
        if (invalid) {
          profile.offline = false;
          receipt.offline = false;
          profile.limit = 0;
          receipt.limit = 0;
        }
        await expectLater(
          AccountProfileRepository(profile).uploadAvatar(
            fileName: 'photo.png',
            contentType: 'image/png',
            bytes: bytes,
          ),
          throwsArgumentError,
        );
        await expectLater(
          BookingRepository(receipt).submitPaymentProof(
            CustomerBooking(paymentBooking()),
            reference: 'reference',
            fileName: 'receipt.png',
            contentType: 'image/png',
            bytes: bytes,
          ),
          throwsArgumentError,
        );
      }
      expect(profile.uploads, 0);
      expect(receipt.uploads, 0);
      expect(receipt.submissions, 0);
    },
  );
}
