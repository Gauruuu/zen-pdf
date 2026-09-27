import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';
import '../models/universal_document_model.dart';

class DocxEngineService {
  /// Parses bytes from a .docx file into structured DocParagraphs
  static List<DocParagraph> parseDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final docXmlFile = archive.findFile('word/document.xml');
      if (docXmlFile == null) {
        return _fallbackTextToParagraphs(utf8.decode(bytes, allowMalformed: true));
      }

      final xmlString = utf8.decode(docXmlFile.content as List<int>, allowMalformed: true);
      final document = XmlDocument.parse(xmlString);
      final pElements = document.findAllElements('w:p');

      if (pElements.isEmpty) {
        return [
          DocParagraph(
            id: 'p_1',
            type: DocBlockType.body,
            runs: [TextRun(text: 'Empty document')],
          )
        ];
      }

      final List<DocParagraph> paragraphs = [];
      int idx = 0;

      for (final p in pElements) {
        idx++;
        // Determine style/type
        DocBlockType type = DocBlockType.body;
        final pStyle = p.findAllElements('w:pStyle').firstOrNull?.getAttribute('w:val')?.toLowerCase();
        if (pStyle != null) {
          if (pStyle.contains('heading1') || pStyle.contains('heading 1') || pStyle == 'title') {
            type = DocBlockType.heading1;
          } else if (pStyle.contains('heading2') || pStyle.contains('heading 2')) {
            type = DocBlockType.heading2;
          } else if (pStyle.contains('heading3') || pStyle.contains('heading 3')) {
            type = DocBlockType.heading3;
          } else if (pStyle.contains('list') || pStyle.contains('bullet')) {
            type = DocBlockType.bullet;
          }
        }

        // Determine alignment
        DocParagraphAlign align = DocParagraphAlign.left;
        final jc = p.findAllElements('w:jc').firstOrNull?.getAttribute('w:val');
        if (jc == 'center') align = DocParagraphAlign.center;
        if (jc == 'right') align = DocParagraphAlign.right;
        if (jc == 'both') align = DocParagraphAlign.justify;

        final List<TextRun> runs = [];
        final rElements = p.findAllElements('w:r');

        for (final r in rElements) {
          final tElements = r.findAllElements('w:t');
          final text = tElements.map((t) => t.innerText).join();
          if (text.isEmpty) continue;

          final isBold = r.findAllElements('w:b').isNotEmpty;
          final isItalic = r.findAllElements('w:i').isNotEmpty;
          final isUnderline = r.findAllElements('w:u').isNotEmpty;
          final isStrike = r.findAllElements('w:strike').isNotEmpty;

          Color textColor = Colors.black87;
          final colorElem = r.findAllElements('w:color').firstOrNull;
          if (colorElem != null) {
            final hex = colorElem.getAttribute('w:val');
            if (hex != null && hex.length == 6) {
              textColor = Color(int.parse('0xFF$hex'));
            }
          }

          runs.add(
            TextRun(
              text: text,
              isBold: isBold,
              isItalic: isItalic,
              isUnderline: isUnderline,
              isStrikethrough: isStrike,
              color: textColor,
              fontSize: type == DocBlockType.heading1
                  ? 22.0
                  : type == DocBlockType.heading2
                      ? 18.0
                      : type == DocBlockType.heading3
                          ? 16.0
                          : 14.0,
            ),
          );
        }

        if (runs.isEmpty) {
          runs.add(TextRun(text: ''));
        }

        paragraphs.add(
          DocParagraph(
            id: 'p_$idx',
            type: type,
            align: align,
            runs: runs,
          ),
        );
      }

      return paragraphs;
    } catch (_) {
      return _fallbackTextToParagraphs(utf8.decode(bytes, allowMalformed: true));
    }
  }

  static List<DocParagraph> _fallbackTextToParagraphs(String rawText) {
    final lines = rawText.split('\n');
    if (lines.isEmpty) {
      return [DocParagraph(id: 'p_1', runs: [TextRun(text: '')])];
    }

    final List<DocParagraph> list = [];
    int idx = 0;
    for (final line in lines) {
      idx++;
      var type = DocBlockType.body;
      var text = line.trimRight();

      if (text.startsWith('# ')) {
        type = DocBlockType.heading1;
        text = text.substring(2);
      } else if (text.startsWith('## ')) {
        type = DocBlockType.heading2;
        text = text.substring(3);
      } else if (text.startsWith('### ')) {
        type = DocBlockType.heading3;
        text = text.substring(4);
      } else if (text.startsWith('- ') || text.startsWith('* ')) {
        type = DocBlockType.bullet;
        text = text.substring(2);
      } else if (RegExp(r'^\d+\.\s').hasMatch(text)) {
        type = DocBlockType.numbered;
        text = text.replaceFirst(RegExp(r'^\d+\.\s'), '');
      }

      list.add(
        DocParagraph(
          id: 'p_$idx',
          type: type,
          runs: [
            TextRun(
              text: text,
              fontSize: type == DocBlockType.heading1
                  ? 22.0
                  : type == DocBlockType.heading2
                      ? 18.0
                      : 14.0,
            )
          ],
        ),
      );
    }
    return list;
  }

  /// Generates a valid Microsoft Word (.docx) zip archive from paragraphs
  static Uint8List exportToDocx(List<DocParagraph> paragraphs, {String title = 'Document'}) {
    final archive = Archive();

    // 1. [Content_Types].xml
    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));

    // 2. _rels/.rels
    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));

    // 3. word/document.xml
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n');
    buffer.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\n');
    buffer.write('  <w:body>\n');

    for (final p in paragraphs) {
      buffer.write('    <w:p>\n');
      buffer.write('      <w:pPr>\n');

      // Paragraph Style
      if (p.type == DocBlockType.heading1) {
        buffer.write('        <w:pStyle w:val="Heading1"/>\n');
      } else if (p.type == DocBlockType.heading2) {
        buffer.write('        <w:pStyle w:val="Heading2"/>\n');
      } else if (p.type == DocBlockType.heading3) {
        buffer.write('        <w:pStyle w:val="Heading3"/>\n');
      }

      // Alignment
      if (p.align == DocParagraphAlign.center) {
        buffer.write('        <w:jc w:val="center"/>\n');
      } else if (p.align == DocParagraphAlign.right) {
        buffer.write('        <w:jc w:val="right"/>\n');
      } else if (p.align == DocParagraphAlign.justify) {
        buffer.write('        <w:jc w:val="both"/>\n');
      }

      buffer.write('      </w:pPr>\n');

      // Runs
      for (final run in p.runs) {
        buffer.write('      <w:r>\n');
        buffer.write('        <w:rPr>\n');
        if (run.isBold || p.type == DocBlockType.heading1 || p.type == DocBlockType.heading2) {
          buffer.write('          <w:b/>\n');
        }
        if (run.isItalic) buffer.write('          <w:i/>\n');
        if (run.isUnderline) buffer.write('          <w:u w:val="single"/>\n');
        if (run.isStrikethrough) buffer.write('          <w:strike/>\n');
        final r = (run.color.r * 255).round().toRadixString(16).padLeft(2, '0');
        final g = (run.color.g * 255).round().toRadixString(16).padLeft(2, '0');
        final b = (run.color.b * 255).round().toRadixString(16).padLeft(2, '0');
        buffer.write('          <w:color w:val="$r$g$b"/>\n');
        final halfPt = (run.fontSize * 2).round();
        buffer.write('          <w:sz w:val="$halfPt"/>\n');
        buffer.write('        </w:rPr>\n');
        final escapedText = run.text
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;');
        buffer.write('        <w:t xml:space="preserve">$escapedText</w:t>\n');
        buffer.write('      </w:r>\n');
      }

      buffer.write('    </w:p>\n');
    }

    buffer.write('  </w:body>\n');
    buffer.write('</w:document>');

    final docXml = buffer.toString();
    archive.addFile(ArchiveFile('word/document.xml', docXml.length, utf8.encode(docXml)));

    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData);
  }

  /// Exports paragraphs to styled PDF
  static Future<Uint8List> exportToPdf(List<DocParagraph> paragraphs, {String title = 'Document'}) async {
    final pdf = pw.Document(title: title);

    final List<pw.Widget> widgets = [];

    for (final p in paragraphs) {
      final isH1 = p.type == DocBlockType.heading1;
      final isH2 = p.type == DocBlockType.heading2;
      final isH3 = p.type == DocBlockType.heading3;
      final isBullet = p.type == DocBlockType.bullet;
      final isQuote = p.type == DocBlockType.quote;
      final isCode = p.type == DocBlockType.code;

      pw.TextAlign align = pw.TextAlign.left;
      if (p.align == DocParagraphAlign.center) align = pw.TextAlign.center;
      if (p.align == DocParagraphAlign.right) align = pw.TextAlign.right;
      if (p.align == DocParagraphAlign.justify) align = pw.TextAlign.justify;

      final spans = p.runs.map((r) {
        final rVal = (r.color.r * 255).round();
        final gVal = (r.color.g * 255).round();
        final bVal = (r.color.b * 255).round();
        final pdfColor = PdfColor.fromInt((0xFF << 24) | (rVal << 16) | (gVal << 8) | bVal);

        return pw.TextSpan(
          text: r.text,
          style: pw.TextStyle(
            fontSize: isH1
                ? 20
                : isH2
                    ? 16
                    : isH3
                        ? 14
                        : (r.fontSize > 0 ? r.fontSize : 11),
            fontWeight: (r.isBold || isH1 || isH2) ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: (r.isItalic || isQuote) ? pw.FontStyle.italic : pw.FontStyle.normal,
            color: pdfColor,
          ),
        );
      }).toList();

      pw.Widget paragraphWidget = pw.RichText(
        textAlign: align,
        text: pw.TextSpan(children: spans),
      );

      if (isBullet) {
        paragraphWidget = pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 4, right: 8),
              width: 5,
              height: 5,
              decoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.Expanded(child: paragraphWidget),
          ],
        );
      } else if (isQuote) {
        paragraphWidget = pw.Container(
          padding: const pw.EdgeInsets.only(left: 12, top: 4, bottom: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: PdfColors.blue600, width: 3)),
          ),
          child: paragraphWidget,
        );
      } else if (isCode) {
        paragraphWidget = pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: paragraphWidget,
        );
      }

      widgets.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(
            top: isH1 ? 16 : isH2 ? 12 : 4,
            bottom: isH1 ? 8 : isH2 ? 6 : 4,
          ),
          child: paragraphWidget,
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => widgets,
      ),
    );

    return pdf.save();
  }
}
