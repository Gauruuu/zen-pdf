import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class PdfSecurityService {
  /// Check if a PDF document is protected with a password
  static bool isPdfEncrypted(Uint8List inputBytes) {
    try {
      final doc = sf.PdfDocument(inputBytes: inputBytes);
      doc.dispose();
      return false;
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('password') || err.contains('encrypted') || err.contains('security') || err.contains('permission')) {
        return true;
      }
      final previewLen = inputBytes.length > 8000 ? 8000 : inputBytes.length;
      final latin1Str = latin1.decode(inputBytes.sublist(0, previewLen), allowInvalid: true);
      if (latin1Str.contains('/Encrypt')) {
        return true;
      }
      return false;
    }
  }

  /// Verify if a password unlocks the PDF document
  static bool verifyPassword(Uint8List inputBytes, String password) {
    try {
      final doc = sf.PdfDocument(inputBytes: inputBytes, password: password.trim());
      doc.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Set password on an existing PDF document
  static Future<Uint8List> lockPdf({
    required Uint8List inputBytes,
    required String password,
    String? currentPassword,
  }) async {
    final doc = (currentPassword != null && currentPassword.isNotEmpty)
        ? sf.PdfDocument(inputBytes: inputBytes, password: currentPassword)
        : sf.PdfDocument(inputBytes: inputBytes);

    final security = doc.security;
    security.userPassword = password.trim();
    security.ownerPassword = password.trim();
    security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
    security.permissions.addAll([
      sf.PdfPermissionsFlags.print,
      sf.PdfPermissionsFlags.copyContent,
    ]);

    final securedBytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return securedBytes;
  }

  /// Remove password from an encrypted PDF
  static Future<Uint8List> unlockPdf({
    required Uint8List inputBytes,
    required String password,
  }) async {
    final doc = sf.PdfDocument(inputBytes: inputBytes, password: password.trim());
    
    final unlockedDoc = sf.PdfDocument();
    for (int i = 0; i < doc.pages.count; i++) {
      final template = doc.pages[i].createTemplate();
      final newPage = unlockedDoc.pages.add();
      final size = newPage.getClientSize();
      newPage.graphics.drawPdfTemplate(
        template,
        ui.Offset.zero,
        size,
      );
    }

    doc.dispose();
    final unlockedBytes = Uint8List.fromList(unlockedDoc.saveSync());
    unlockedDoc.dispose();
    return unlockedBytes;
  }

  /// Update document metadata (Title, Author, Subject)
  static Future<Uint8List> updateMetadata({
    required Uint8List inputBytes,
    String? title,
    String? author,
    String? subject,
    String? password,
  }) async {
    final doc = (password != null && password.isNotEmpty)
        ? sf.PdfDocument(inputBytes: inputBytes, password: password)
        : sf.PdfDocument(inputBytes: inputBytes);

    if (title != null && title.isNotEmpty) doc.documentInformation.title = title;
    if (author != null && author.isNotEmpty) doc.documentInformation.author = author;
    if (subject != null && subject.isNotEmpty) doc.documentInformation.subject = subject;

    final updatedBytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return updatedBytes;
  }
}
