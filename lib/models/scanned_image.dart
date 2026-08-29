import 'dart:typed_data';
import '../core/constants/app_constants.dart';

class ScannedImage {
  final String id;
  final String? originalPath;
  final Uint8List originalBytes;
  Uint8List? previewBytes;
  DocumentFilter filter;
  int rotationQuarterTurns; // 0 = 0 deg, 1 = 90 deg, 2 = 180 deg, 3 = 270 deg
  
  ScannedImage({
    required this.id,
    this.originalPath,
    required this.originalBytes,
    this.previewBytes,
    this.filter = DocumentFilter.original,
    this.rotationQuarterTurns = 0,
  }) {
    previewBytes ??= originalBytes;
  }

  ScannedImage copyWith({
    String? id,
    String? originalPath,
    Uint8List? originalBytes,
    Uint8List? previewBytes,
    DocumentFilter? filter,
    int? rotationQuarterTurns,
  }) {
    return ScannedImage(
      id: id ?? this.id,
      originalPath: originalPath ?? this.originalPath,
      originalBytes: originalBytes ?? this.originalBytes,
      previewBytes: previewBytes ?? this.previewBytes,
      filter: filter ?? this.filter,
      rotationQuarterTurns: rotationQuarterTurns ?? this.rotationQuarterTurns,
    );
  }
}
