enum DocumentFilter {
  original,
  cleanScan,
  blackAndWhite,
  grayscale,
  magicColor,
  brighten,
}

extension DocumentFilterExtension on DocumentFilter {
  String get displayName {
    switch (this) {
      case DocumentFilter.original:
        return 'Original';
      case DocumentFilter.cleanScan:
        return 'Clean Scan';
      case DocumentFilter.blackAndWhite:
        return 'Black & White';
      case DocumentFilter.grayscale:
        return 'Grayscale';
      case DocumentFilter.magicColor:
        return 'Vivid Color';
      case DocumentFilter.brighten:
        return 'Brighten';
    }
  }

  String get simpleDescription {
    switch (this) {
      case DocumentFilter.original:
        return 'Photo as taken';
      case DocumentFilter.cleanScan:
        return 'Whitens background and sharpens text';
      case DocumentFilter.blackAndWhite:
        return 'Pure black ink on white page';
      case DocumentFilter.grayscale:
        return 'Black and white with smooth shading';
      case DocumentFilter.magicColor:
        return 'Vibrant colors with clear background';
      case DocumentFilter.brighten:
        return 'Boosts lighting for dark photos';
    }
  }
}

enum PageSizeOption {
  a4,
  usLetter,
  fitImage,
}

extension PageSizeOptionExtension on PageSizeOption {
  String get displayName {
    switch (this) {
      case PageSizeOption.a4:
        return 'A4 (Standard)';
      case PageSizeOption.usLetter:
        return 'US Letter';
      case PageSizeOption.fitImage:
        return 'Fit to Image';
    }
  }
}

enum PageMarginOption {
  none,
  small,
  medium,
}

extension PageMarginOptionExtension on PageMarginOption {
  String get displayName {
    switch (this) {
      case PageMarginOption.none:
        return 'No Margins';
      case PageMarginOption.small:
        return 'Small Margins';
      case PageMarginOption.medium:
        return 'Medium Margins';
    }
  }

  double get marginValue {
    switch (this) {
      case PageMarginOption.none:
        return 0.0;
      case PageMarginOption.small:
        return 14.0;
      case PageMarginOption.medium:
        return 28.0;
    }
  }
}
