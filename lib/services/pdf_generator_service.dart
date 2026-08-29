import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../core/constants/app_constants.dart';
import '../models/scanned_image.dart';
import 'image_filter_service.dart';

class PdfGeneratorService {
  static Future<Uint8List> createPdfFromImages({
    required List<ScannedImage> images,
    PageSizeOption pageSize = PageSizeOption.a4,
    PageMarginOption margin = PageMarginOption.none,
    String? password,
    String? title,
    String? author,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final pdf = pw.Document(
      title: title ?? 'ZenPDF Document',
      author: author ?? 'ZenPDF',
    );

    PdfPageFormat format;
    switch (pageSize) {
      case PageSizeOption.a4:
        format = PdfPageFormat.a4;
        break;
      case PageSizeOption.usLetter:
        format = PdfPageFormat.letter;
        break;
      case PageSizeOption.fitImage:
        format = PdfPageFormat.a4;
        break;
    }

    final marginVal = margin.marginValue;
    final pageMargin = pw.EdgeInsets.all(marginVal);

    final total = images.length;
    for (int i = 0; i < total; i++) {
      final item = images[i];
      if (onProgress != null) {
        onProgress(i + 1, total, 'Enhancing page ${i + 1} of $total...');
      }

      final processedBytes = await ImageFilterService.processImage(
        inputBytes: item.originalBytes,
        filter: item.filter,
        rotationQuarterTurns: item.rotationQuarterTurns,
      );

      final pwImage = pw.MemoryImage(processedBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: pageMargin,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                pwImage,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }

    if (onProgress != null) {
      onProgress(total, total, 'Building PDF document...');
    }

    final pdfBytes = await pdf.save();

    // If password provided, encrypt using AES-256
    if (password != null && password.trim().isNotEmpty) {
      if (onProgress != null) {
        onProgress(total, total, 'Securing PDF with password...');
      }
      final sfDoc = sf.PdfDocument(inputBytes: pdfBytes);
      final security = sfDoc.security;
      security.userPassword = password.trim();
      security.ownerPassword = password.trim();
      security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;

      final encryptedBytes = Uint8List.fromList(sfDoc.saveSync());
      sfDoc.dispose();
      return encryptedBytes;
    }

    return pdfBytes;
  }
}
