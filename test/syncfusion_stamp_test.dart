import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Syncfusion PDF drawing test', () async {
    final pdf = PdfDocument();
    final page = pdf.pages.add();
    page.graphics.drawString(
      'Original Text',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
      bounds: const Rect.fromLTWH(50, 50, 200, 20),
    );
    final bytes = Uint8List.fromList(await pdf.save());
    pdf.dispose();

    // Now reload and stamp
    final loadedDoc = PdfDocument(inputBytes: bytes);
    final loadedPage = loadedDoc.pages[0];
    
    // Draw white background
    loadedPage.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
      pen: PdfPen(PdfColor(16, 185, 129), width: 1.5),
      bounds: const Rect.fromLTWH(40, 40, 300, 80),
    );
    
    loadedPage.graphics.drawString(
      'Signature Valid',
      PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
      brush: PdfSolidBrush(PdfColor(5, 150, 105)),
      bounds: const Rect.fromLTWH(50, 50, 280, 20),
    );
    
    final stampedBytes = Uint8List.fromList(await loadedDoc.save());
    loadedDoc.dispose();
    
    expect(stampedBytes.length, greaterThan(bytes.length));
  });
}
