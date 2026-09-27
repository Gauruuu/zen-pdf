import 'package:flutter/material.dart';

/// Represents a single styled span or run of text
class TextRun {
  String text;
  bool isBold;
  bool isItalic;
  bool isUnderline;
  bool isStrikethrough;
  double fontSize;
  Color color;
  Color? backgroundColor;
  String? fontFamily;

  TextRun({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.isStrikethrough = false,
    this.fontSize = 14.0,
    this.color = Colors.black87,
    this.backgroundColor,
    this.fontFamily,
  });

  TextRun copyWith({
    String? text,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    bool? isStrikethrough,
    double? fontSize,
    Color? color,
    Color? backgroundColor,
    String? fontFamily,
  }) {
    return TextRun(
      text: text ?? this.text,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      isStrikethrough: isStrikethrough ?? this.isStrikethrough,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

/// Represents paragraph alignment
enum DocParagraphAlign { left, center, right, justify }

/// Type of paragraph or block
enum DocBlockType { heading1, heading2, heading3, body, bullet, numbered, quote, code }

/// Represents a block / paragraph in a rich document (Word / DOCX)
class DocParagraph {
  String id;
  DocBlockType type;
  DocParagraphAlign align;
  List<TextRun> runs;

  DocParagraph({
    required this.id,
    this.type = DocBlockType.body,
    this.align = DocParagraphAlign.left,
    List<TextRun>? runs,
  }) : runs = runs ?? [TextRun(text: '')];

  String get plainText => runs.map((r) => r.text).join();
}

/// Represents a cell in a spreadsheet (Excel / XLSX / CSV)
class SheetCell {
  String rawValue; // Can be "=SUM(A1:A5)" or "100" or "Hello"
  String displayValue;
  bool isBold;
  bool isItalic;
  Color textColor;
  Color? fillColor;
  TextAlign alignment;
  String numberFormat; // 'general', 'currency', 'percentage', 'number'

  SheetCell({
    this.rawValue = '',
    this.displayValue = '',
    this.isBold = false,
    this.isItalic = false,
    this.textColor = Colors.black87,
    this.fillColor,
    this.alignment = TextAlign.left,
    this.numberFormat = 'general',
  });

  SheetCell copyWith({
    String? rawValue,
    String? displayValue,
    bool? isBold,
    bool? isItalic,
    Color? textColor,
    Color? fillColor,
    TextAlign? alignment,
    String? numberFormat,
  }) {
    return SheetCell(
      rawValue: rawValue ?? this.rawValue,
      displayValue: displayValue ?? this.displayValue,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      textColor: textColor ?? this.textColor,
      fillColor: fillColor ?? this.fillColor,
      alignment: alignment ?? this.alignment,
      numberFormat: numberFormat ?? this.numberFormat,
    );
  }
}

/// A complete spreadsheet sheet tab
class SheetTab {
  String title;
  int rowCount;
  int colCount;
  Map<String, SheetCell> cells; // Key is coordinate e.g. "A1", "B3"

  SheetTab({
    required this.title,
    this.rowCount = 30,
    this.colCount = 10,
    Map<String, SheetCell>? cells,
  }) : cells = cells ?? {};

  SheetCell getCell(String coord) {
    return cells[coord] ?? SheetCell();
  }

  void setCell(String coord, SheetCell cell) {
    cells[coord] = cell;
  }
}

/// Slide element type in a presentation (PPTX)
enum SlideElementType { title, text, bulletList, shape, card }

/// Element inside a slide
class SlideElement {
  String id;
  SlideElementType type;
  String content;
  List<String> bulletPoints;
  Color textColor;
  Color backgroundColor;
  double fontSize;
  bool isBold;
  Alignment alignment;

  SlideElement({
    required this.id,
    required this.type,
    this.content = '',
    List<String>? bulletPoints,
    this.textColor = Colors.white,
    this.backgroundColor = Colors.transparent,
    this.fontSize = 18.0,
    this.isBold = false,
    this.alignment = Alignment.topLeft,
  }) : bulletPoints = bulletPoints ?? [];
}

/// Layout preset for a slide
enum SlideLayout { titleSlide, titleAndContent, twoColumns, cardHighlight, blank }

/// Presentation slide
class PresentationSlide {
  String id;
  String title;
  String subtitle;
  SlideLayout layout;
  Color backgroundColor;
  Color accentColor;
  List<String> bullets;
  List<String> rightColumnBullets;
  String footerText;

  PresentationSlide({
    required this.id,
    this.title = 'Slide Title',
    this.subtitle = 'Subtitle or Description',
    this.layout = SlideLayout.titleAndContent,
    this.backgroundColor = const Color(0xFF0F172A),
    this.accentColor = const Color(0xFF38BDF8),
    List<String>? bullets,
    List<String>? rightColumnBullets,
    this.footerText = 'Zen Presentation Studio',
  })  : bullets = bullets ?? ['Key point or milestone here', 'Second important detail'],
        rightColumnBullets = rightColumnBullets ?? ['Comparison item 1', 'Comparison item 2'];
}
