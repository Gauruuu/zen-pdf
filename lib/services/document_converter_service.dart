import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:xml/xml.dart';

enum DocumentFormatType {
  docx('Microsoft Word (.docx)', ['.docx']),
  pptx('PowerPoint Presentation (.pptx)', ['.pptx']),
  xlsx('Excel Spreadsheet (.xlsx)', ['.xlsx']),
  txt('Plain Text (.txt)', ['.txt', '.text']),
  csv('Spreadsheet CSV (.csv)', ['.csv']),
  json('JSON File (.json)', ['.json']),
  html('HTML Document (.html)', ['.html', '.htm']),
  pdf('PDF Document (.pdf)', ['.pdf']),
  image('Picture File', ['.jpg', '.jpeg', '.png', '.webp', '.bmp']);

  final String displayName;
  final List<String> extensions;
  const DocumentFormatType(this.displayName, this.extensions);

  static DocumentFormatType fromExtension(String ext) {
    final lower = ext.toLowerCase().trim();
    for (final type in DocumentFormatType.values) {
      if (type.extensions.any((e) => e == lower || lower.endsWith(e))) {
        return type;
      }
    }
    return DocumentFormatType.txt;
  }
}

class DocumentConverterService {
  /// Converts any supported format to PDF bytes
  static Future<Uint8List> convertToPdf({
    required Uint8List inputBytes,
    required DocumentFormatType sourceFormat,
    String title = 'Converted Document',
    void Function(String status)? onProgress,
  }) async {
    switch (sourceFormat) {
      case DocumentFormatType.docx:
        onProgress?.call('Reading Word document (.docx)...');
        return docxToPdf(inputBytes, title: title);

      case DocumentFormatType.pptx:
        onProgress?.call('Reading PowerPoint presentation (.pptx)...');
        return pptxToPdf(inputBytes, title: title);

      case DocumentFormatType.xlsx:
        onProgress?.call('Reading Excel spreadsheet (.xlsx)...');
        return xlsxToPdf(inputBytes, title: title);

      case DocumentFormatType.txt:
      case DocumentFormatType.json:
      case DocumentFormatType.html:
        onProgress?.call('Formatting text into PDF...');
        return textToPdf(utf8.decode(inputBytes, allowMalformed: true), title: title);

      case DocumentFormatType.csv:
        onProgress?.call('Formatting CSV data grid into PDF...');
        return csvToPdf(utf8.decode(inputBytes, allowMalformed: true), title: title);

      case DocumentFormatType.image:
        onProgress?.call('Embedding picture into PDF...');
        return imageToPdf(inputBytes, title: title);

      case DocumentFormatType.pdf:
        return inputBytes;
    }
  }

  /// Convert Microsoft Word (.docx) to PDF
  static Future<Uint8List> docxToPdf(Uint8List docxBytes, {String title = 'Document'}) async {
    final archive = ZipDecoder().decodeBytes(docxBytes);
    final docXmlFile = archive.findFile('word/document.xml');
    
    if (docXmlFile == null) {
      throw Exception('Invalid Word file: word/document.xml not found.');
    }

    final xmlContent = utf8.decode(docXmlFile.content as List<int>, allowMalformed: true);
    final document = XmlDocument.parse(xmlContent);

    final pdf = pw.Document(title: title);
    final paragraphs = document.findAllElements('w:p');

    final List<pw.Widget> widgets = [];

    // Document Title Header
    widgets.add(
      pw.Header(
        level: 0,
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
        ),
      ),
    );
    widgets.add(pw.SizedBox(height: 10));

    for (final p in paragraphs) {
      final runs = p.findAllElements('w:r');
      if (runs.isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }

      final textSpans = <pw.TextSpan>[];
      for (final r in runs) {
        final textElems = r.findAllElements('w:t');
        if (textElems.isEmpty) continue;
        
        final isBold = r.findAllElements('w:b').isNotEmpty;
        final isItalic = r.findAllElements('w:i').isNotEmpty;
        final runText = textElems.map((e) => e.innerText).join('');

        textSpans.add(
          pw.TextSpan(
            text: runText,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
              color: PdfColors.grey900,
            ),
          ),
        );
      }

      if (textSpans.isNotEmpty) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.RichText(
              text: pw.TextSpan(children: textSpans),
            ),
          ),
        );
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) => widgets,
      ),
    );

    return pdf.save();
  }

  /// Convert PowerPoint (.pptx) to PDF (16:9 Presentation Slides)
  static Future<Uint8List> pptxToPdf(Uint8List pptxBytes, {String title = 'Presentation'}) async {
    final archive = ZipDecoder().decodeBytes(pptxBytes);
    final pdf = pw.Document(title: title);

    final slideFiles = archive.files
        .where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
        .toList();

    slideFiles.sort((a, b) => a.name.compareTo(b.name));

    if (slideFiles.isEmpty) {
      throw Exception('No slides found in PowerPoint presentation.');
    }

    final slideFormat = PdfPageFormat.a4.landscape;

    int slideIndex = 1;
    for (final slideFile in slideFiles) {
      final xmlContent = utf8.decode(slideFile.content as List<int>, allowMalformed: true);
      final doc = XmlDocument.parse(xmlContent);

      final textElements = doc.findAllElements('a:t');
      final slideTexts = textElements.map((e) => e.innerText.trim()).where((t) => t.isNotEmpty).toList();

      final slideTitle = slideTexts.isNotEmpty ? slideTexts.first : 'Slide $slideIndex';
      final slideBody = slideTexts.length > 1 ? slideTexts.sublist(1) : <String>[];

      pdf.addPage(
        pw.Page(
          pageFormat: slideFormat,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 1.5),
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColors.white,
              ),
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Zen PDF • Presentation Deck',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'Slide $slideIndex of ${slideFiles.length}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                      ),
                    ],
                  ),
                  pw.Divider(color: PdfColors.blue700, thickness: 1.5),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    slideTitle,
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: slideBody.map((item) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 8),
                          child: pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('- ', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue600)),
                              pw.Expanded(
                                child: pw.Text(
                                  item,
                                  style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey800, lineSpacing: 1.3),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      slideIndex++;
    }

    return pdf.save();
  }

  /// Convert Excel (.xlsx) to PDF (Formatted Data Grid)
  static Future<Uint8List> xlsxToPdf(Uint8List xlsxBytes, {String title = 'Spreadsheet'}) async {
    final archive = ZipDecoder().decodeBytes(xlsxBytes);
    
    final sharedStrings = <String>[];
    final ssFile = archive.findFile('xl/sharedStrings.xml');
    if (ssFile != null) {
      final ssXml = utf8.decode(ssFile.content as List<int>, allowMalformed: true);
      final ssDoc = XmlDocument.parse(ssXml);
      for (final si in ssDoc.findAllElements('si')) {
        final tElems = si.findAllElements('t');
        sharedStrings.add(tElems.map((e) => e.innerText).join(''));
      }
    }

    final sheetFile = archive.findFile('xl/worksheets/sheet1.xml') ?? 
                      archive.files.firstWhere((f) => f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml'));

    final sheetXml = utf8.decode(sheetFile.content as List<int>, allowMalformed: true);
    final sheetDoc = XmlDocument.parse(sheetXml);

    final List<List<String>> tableData = [];

    for (final row in sheetDoc.findAllElements('row')) {
      final List<String> rowCells = [];
      for (final c in row.findAllElements('c')) {
        final type = c.getAttribute('t');
        final valElem = c.findElements('v').firstOrNull;
        if (valElem != null) {
          final rawVal = valElem.innerText;
          if (type == 's') {
            final idx = int.tryParse(rawVal) ?? 0;
            rowCells.add(idx < sharedStrings.length ? sharedStrings[idx] : rawVal);
          } else {
            rowCells.add(rawVal);
          }
        } else {
          final isElem = c.findAllElements('t').firstOrNull;
          rowCells.add(isElem != null ? isElem.innerText : '');
        }
      }
      if (rowCells.any((c) => c.trim().isNotEmpty)) {
        tableData.add(rowCells);
      }
    }

    if (tableData.isEmpty) {
      tableData.add(['No Data Found']);
    }

    final maxCols = tableData.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    for (final r in tableData) {
      while (r.length < maxCols) {
        r.add('');
      }
    }

    final pdf = pw.Document(title: title);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text('Excel Spreadsheet Export', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: tableData.first,
            data: tableData.length > 1 ? tableData.sublist(1) : [],
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Convert Plain Text / Code to PDF
  static Future<Uint8List> textToPdf(String text, {String title = 'Document'}) async {
    final pdf = pw.Document(title: title);
    final lines = text.split('\n');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          ),
          pw.SizedBox(height: 12),
          ...lines.map((line) => pw.Text(
                line,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900, lineSpacing: 1.25),
              )),
        ],
      ),
    );

    return pdf.save();
  }

  /// Convert CSV to PDF
  static Future<Uint8List> csvToPdf(String csvContent, {String title = 'CSV Data'}) async {
    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final List<List<String>> tableData = lines.map((l) {
      return l.split(',').map((c) => c.replaceAll('"', '').trim()).toList();
    }).toList();

    if (tableData.isEmpty) {
      tableData.add(['Empty CSV']);
    }

    final maxCols = tableData.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    for (final r in tableData) {
      while (r.length < maxCols) {
        r.add('');
      }
    }

    final pdf = pw.Document(title: title);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: tableData.first,
            data: tableData.length > 1 ? tableData.sublist(1) : [],
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// Convert Image to Single Page PDF
  static Future<Uint8List> imageToPdf(Uint8List imageBytes, {String title = 'Image'}) async {
    final pdf = pw.Document(title: title);
    final pwImage = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(pwImage, fit: pw.BoxFit.contain),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Convert PDF to Microsoft Word (.docx)
  static Future<Uint8List> pdfToDocx(Uint8List pdfBytes, {String title = 'Converted_Document'}) async {
    final sfDoc = sf.PdfDocument(inputBytes: pdfBytes);
    final textExtractor = sf.PdfTextExtractor(sfDoc);
    final fullText = textExtractor.extractText();
    sfDoc.dispose();

    final lines = fullText.split('\n');
    final archive = Archive();

    const contentTypesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n  <Default Extension="xml" ContentType="application/xml"/>\n  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>\n</Types>';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    const relsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>\n</Relationships>';
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.writeln('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    buffer.writeln('  <w:body>');

    buffer.writeln('    <w:p>');
    buffer.writeln('      <w:r>');
    buffer.writeln('        <w:rPr><w:b/><w:sz w:val="36"/><w:color w:val="1E3A8A"/></w:rPr>');
    buffer.writeln('        <w:t>${_escapeXml(title)}</w:t>');
    buffer.writeln('      </w:r>');
    buffer.writeln('    </w:p>');

    for (final line in lines) {
      final trimmed = line.trim();
      buffer.writeln('    <w:p>');
      if (trimmed.isNotEmpty) {
        buffer.writeln('      <w:r>');
        buffer.writeln('        <w:rPr><w:sz w:val="22"/></w:rPr>');
        buffer.writeln('        <w:t>${_escapeXml(trimmed)}</w:t>');
        buffer.writeln('      </w:r>');
      }
      buffer.writeln('    </w:p>');
    }

    buffer.writeln('  </w:body>');
    buffer.writeln('</w:document>');

    final docXml = buffer.toString();
    archive.addFile(ArchiveFile('word/document.xml', docXml.length, utf8.encode(docXml)));

    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    return Uint8List.fromList(encoded);
  }

  /// Convert PDF to Microsoft PowerPoint (.pptx)
  static Future<Uint8List> pdfToPptx(Uint8List pdfBytes, {String title = 'Presentation'}) async {
    final sfDoc = sf.PdfDocument(inputBytes: pdfBytes);
    final textExtractor = sf.PdfTextExtractor(sfDoc);
    
    final pageCount = sfDoc.pages.count;
    final archive = Archive();

    // Content types
    final ctBuffer = StringBuffer();
    ctBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    ctBuffer.writeln('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');
    ctBuffer.writeln('  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>');
    ctBuffer.writeln('  <Default Extension="xml" ContentType="application/xml"/>');
    ctBuffer.writeln('  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>');
    for (int i = 1; i <= pageCount; i++) {
      ctBuffer.writeln('  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
    }
    ctBuffer.writeln('</Types>');
    final ctStr = ctBuffer.toString();
    archive.addFile(ArchiveFile('[Content_Types].xml', ctStr.length, utf8.encode(ctStr)));

    // _rels/.rels
    const rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>\n</Relationships>';
    archive.addFile(ArchiveFile('_rels/.rels', rootRels.length, utf8.encode(rootRels)));

    // ppt/presentation.xml
    final presBuffer = StringBuffer();
    presBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    presBuffer.writeln('<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">');
    presBuffer.writeln('  <p:sldIdLst>');
    for (int i = 1; i <= pageCount; i++) {
      presBuffer.writeln('    <p:sldId id="${255 + i}" r:id="rId$i"/>');
    }
    presBuffer.writeln('  </p:sldIdLst>');
    presBuffer.writeln('</p:presentation>');
    final presStr = presBuffer.toString();
    archive.addFile(ArchiveFile('ppt/presentation.xml', presStr.length, utf8.encode(presStr)));

    // ppt/_rels/presentation.xml.rels
    final presRelsBuffer = StringBuffer();
    presRelsBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    presRelsBuffer.writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
    for (int i = 1; i <= pageCount; i++) {
      presRelsBuffer.writeln('  <Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$i.xml"/>');
    }
    presRelsBuffer.writeln('</Relationships>');
    final presRelsStr = presRelsBuffer.toString();
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', presRelsStr.length, utf8.encode(presRelsStr)));

    // Generate each slide XML
    for (int i = 0; i < pageCount; i++) {
      final slideNum = i + 1;
      final pageText = textExtractor.extractText(startPageIndex: i, endPageIndex: i);
      final lines = pageText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final slideTitle = lines.isNotEmpty ? lines.first : 'Slide $slideNum';
      final slideBullets = lines.length > 1 ? lines.sublist(1) : <String>[];

      final sBuf = StringBuffer();
      sBuf.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
      sBuf.writeln('<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">');
      sBuf.writeln('  <p:cSld>');
      sBuf.writeln('    <p:spTree>');
      sBuf.writeln('      <p:sp>');
      sBuf.writeln('        <p:txBody>');
      sBuf.writeln('          <a:p><a:r><a:t>${_escapeXml(slideTitle)}</a:t></a:r></a:p>');
      for (final bullet in slideBullets) {
        sBuf.writeln('          <a:p><a:r><a:t>${_escapeXml(bullet)}</a:t></a:r></a:p>');
      }
      sBuf.writeln('        </p:txBody>');
      sBuf.writeln('      </p:sp>');
      sBuf.writeln('    </p:spTree>');
      sBuf.writeln('  </p:cSld>');
      sBuf.writeln('</p:sld>');

      final sStr = sBuf.toString();
      archive.addFile(ArchiveFile('ppt/slides/slide$slideNum.xml', sStr.length, utf8.encode(sStr)));
    }

    sfDoc.dispose();

    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    return Uint8List.fromList(encoded);
  }

  /// Convert PDF to Microsoft Excel (.xlsx)
  static Future<Uint8List> pdfToXlsx(Uint8List pdfBytes, {String title = 'Spreadsheet'}) async {
    final sfDoc = sf.PdfDocument(inputBytes: pdfBytes);
    final textExtractor = sf.PdfTextExtractor(sfDoc);
    final fullText = textExtractor.extractText();
    sfDoc.dispose();

    final rawLines = fullText.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final List<List<String>> tableRows = rawLines.map((line) {
      return line.split(RegExp(r'\s{2,}|\t|,')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    }).where((r) => r.isNotEmpty).toList();

    if (tableRows.isEmpty) {
      tableRows.add(['Page Content', 'Zen PDF Export']);
    }

    final archive = Archive();

    // [Content_Types].xml
    const ctXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n  <Default Extension="xml" ContentType="application/xml"/>\n  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\n  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\n</Types>';
    archive.addFile(ArchiveFile('[Content_Types].xml', ctXml.length, utf8.encode(ctXml)));

    // _rels/.rels
    const rootRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\n</Relationships>';
    archive.addFile(ArchiveFile('_rels/.rels', rootRels.length, utf8.encode(rootRels)));

    // xl/workbook.xml
    const wbXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\n  <sheets>\n    <sheet name="Sheet1" sheetId="1" r:id="rId1"/>\n  </sheets>\n</workbook>';
    archive.addFile(ArchiveFile('xl/workbook.xml', wbXml.length, utf8.encode(wbXml)));

    // xl/_rels/workbook.xml.rels
    const wbRels = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>\n</Relationships>';
    archive.addFile(ArchiveFile('xl/_rels/workbook.xml.rels', wbRels.length, utf8.encode(wbRels)));

    // xl/worksheets/sheet1.xml
    final sheetBuffer = StringBuffer();
    sheetBuffer.writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    sheetBuffer.writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
    sheetBuffer.writeln('  <sheetData>');

    for (int r = 0; r < tableRows.length; r++) {
      final rowNum = r + 1;
      sheetBuffer.writeln('    <row r="$rowNum">');
      final rowData = tableRows[r];
      for (int c = 0; c < rowData.length; c++) {
        final colLetter = String.fromCharCode(65 + (c % 26));
        final cellRef = '$colLetter$rowNum';
        final val = rowData[c];
        sheetBuffer.writeln('      <c r="$cellRef" t="inlineStr"><is><t>${_escapeXml(val)}</t></is></c>');
      }
      sheetBuffer.writeln('    </row>');
    }

    sheetBuffer.writeln('  </sheetData>');
    sheetBuffer.writeln('</worksheet>');

    final sheetStr = sheetBuffer.toString();
    archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetStr.length, utf8.encode(sheetStr)));

    final zipEncoder = ZipEncoder();
    final encoded = zipEncoder.encode(archive);
    return Uint8List.fromList(encoded);
  }

  /// Convert PDF to HTML Document
  static Future<String> pdfToHtml(Uint8List pdfBytes, {String title = 'Document'}) async {
    final sfDoc = sf.PdfDocument(inputBytes: pdfBytes);
    final textExtractor = sf.PdfTextExtractor(sfDoc);
    final fullText = textExtractor.extractText();
    sfDoc.dispose();

    final lines = fullText.split('\n');
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8">');
    buffer.writeln('  <title>${_escapeXml(title)}</title>');
    buffer.writeln('  <style>');
    buffer.writeln('    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; margin: 40px; background: #f8fafc; color: #0f172a; line-height: 1.6; }');
    buffer.writeln('    .container { max-width: 800px; margin: 0 auto; background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); }');
    buffer.writeln('    h1 { color: #1e3a8a; border-bottom: 2px solid #2563eb; padding-bottom: 8px; }');
    buffer.writeln('    p { margin-bottom: 12px; }');
    buffer.writeln('  </style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('  <div class="container">');
    buffer.writeln('    <h1>${_escapeXml(title)}</h1>');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        buffer.writeln('    <p>${_escapeXml(trimmed)}</p>');
      }
    }
    buffer.writeln('  </div>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');
    return buffer.toString();
  }

  /// Convert PDF to JSON
  static Future<String> pdfToJson(Uint8List pdfBytes, {String title = 'Document'}) async {
    final sfDoc = sf.PdfDocument(inputBytes: pdfBytes);
    final textExtractor = sf.PdfTextExtractor(sfDoc);
    
    final List<Map<String, dynamic>> pagesData = [];
    for (int i = 0; i < sfDoc.pages.count; i++) {
      final pageText = textExtractor.extractText(startPageIndex: i, endPageIndex: i);
      pagesData.add({
        'page': i + 1,
        'content': pageText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList(),
      });
    }
    sfDoc.dispose();

    final result = {
      'title': title,
      'totalPages': pagesData.length,
      'pages': pagesData,
    };
    return const JsonEncoder.withIndent('  ').convert(result);
  }

  /// Convert PDF to Plain Text
  static Future<String> pdfToText(Uint8List pdfBytes) async {
    final sfDoc = sf.PdfDocument(inputBytes: pdfBytes);
    final textExtractor = sf.PdfTextExtractor(sfDoc);
    final fullText = textExtractor.extractText();
    sfDoc.dispose();
    return fullText;
  }

  /// Convert PDF to CSV
  static Future<String> pdfToCsv(Uint8List pdfBytes) async {
    final sfDoc = sf.PdfDocument(inputBytes: pdfBytes);
    final textExtractor = sf.PdfTextExtractor(sfDoc);
    final fullText = textExtractor.extractText();
    sfDoc.dispose();

    final lines = fullText.split('\n');
    final buffer = StringBuffer();
    for (final line in lines) {
      final tokens = line.split(RegExp(r'\s{2,}|\t'));
      buffer.writeln(tokens.map((t) => '"$t"').join(','));
    }
    return buffer.toString();
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
