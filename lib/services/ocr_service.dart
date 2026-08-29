import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:image/image.dart' as img;

class OcrService {
  /// Extracts all readable text from a PDF document
  static Future<String> extractTextFromPdf(Uint8List pdfBytes, {String? password}) async {
    try {
      final doc = (password != null && password.isNotEmpty)
          ? sf.PdfDocument(inputBytes: pdfBytes, password: password)
          : sf.PdfDocument(inputBytes: pdfBytes);

      final extractor = sf.PdfTextExtractor(doc);
      final text = extractor.extractText();
      doc.dispose();

      if (text.trim().isNotEmpty) {
        return text.trim();
      } else {
        return "No digital text found in this PDF. This document may consist of scanned images.";
      }
    } catch (e) {
      return "Could not read text: ${e.toString()}";
    }
  }

  /// Extracts text / image summary info
  static Future<String> scanImageInfo(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return "Could not decode image.";
      
      final width = image.width;
      final height = image.height;
      return "Scanned Image: $width x $height px\nReady for high-clarity document export.";
    } catch (e) {
      return "Scan info error: ${e.toString()}";
    }
  }
}
