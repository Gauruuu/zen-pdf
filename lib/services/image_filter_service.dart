import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../core/constants/app_constants.dart';

class ImageFilterParams {
  final Uint8List inputBytes;
  final DocumentFilter filter;
  final int rotationQuarterTurns;
  final int maxDimension;
  final int quality;

  const ImageFilterParams({
    required this.inputBytes,
    required this.filter,
    this.rotationQuarterTurns = 0,
    this.maxDimension = 2048,
    this.quality = 85,
  });
}

class ImageFilterService {
  static Future<Uint8List> processImage({
    required Uint8List inputBytes,
    required DocumentFilter filter,
    int rotationQuarterTurns = 0,
    int maxDimension = 2048,
    int quality = 85,
  }) async {
    // Fast path: if original, no rotation, pass through original image bytes directly with zero latency
    if (filter == DocumentFilter.original && rotationQuarterTurns % 4 == 0) {
      return inputBytes;
    }

    return compute(
      _processImageInIsolate,
      ImageFilterParams(
        inputBytes: inputBytes,
        filter: filter,
        rotationQuarterTurns: rotationQuarterTurns,
        maxDimension: maxDimension,
        quality: quality,
      ),
    );
  }

  static Uint8List _processImageInIsolate(ImageFilterParams params) {
    img.Image? image = img.decodeImage(params.inputBytes);
    if (image == null) return params.inputBytes;

    // Handle rotation
    if (params.rotationQuarterTurns % 4 != 0) {
      final angle = (params.rotationQuarterTurns % 4) * 90;
      image = img.copyRotate(image, angle: angle);
    }

    // Downscale oversized images for fast processing & low memory usage
    if (image.width > params.maxDimension || image.height > params.maxDimension) {
      if (image.width >= image.height) {
        image = img.copyResize(
          image,
          width: params.maxDimension,
          interpolation: img.Interpolation.linear,
        );
      } else {
        image = img.copyResize(
          image,
          height: params.maxDimension,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // Apply Filter
    switch (params.filter) {
      case DocumentFilter.original:
        break;

      case DocumentFilter.cleanScan:
        image = img.grayscale(image);
        image = img.adjustColor(image, contrast: 1.5, brightness: 1.1);
        break;

      case DocumentFilter.blackAndWhite:
        image = img.grayscale(image);
        image = img.adjustColor(image, contrast: 2.2, brightness: 1.15);
        break;

      case DocumentFilter.grayscale:
        image = img.grayscale(image);
        image = img.adjustColor(image, contrast: 1.1);
        break;

      case DocumentFilter.magicColor:
        image = img.adjustColor(image, saturation: 1.35, contrast: 1.25, brightness: 1.05);
        break;

      case DocumentFilter.brighten:
        image = img.adjustColor(image, brightness: 1.25, contrast: 1.1);
        break;
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: params.quality));
  }
}
