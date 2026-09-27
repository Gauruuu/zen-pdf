import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';
import '../models/universal_document_model.dart';

class PptxEngineService {
  /// Parses bytes from a .pptx file into a list of PresentationSlide
  static List<PresentationSlide> parsePptx(Uint8List bytes, {String title = 'Presentation'}) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final slideFiles = archive.files
          .where((f) => f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml'))
          .toList();

      // Sort slide files by index slide1, slide2, slide10
      slideFiles.sort((a, b) {
        final aNum = int.tryParse(RegExp(r'\d+').firstMatch(a.name)?.group(0) ?? '0') ?? 0;
        final bNum = int.tryParse(RegExp(r'\d+').firstMatch(b.name)?.group(0) ?? '0') ?? 0;
        return aNum.compareTo(bNum);
      });

      if (slideFiles.isEmpty) {
        return _defaultSlides(title);
      }

      final List<PresentationSlide> slides = [];
      int idx = 0;

      for (final sf in slideFiles) {
        idx++;
        final xml = utf8.decode(sf.content as List<int>, allowMalformed: true);
        final doc = XmlDocument.parse(xml);

        final List<String> extractedTexts = [];
        for (final p in doc.findAllElements('a:p')) {
          final tElements = p.findAllElements('a:t');
          final pText = tElements.map((t) => t.innerText).join().trim();
          if (pText.isNotEmpty) {
            extractedTexts.add(pText);
          }
        }

        String slideTitle = 'Slide $idx';
        String subtitle = '';
        List<String> bullets = [];

        if (extractedTexts.isNotEmpty) {
          slideTitle = extractedTexts[0];
        }
        if (extractedTexts.length > 1) {
          if (extractedTexts.length == 2 && idx == 1) {
            subtitle = extractedTexts[1];
          } else {
            bullets = extractedTexts.sublist(1);
          }
        }

        slides.add(
          PresentationSlide(
            id: 'slide_$idx',
            title: slideTitle,
            subtitle: subtitle.isNotEmpty ? subtitle : 'Presentation Slide $idx',
            layout: idx == 1 ? SlideLayout.titleSlide : SlideLayout.titleAndContent,
            bullets: bullets.isNotEmpty ? bullets : ['Key point 1', 'Key point 2'],
            footerText: title,
          ),
        );
      }

      return slides;
    } catch (_) {
      return _defaultSlides(title);
    }
  }

  static List<PresentationSlide> _defaultSlides(String title) {
    return [
      PresentationSlide(
        id: 'slide_1',
        title: title.isNotEmpty ? title : 'New Presentation',
        subtitle: 'Created with Zen Presentation Studio',
        layout: SlideLayout.titleSlide,
        backgroundColor: const Color(0xFF0F172A),
        accentColor: const Color(0xFF38BDF8),
        bullets: ['Overview and Executive Summary', 'Key Architecture & Goals'],
      ),
      PresentationSlide(
        id: 'slide_2',
        title: 'Project Highlights & Key Points',
        subtitle: 'Core features and deliverables',
        layout: SlideLayout.titleAndContent,
        backgroundColor: const Color(0xFF1E293B),
        accentColor: const Color(0xFF38BDF8),
        bullets: [
          'High performance native execution',
          'Universal multi-format support',
          'Integrated offline editing and export',
          'Responsive design for desktop and mobile',
        ],
      ),
      PresentationSlide(
        id: 'slide_3',
        title: 'Feature Comparison',
        subtitle: 'Detailed side-by-side analysis',
        layout: SlideLayout.twoColumns,
        backgroundColor: const Color(0xFF0F172A),
        accentColor: const Color(0xFF34D399),
        bullets: [
          'Direct In-App Editing',
          'Full Offline Independence',
          'Zero-Lag Canvas Rendering',
        ],
        rightColumnBullets: [
          'Instant PDF Export',
          'Full MS Office Compatibility',
          'Clean Minimal UI',
        ],
      ),
    ];
  }

  /// Exports presentation deck to a high-resolution landscape presentation PDF
  static Future<Uint8List> exportToPdf(List<PresentationSlide> slides, {String title = 'Presentation'}) async {
    final pdf = pw.Document(title: title);

    for (int i = 0; i < slides.length; i++) {
      final s = slides[i];
      final isTitleSlide = s.layout == SlideLayout.titleSlide;

      // Extract colors
      final rBg = (s.backgroundColor.r * 255).round();
      final gBg = (s.backgroundColor.g * 255).round();
      final bBg = (s.backgroundColor.b * 255).round();
      final pdfBg = PdfColor.fromInt((0xFF << 24) | (rBg << 16) | (gBg << 8) | bBg);

      final rAc = (s.accentColor.r * 255).round();
      final gAc = (s.accentColor.g * 255).round();
      final bAc = (s.accentColor.b * 255).round();
      final pdfAc = PdfColor.fromInt((0xFF << 24) | (rAc << 16) | (gAc << 8) | bAc);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: pw.EdgeInsets.zero,
          build: (context) {
            return pw.Container(
              width: double.infinity,
              height: double.infinity,
              color: pdfBg,
              padding: const pw.EdgeInsets.symmetric(horizontal: 48, vertical: 36),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Top Accent Bar
                  pw.Container(
                    height: 4,
                    width: 80,
                    decoration: pw.BoxDecoration(
                      color: pdfAc,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                  ),
                  pw.SizedBox(height: isTitleSlide ? 60 : 20),

                  // Slide Title
                  pw.Text(
                    s.title,
                    style: pw.TextStyle(
                      fontSize: isTitleSlide ? 34 : 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // Slide Subtitle
                  if (s.subtitle.isNotEmpty) ...[
                    pw.Text(
                      s.subtitle,
                      style: pw.TextStyle(
                        fontSize: isTitleSlide ? 18 : 13,
                        color: pdfAc,
                      ),
                    ),
                    pw.SizedBox(height: isTitleSlide ? 40 : 20),
                  ],

                  // Content Body
                  if (!isTitleSlide) ...[
                    pw.Expanded(
                      child: s.layout == SlideLayout.twoColumns
                          ? pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Expanded(
                                  child: _buildPdfBullets(s.bullets, pdfAc),
                                ),
                                pw.SizedBox(width: 24),
                                pw.Expanded(
                                  child: _buildPdfBullets(s.rightColumnBullets, pdfAc),
                                ),
                              ],
                            )
                          : _buildPdfBullets(s.bullets, pdfAc),
                    ),
                  ] else ...[
                    pw.Spacer(),
                  ],

                  // Slide Footer
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        s.footerText.isNotEmpty ? s.footerText : title,
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                      ),
                      pw.Text(
                        '${i + 1} / ${slides.length}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildPdfBullets(List<String> bullets, PdfColor accentColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: bullets.map((bullet) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 4, right: 10),
                width: 8,
                height: 8,
                decoration: pw.BoxDecoration(
                  color: accentColor,
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  bullet,
                  style: pw.TextStyle(fontSize: 13, color: PdfColors.grey200, lineSpacing: 3),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
