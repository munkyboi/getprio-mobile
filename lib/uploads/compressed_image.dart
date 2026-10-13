import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class UploadImage {
  const UploadImage(this.bytes, this.fileName, this.contentType);
  final Uint8List bytes;
  final String fileName, contentType;
}

/// Local preparation only; the API still enforces its configured upload policy.
Future<UploadImage> prepareUploadImage(
  Uint8List bytes, {
  required String fileName,
  required String contentType,
  int maxBytes = 200 * 1024,
}) async {
  if (!['image/jpeg', 'image/png', 'image/webp'].contains(contentType)) {
    throw ArgumentError('Choose a JPEG, PNG, or WebP image.');
  }
  if (bytes.isEmpty || bytes.length > 8 * 1024 * 1024) {
    throw ArgumentError('Choose an image up to 8 MB.');
  }
  if (maxBytes < 1) throw ArgumentError('Invalid image size limit.');
  final compressed = await compute(_compress, (bytes, maxBytes, contentType));
  if (bytes.length <= maxBytes) {
    return UploadImage(bytes, fileName, contentType);
  }
  final stem = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
  return UploadImage(compressed, '$stem.jpg', 'image/jpeg');
}

Uint8List _compress((Uint8List, int, String) input) {
  try {
    return _validateAndCompress(input);
  } on ArgumentError {
    rethrow;
  } catch (_) {
    throw ArgumentError('Could not read this image. Choose another image.');
  }
}

Uint8List _validateAndCompress((Uint8List, int, String) input) {
  final (bytes, maxBytes, contentType) = input;
  final decoder = img.findDecoderForData(bytes);
  final format = switch (contentType) {
    'image/jpeg' => img.ImageFormat.jpg,
    'image/png' => img.ImageFormat.png,
    _ => img.ImageFormat.webp,
  };
  if (decoder?.format != format) {
    throw ArgumentError(
      'Image format does not match the selected file. Choose another image.',
    );
  }
  final info = decoder?.startDecode(bytes);
  if (info == null ||
      info.width < 1 ||
      info.height < 1 ||
      info.width * info.height > 24 * 1000 * 1000 ||
      info.numFrames != 1) {
    throw ArgumentError('Choose a valid still image up to 24 megapixels.');
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) {
    throw ArgumentError('Could not read this image. Choose another image.');
  }
  if (bytes.length <= maxBytes) return bytes;
  final oriented = img.bakeOrientation(decoded);
  final longest = math.max(oriented.width, oriented.height);
  for (final edge in [2000, 1600, 1280, 1024]) {
    final scale = math.min(1.0, edge / longest);
    final resized = img.copyResize(
      oriented,
      width: math.max(1, (oriented.width * scale).round()),
      height: math.max(1, (oriented.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
    // Flatten transparency on white and omit source metadata in the upload copy.
    final clean = img.Image(
      width: resized.width,
      height: resized.height,
      numChannels: 3,
    );
    img.fill(clean, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(clean, resized);
    for (final quality in [88, 80, 72]) {
      final result = img.encodeJpg(
        clean,
        quality: quality,
        chroma: img.JpegChroma.yuv420,
      );
      if (result.length <= maxBytes) return result;
    }
    if (longest <= edge && edge <= 1024) break;
  }
  throw ArgumentError(
    'This image cannot fit within ${maxBytes ~/ 1024} KB at a usable quality. Choose a clearer or cropped image.',
  );
}
