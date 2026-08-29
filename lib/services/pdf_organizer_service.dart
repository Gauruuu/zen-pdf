import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class PdfOrganizerService {
  /// Combines multiple PDF file bytes into a single merged PDF
  static Future<Uint8List> mergePdfs(List<Uint8List> pdfsBytes) async {
    final outputDocument = sf.PdfDocument();

    for (final bytes in pdfsBytes) {
      final docToMerge = sf.PdfDocument(inputBytes: bytes);
      final pageCount = docToMerge.pages.count;
      
      for (int i = 0; i < pageCount; i++) {
        final template = docToMerge.pages[i].createTemplate();
        final newPage = outputDocument.pages.add();
        final size = newPage.getClientSize();
        newPage.graphics.drawPdfTemplate(
          template,
          ui.Offset.zero,
          size,
        );
      }
      docToMerge.dispose();
    }

    final mergedBytes = Uint8List.fromList(outputDocument.saveSync());
    outputDocument.dispose();
    return mergedBytes;
  }

  /// Splits a PDF by extracting specific page numbers (1-based index e.g. [1, 2, 4])
  static Future<Uint8List> extractPages({
    required Uint8List inputPdfBytes,
    required List<int> pageNumbers,
  }) async {
    final inputDoc = sf.PdfDocument(inputBytes: inputPdfBytes);
    final outputDoc = sf.PdfDocument();

    for (final pageNum in pageNumbers) {
      final zeroIndex = pageNum - 1;
      if (zeroIndex >= 0 && zeroIndex < inputDoc.pages.count) {
        final template = inputDoc.pages[zeroIndex].createTemplate();
        final newPage = outputDoc.pages.add();
        final size = newPage.getClientSize();
        newPage.graphics.drawPdfTemplate(
          template,
          ui.Offset.zero,
          size,
        );
      }
    }

    inputDoc.dispose();
    final resultBytes = Uint8List.fromList(outputDoc.saveSync());
    outputDoc.dispose();
    return resultBytes;
  }

  /// Reorders and rotates pages
  static Future<Uint8List> organizePages({
    required Uint8List inputPdfBytes,
    required List<int> pageOrder,
    required Map<int, int> pageRotations,
  }) async {
    final inputDoc = sf.PdfDocument(inputBytes: inputPdfBytes);
    final outputDoc = sf.PdfDocument();

    for (final oldIndex in pageOrder) {
      if (oldIndex >= 0 && oldIndex < inputDoc.pages.count) {
        final template = inputDoc.pages[oldIndex].createTemplate();
        final newPage = outputDoc.pages.add();
        
        final rotationDeg = pageRotations[oldIndex] ?? 0;
        if (rotationDeg == 90) {
          newPage.rotation = sf.PdfPageRotateAngle.rotateAngle90;
        } else if (rotationDeg == 180) {
          newPage.rotation = sf.PdfPageRotateAngle.rotateAngle180;
        } else if (rotationDeg == 270) {
          newPage.rotation = sf.PdfPageRotateAngle.rotateAngle270;
        }

        final size = newPage.getClientSize();
        newPage.graphics.drawPdfTemplate(
          template,
          ui.Offset.zero,
          size,
        );
      }
    }

    inputDoc.dispose();
    final resultBytes = Uint8List.fromList(outputDoc.saveSync());
    outputDoc.dispose();
    return resultBytes;
  }

  /// Gets the total page count of a PDF
  static int getPageCount(Uint8List pdfBytes, {String? password}) {
    try {
      final doc = password != null && password.isNotEmpty
          ? sf.PdfDocument(inputBytes: pdfBytes, password: password)
          : sf.PdfDocument(inputBytes: pdfBytes);
      final count = doc.pages.count;
      doc.dispose();
      return count;
    } catch (_) {
      return 1;
    }
  }
}
