import 'dart:async';
import 'dart:typed_data';

import 'compressed_image.dart';

abstract interface class ImageUploadPolicyApi {
  Future<Map<String, dynamic>> loadImageUploadPolicy();
}

class ImageUploadPolicy {
  const ImageUploadPolicy(this.maxImageBytes);
  final int maxImageBytes;
  factory ImageUploadPolicy.fromJson(Map<String, dynamic> json) {
    final limit = json['maxImageBytes'];
    if (limit is! int ||
        limit < 1024 ||
        limit > 8 * 1024 * 1024 ||
        limit % 1024 != 0) {
      throw ArgumentError(
        'Could not read the current image upload limit. Please retry.',
      );
    }
    return ImageUploadPolicy(limit);
  }
}

/// Fetch on every attempt, including retries. Never substitute a stale/default
/// platform setting. Keep the original bytes so a changed limit can be honored.
Future<UploadImage> prepareImageForCurrentPolicy(
  Object api,
  List<int> bytes, {
  required String fileName,
  required String contentType,
}) async {
  if (api is! ImageUploadPolicyApi) {
    throw ArgumentError('Image upload settings are unavailable. Please retry.');
  }
  Map<String, dynamic> response;
  try {
    response = await api.loadImageUploadPolicy().timeout(
      const Duration(seconds: 20),
    );
  } catch (_) {
    throw ArgumentError(
      'Could not load the current image upload limit. Please retry.',
    );
  }
  final policy = ImageUploadPolicy.fromJson(response);
  return prepareUploadImage(
    bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
    fileName: fileName,
    contentType: contentType,
    maxBytes: policy.maxImageBytes,
  );
}
