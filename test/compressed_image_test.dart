import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:getprio_mobile/uploads/compressed_image.dart';

void main() {
  test('small images retain exact bytes, format and filename', () async {
    final bytes = img.encodePng(img.Image(width: 20, height: 20));
    final result = await prepareUploadImage(
      bytes,
      fileName: 'receipt.png',
      contentType: 'image/png',
    );
    expect(result.bytes, same(bytes));
    expect(result.fileName, 'receipt.png');
    expect(result.contentType, 'image/png');
  });

  test(
    'large receipt fits 200KB with correct JPEG name and aspect ratio',
    () async {
      final source = img.Image(width: 1400, height: 1100);
      final random = Random(12);
      for (final pixel in source) {
        pixel.setRgb(
          96 + random.nextInt(64),
          96 + random.nextInt(64),
          96 + random.nextInt(64),
        );
      }
      final bytes = img.encodePng(source);
      expect(bytes.length, greaterThan(200 * 1024));
      final result = await prepareUploadImage(
        bytes,
        fileName: 'receipt.final.png',
        contentType: 'image/png',
      );
      expect(result.bytes.length, lessThanOrEqualTo(200 * 1024));
      expect(result.contentType, 'image/jpeg');
      expect(result.fileName, 'receipt.final.jpg');
      final decoded = img.decodeJpg(result.bytes)!;
      expect(decoded.width / decoded.height, closeTo(1400 / 1100, 0.005));
      expect(decoded.width, greaterThanOrEqualTo(1024));
      expect(decoded.width, lessThanOrEqualTo(source.width));
    },
  );

  test(
    'orientation is applied and upload copy strips source metadata',
    () async {
      final source = img.Image(width: 1500, height: 1100);
      source.exif.imageIfd.orientation = 6;
      final jpeg = img.encodeJpg(source);
      final padded = Uint8List(220 * 1024)..setRange(0, jpeg.length, jpeg);
      final result = await prepareUploadImage(
        padded,
        fileName: 'photo.jpeg',
        contentType: 'image/jpeg',
      );
      final decoded = img.decodeJpg(result.bytes)!;
      expect(decoded.height, greaterThan(decoded.width));
      expect(decoded.exif.imageIfd.hasOrientation, isFalse);
    },
  );

  test('transparent images are flattened on white', () async {
    final source = img.Image(width: 700, height: 700, numChannels: 4);
    final random = Random(3);
    for (final pixel in source) {
      pixel.setRgba(
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
        0,
      );
    }
    final result = await prepareUploadImage(
      img.encodePng(source),
      fileName: 'transparent.png',
      contentType: 'image/png',
    );
    final decoded = img.decodeJpg(result.bytes)!;
    expect(decoded.getPixel(350, 350).r, greaterThanOrEqualTo(250));
    expect(decoded.getPixel(350, 350).g, greaterThanOrEqualTo(250));
    expect(decoded.getPixel(350, 350).b, greaterThanOrEqualTo(250));
  });

  test('invalid large image, unsupported types and oversized selections fail locally', () async {
    await expectLater(
      prepareUploadImage(
        Uint8List(210 * 1024),
        fileName: 'bad.jpg',
        contentType: 'image/jpeg',
      ),
      throwsArgumentError,
    );
    await expectLater(
      prepareUploadImage(
        Uint8List(1),
        fileName: 'bad.heic',
        contentType: 'image/heic',
      ),
      throwsArgumentError,
    );
    await expectLater(
      prepareUploadImage(
        Uint8List(9 * 1024 * 1024),
        fileName: 'huge.jpg',
        contentType: 'image/jpeg',
      ),
      throwsArgumentError,
    );
  });
}
