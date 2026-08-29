import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zen_pdf/core/constants/app_constants.dart';
import 'package:zen_pdf/models/scanned_image.dart';
import 'package:zen_pdf/services/image_filter_service.dart';
import 'package:zen_pdf/services/pdf_generator_service.dart';
import 'package:zen_pdf/services/pdf_organizer_service.dart';
import 'package:zen_pdf/services/pdf_security_service.dart';
import 'package:zen_pdf/services/pdf_signature_verifier_service.dart';

void main() {
  late Uint8List sampleImageBytes;

  setUp(() {
    final image = img.Image(width: 100, height: 100);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    sampleImageBytes = Uint8List.fromList(img.encodeJpg(image));
  });

  test('ImageFilterService applies filters and rotation', () async {
    final filtered = await ImageFilterService.processImage(
      inputBytes: sampleImageBytes,
      filter: DocumentFilter.cleanScan,
      rotationQuarterTurns: 1,
    );
    expect(filtered, isNotEmpty);
  });

  test('PdfGeneratorService creates a valid PDF from images', () async {
    final scannedImage = ScannedImage(
      id: 'test_1',
      originalBytes: sampleImageBytes,
      filter: DocumentFilter.original,
    );

    final pdfBytes = await PdfGeneratorService.createPdfFromImages(
      images: [scannedImage],
      pageSize: PageSizeOption.a4,
      margin: PageMarginOption.small,
    );

    expect(pdfBytes, isNotEmpty);
    expect(PdfOrganizerService.getPageCount(pdfBytes), equals(1));
  });

  test('PdfSecurityService locks and unlocks PDF with password', () async {
    final scannedImage = ScannedImage(
      id: 'test_sec',
      originalBytes: sampleImageBytes,
    );

    final originalPdf = await PdfGeneratorService.createPdfFromImages(
      images: [scannedImage],
    );

    final lockedPdf = await PdfSecurityService.lockPdf(
      inputBytes: originalPdf,
      password: 'mypassword123',
    );
    expect(lockedPdf, isNotEmpty);

    final unlockedPdf = await PdfSecurityService.unlockPdf(
      inputBytes: lockedPdf,
      password: 'mypassword123',
    );
    expect(unlockedPdf, isNotEmpty);
    expect(PdfOrganizerService.getPageCount(unlockedPdf), equals(1));
  });

  test('PdfOrganizerService merges and splits PDFs', () async {
    final image1 = ScannedImage(id: 'img1', originalBytes: sampleImageBytes);
    final image2 = ScannedImage(id: 'img2', originalBytes: sampleImageBytes);

    final pdf1 = await PdfGeneratorService.createPdfFromImages(images: [image1]);
    final pdf2 = await PdfGeneratorService.createPdfFromImages(images: [image2]);

    final mergedPdf = await PdfOrganizerService.mergePdfs([pdf1, pdf2]);
    expect(PdfOrganizerService.getPageCount(mergedPdf), equals(2));

    final extractedPdf = await PdfOrganizerService.extractPages(
      inputPdfBytes: mergedPdf,
      pageNumbers: [1],
    );
    expect(PdfOrganizerService.getPageCount(extractedPdf), equals(1));
  });

  test('PdfSignatureVerifierService analyzes digital signatures', () async {
    final image1 = ScannedImage(id: 'img1', originalBytes: sampleImageBytes);
    final pdfBytes = await PdfGeneratorService.createPdfFromImages(images: [image1]);

    final report = await PdfSignatureVerifierService.verifySignatures(
      pdfBytes: pdfBytes,
      fileName: 'Test_Doc.pdf',
    );

    expect(report.fileName, equals('Test_Doc.pdf'));
    expect(report.hasDigitalSignatures, isFalse);
  });
}
