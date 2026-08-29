import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/annotation_item.dart';

class PdfAnnotationService {
  /// Applies annotations (Text, Signature, Whiteout, Watermark) onto the specified page of a PDF
  static Future<Uint8List> applyAnnotationsToPdf({
    required Uint8List inputPdfBytes,
    required int pageIndex,
    required List<AnnotationItem> annotations,
    String? password,
  }) async {
    final doc = (password != null && password.isNotEmpty)
        ? sf.PdfDocument(inputBytes: inputPdfBytes, password: password)
        : sf.PdfDocument(inputBytes: inputPdfBytes);

    if (pageIndex >= 0 && pageIndex < doc.pages.count) {
      final page = doc.pages[pageIndex];
      final pageSize = page.getClientSize();

      for (final item in annotations) {
        switch (item.type) {
          case AnnotationType.text:
          case AnnotationType.whiteout:
            final x = item.position.dx * pageSize.width;
            final y = item.position.dy * pageSize.height;
            final w = item.size.width;
            final h = item.size.height;

            if (item.backgroundColor != null) {
              final bg = item.backgroundColor!;
              final bgBrush = sf.PdfSolidBrush(
                sf.PdfColor(
                  (bg.r * 255).round().clamp(0, 255),
                  (bg.g * 255).round().clamp(0, 255),
                  (bg.b * 255).round().clamp(0, 255),
                  (bg.a * 255).round().clamp(0, 255),
                ),
              );
              page.graphics.drawRectangle(
                brush: bgBrush,
                bounds: ui.Rect.fromLTWH(x, y, w, h),
              );
            }

            if (item.text.trim().isNotEmpty) {
              final fontStyle = item.isBold
                  ? sf.PdfFontStyle.bold
                  : item.isItalic
                      ? sf.PdfFontStyle.italic
                      : sf.PdfFontStyle.regular;

              final font = sf.PdfStandardFont(
                sf.PdfFontFamily.helvetica,
                item.fontSize,
                style: fontStyle,
              );

              final fg = item.color;
              final textBrush = sf.PdfSolidBrush(
                sf.PdfColor(
                  (fg.r * 255).round().clamp(0, 255),
                  (fg.g * 255).round().clamp(0, 255),
                  (fg.b * 255).round().clamp(0, 255),
                  (fg.a * 255).round().clamp(0, 255),
                ),
              );

              page.graphics.drawString(
                item.text,
                font,
                brush: textBrush,
                bounds: ui.Rect.fromLTWH(x + 2, y + 2, w - 4, h - 4),
              );
            }
            break;

          case AnnotationType.signature:
            if (item.signatureBytes != null) {
              final bitmap = sf.PdfBitmap(item.signatureBytes!);
              final x = item.position.dx * pageSize.width;
              final y = item.position.dy * pageSize.height;
              page.graphics.drawImage(
                bitmap,
                ui.Rect.fromLTWH(x, y, item.size.width, item.size.height),
              );
            }
            break;

          case AnnotationType.watermark:
            if (item.text.isNotEmpty) {
              final font = sf.PdfStandardFont(
                sf.PdfFontFamily.helvetica,
                48,
                style: sf.PdfFontStyle.bold,
              );
              
              final fg = item.color;
              final brush = sf.PdfSolidBrush(
                sf.PdfColor(
                  (fg.r * 255).round().clamp(0, 255),
                  (fg.g * 255).round().clamp(0, 255),
                  (fg.b * 255).round().clamp(0, 255),
                  (item.opacity * 255).round().clamp(0, 255),
                ),
              );

              final state = page.graphics.save();
              page.graphics.translateTransform(pageSize.width / 2, pageSize.height / 2);
              page.graphics.rotateTransform(-45);
              
              final textSize = font.measureString(item.text);
              page.graphics.drawString(
                item.text,
                font,
                brush: brush,
                bounds: ui.Rect.fromLTWH(
                  -textSize.width / 2,
                  -textSize.height / 2,
                  textSize.width,
                  textSize.height,
                ),
              );
              page.graphics.restore(state);
            }
            break;

          case AnnotationType.digitalSignatureStamp:
            final x = item.position.dx * pageSize.width;
            final y = item.position.dy * pageSize.height;
            final w = item.size.width;

            // 1. Draw compact bold 'Signature valid' header text
            final titleFont = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 10, style: sf.PdfFontStyle.bold);
            final blackBrush = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0));
            page.graphics.drawString(
              'Signature valid',
              titleFont,
              brush: blackBrush,
              bounds: ui.Rect.fromLTWH(x, y, w, 12),
            );

            // 2. Draw compact 3D shadow tick path
            final shadowTick = sf.PdfPath();
            shadowTick.addLine(ui.Offset(x + 14 + 1.0, y + 16 + 1.0), ui.Offset(x + 22 + 1.0, y + 26 + 1.0));
            shadowTick.addLine(ui.Offset(x + 22 + 1.0, y + 26 + 1.0), ui.Offset(x + 36 + 1.0, y + 6 + 1.0));
            final shadowPen = sf.PdfPen(sf.PdfColor(0, 0, 0), width: 2.8);
            page.graphics.drawPath(shadowTick, pen: shadowPen);

            // 3. Draw compact bright green tick path
            final greenTick = sf.PdfPath();
            greenTick.addLine(ui.Offset(x + 14, y + 16), ui.Offset(x + 22, y + 26));
            greenTick.addLine(ui.Offset(x + 22, y + 26), ui.Offset(x + 36, y + 6));
            final greenPen = sf.PdfPen(sf.PdfColor(0, 153, 51), width: 2.4);
            page.graphics.drawPath(greenTick, pen: greenPen);

            // 4. Draw signer and date metadata lines
            final metaFont = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 6.8, style: sf.PdfFontStyle.bold);
            final now = DateTime.now();
            final dateStr = '${now.year}.${now.month.toString().padLeft(2, "0")}.${now.day.toString().padLeft(2, "0")} ${now.hour.toString().padLeft(2, "0")}:${now.minute.toString().padLeft(2, "0")}:${now.second.toString().padLeft(2, "0")}';
            page.graphics.drawString(
              'Digitally signed by ${item.text}\nDate: $dateStr\nIST',
              metaFont,
              brush: blackBrush,
              bounds: ui.Rect.fromLTWH(x, y + 14, w, 28),
            );
            break;

          default:
            break;
        }
      }
    }

    final savedBytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return savedBytes;
  }
}
