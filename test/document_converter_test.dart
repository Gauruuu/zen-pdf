import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:archive/archive.dart';
import 'package:zen_pdf/services/document_converter_service.dart';
import 'package:zen_pdf/views/common/fidget_spinner_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentConverterService Tests', () {
    test('Converts Text to PDF', () async {
      const text = 'Hello Zen PDF!\nThis is a plain text conversion test.\nLine 3 of document.';
      final pdfBytes = await DocumentConverterService.textToPdf(text, title: 'Sample Text');
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46])); // '%PDF'
    });

    test('Converts CSV to PDF', () async {
      const csv = 'Name,Role,City\nAlice,Developer,Bangalore\nBob,Designer,Mumbai\nCharlie,Manager,Delhi';
      final pdfBytes = await DocumentConverterService.csvToPdf(csv, title: 'Employee Data');
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46])); // '%PDF'
    });

    test('Converts DOCX to PDF', () async {
      // Create a mock docx in memory
      final archive = Archive();
      const docXml = '''<?xml version="1.0" encoding="UTF-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p><w:r><w:t>Heading Paragraph</w:t></w:r></w:p>
    <w:p><w:r><w:b/><w:t>Bold Text Line</w:t></w:r></w:p>
  </w:body>
</w:document>''';
      archive.addFile(ArchiveFile('word/document.xml', docXml.length, utf8.encode(docXml)));
      final docxBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final pdfBytes = await DocumentConverterService.docxToPdf(docxBytes, title: 'Test Docx');
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Converts PPTX to PDF', () async {
      // Create a mock pptx in memory
      final archive = Archive();
      const slide1Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp><p:txBody><a:p><a:r><a:t>Slide 1 Title</a:t></a:r></a:p></p:txBody></p:sp>
      <p:sp><p:txBody><a:p><a:r><a:t>Bullet Point 1</a:t></a:r></a:p></p:txBody></p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
      archive.addFile(ArchiveFile('ppt/slides/slide1.xml', slide1Xml.length, utf8.encode(slide1Xml)));
      final pptxBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final pdfBytes = await DocumentConverterService.pptxToPdf(pptxBytes, title: 'Test PPTX');
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Converts XLSX to PDF', () async {
      // Create a mock xlsx in memory
      final archive = Archive();
      const sharedStringsXml = '''<?xml version="1.0" encoding="UTF-8"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <si><t>Item</t></si>
  <si><t>Price</t></si>
  <si><t>Apple</t></si>
</sst>''';
      const sheet1Xml = '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>
    <row r="2"><c r="A2" t="s"><v>2</v></c><c r="B2"><v>100</v></c></row>
  </sheetData>
</worksheet>''';
      archive.addFile(ArchiveFile('xl/sharedStrings.xml', sharedStringsXml.length, utf8.encode(sharedStringsXml)));
      archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheet1Xml.length, utf8.encode(sheet1Xml)));
      final xlsxBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      final pdfBytes = await DocumentConverterService.xlsxToPdf(xlsxBytes, title: 'Test Spreadsheet');
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });

    test('Converts PDF to DOCX OpenXML package', () async {
      final pdfBytes = await DocumentConverterService.textToPdf('Sample PDF line 1\nSample PDF line 2');
      final docxBytes = await DocumentConverterService.pdfToDocx(pdfBytes, title: 'Extracted Word');
      expect(docxBytes, isNotEmpty);
      final archive = ZipDecoder().decodeBytes(docxBytes);
      expect(archive.findFile('word/document.xml'), isNotNull);
      expect(archive.findFile('[Content_Types].xml'), isNotNull);
    });

    test('Converts PDF to PPTX OpenXML presentation', () async {
      final pdfBytes = await DocumentConverterService.textToPdf('Slide Title 1\nBullet point 1\nBullet point 2');
      final pptxBytes = await DocumentConverterService.pdfToPptx(pdfBytes, title: 'Exported PPTX');
      expect(pptxBytes, isNotEmpty);
      final archive = ZipDecoder().decodeBytes(pptxBytes);
      expect(archive.findFile('ppt/presentation.xml'), isNotNull);
      expect(archive.findFile('ppt/slides/slide1.xml'), isNotNull);
    });

    test('Converts PDF to XLSX OpenXML workbook', () async {
      final pdfBytes = await DocumentConverterService.textToPdf('Item  Quantity  Price\nApples  10  50\nOranges  20  80');
      final xlsxBytes = await DocumentConverterService.pdfToXlsx(pdfBytes, title: 'Exported Excel');
      expect(xlsxBytes, isNotEmpty);
      final archive = ZipDecoder().decodeBytes(xlsxBytes);
      expect(archive.findFile('xl/workbook.xml'), isNotNull);
      expect(archive.findFile('xl/worksheets/sheet1.xml'), isNotNull);
    });

    test('Converts PDF to HTML and JSON', () async {
      final pdfBytes = await DocumentConverterService.textToPdf('Web Content Heading\nParagraph 1 text content');
      final html = await DocumentConverterService.pdfToHtml(pdfBytes, title: 'Test HTML');
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('Test HTML'));
      expect(html, contains('Content'));

      final jsonStr = await DocumentConverterService.pdfToJson(pdfBytes, title: 'Test JSON');
      expect(jsonStr, contains('totalPages'));
      expect(jsonStr, contains('content'));
    });
  });

  group('FidgetSpinnerLoader Widget Test', () {
    testWidgets('Renders FidgetSpinnerLoader with message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: FidgetSpinnerLoader(
                size: 64,
                message: 'Spinning test...',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Spinning test...'), findsOneWidget);
      expect(find.byType(FidgetSpinnerLoader), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
