import 'dart:typed_data';
import 'package:flutter/material.dart';

enum AnnotationType {
  text,
  whiteout,
  signature,
  drawing,
  watermark,
  stamp,
  digitalSignatureStamp,
}

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final bool isHighlighter;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isHighlighter = false,
  });
}

class AnnotationItem {
  final String id;
  final AnnotationType type;
  Offset position;
  Size size;
  String text;
  Color color;
  Color? backgroundColor;
  double fontSize;
  bool isBold;
  bool isItalic;
  double rotation;
  double opacity;
  List<DrawingStroke>? strokes;
  Image? signatureImage;
  Uint8List? signatureBytes;

  AnnotationItem({
    required this.id,
    required this.type,
    required this.position,
    this.size = const Size(120, 40),
    this.text = '',
    this.color = Colors.black,
    this.backgroundColor,
    this.fontSize = 16.0,
    this.isBold = false,
    this.isItalic = false,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.strokes,
    this.signatureImage,
    this.signatureBytes,
  });
}
