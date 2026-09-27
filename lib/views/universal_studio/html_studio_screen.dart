import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/utils/file_helper.dart';
import '../../services/recent_files_service.dart';
import '../common/fidget_spinner_loader.dart';
import '../pdf_viewer/chrome_pdf_viewer_screen.dart';
import '../gdrm/gdrm_export_dialog.dart';
import 'package:flutter/services.dart';

enum HtmlStudioViewMode { code, visual, split, livePreview }

class HtmlStudioScreen extends StatefulWidget {
  final String? initialFilePath;
  final String? initialTitle;
  final String? initialHtmlContent;
  final bool isExternalIntent;

  const HtmlStudioScreen({
    super.key,
    this.initialFilePath,
    this.initialTitle,
    this.initialHtmlContent,
    this.isExternalIntent = false,
  });

  @override
  State<HtmlStudioScreen> createState() => _HtmlStudioScreenState();
}

class _HtmlStudioScreenState extends State<HtmlStudioScreen> {
  late String _documentTitle;
  bool _isLoading = true;
  String? _filePath;

  HtmlStudioViewMode _viewMode = HtmlStudioViewMode.split;
  double _previewWidth = 800; // 800 = Desktop, 500 = Tablet, 340 = Mobile
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _documentTitle = widget.initialTitle ?? 'index.html';
    _filePath = widget.initialFilePath;
    _initHtml();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initHtml() async {
    setState(() => _isLoading = true);

    if (widget.initialHtmlContent != null && widget.initialHtmlContent!.isNotEmpty) {
      _codeController.text = widget.initialHtmlContent!;
    } else if (_filePath != null && File(_filePath!).existsSync()) {
      final content = await File(_filePath!).readAsString();
      _codeController.text = content;
      _documentTitle = FileHelper.getFileName(_filePath!);
    } else {
      _codeController.text = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Zen HTML Studio</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      margin: 0;
      padding: 32px;
      background-color: #f8fafc;
      color: #0f172a;
    }
    .hero {
      background: linear-gradient(135deg, #2563eb, #1d4ed8);
      color: white;
      padding: 32px;
      border-radius: 16px;
      margin-bottom: 24px;
      box-shadow: 0 10px 25px rgba(37, 99, 235, 0.2);
    }
    h1 { margin: 0 0 8px 0; font-size: 28px; }
    p { font-size: 15px; line-height: 1.6; }
    .card {
      background: white;
      border: 1px solid #e2e8f0;
      padding: 24px;
      border-radius: 12px;
      margin-bottom: 16px;
    }
    .btn {
      display: inline-block;
      background: #2563eb;
      color: white;
      padding: 10px 20px;
      border-radius: 8px;
      text-decoration: none;
      font-weight: bold;
    }
    ul { padding-left: 20px; }
    li { margin-bottom: 8px; }
  </style>
</head>
<body>
  <div class="hero">
    <h1>Welcome to Zen Web Studio</h1>
    <p>Build, edit, and preview responsive HTML/CSS pages offline with live real-time rendering.</p>
  </div>

  <div class="card">
    <h2>Features & Capabilities</h2>
    <ul>
      <li>Live HTML & CSS dual-pane editor</li>
      <li>Instant visual rendering engine</li>
      <li>Export clean HTML or formatted PDF</li>
      <li>Desktop, Tablet, and Mobile viewport testing</li>
    </ul>
    <a href="#" class="btn">Get Started</a>
  </div>
</body>
</html>''';
    }

    setState(() => _isLoading = false);
  }

  void _insertTag(String openTag, String closeTag) {
    final text = _codeController.text;
    final sel = _codeController.selection;
    final start = sel.start >= 0 ? sel.start : text.length;
    final end = sel.end >= 0 ? sel.end : text.length;
    final selectedText = text.substring(start, end);

    final replacement = '$openTag$selectedText$closeTag';
    final newText = text.replaceRange(start, end, replacement);

    _codeController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + openTag.length + selectedText.length),
    );
    setState(() {});
  }

  void _beautifyHtml() {
    final lines = _codeController.text.split('\n');
    final buffer = StringBuffer();
    int indent = 0;

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.startsWith('</') || trimmed.startsWith('}')) {
        indent = (indent - 1).clamp(0, 20);
      }

      buffer.writeln('${'  ' * indent}$trimmed');

      if ((trimmed.startsWith('<') && !trimmed.startsWith('</') && !trimmed.endsWith('/>') && !trimmed.startsWith('<!') && !trimmed.contains('</')) ||
          trimmed.endsWith('{')) {
        indent++;
      }
    }

    setState(() {
      _codeController.text = buffer.toString();
    });
  }

  Future<void> _exportHtml() async {
    try {
      final cleanName = _documentTitle.endsWith('.html') || _documentTitle.endsWith('.htm') ? _documentTitle : '$_documentTitle.html';
      final file = await FileHelper.saveDocumentText(
        content: _codeController.text,
        fileName: cleanName,
      );
      await RecentFilesService.addRecentFile(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved HTML file: ${FileHelper.getFileName(file.path)}'),
          backgroundColor: const Color(0xFF0D9488),
          action: SnackBarAction(
            label: 'Open in Browser',
            textColor: Colors.white,
            onPressed: () => FileHelper.openFile(file.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _exportPdf() async {
    try {
      final pdf = pw.Document(title: _documentTitle);
      final rawLines = _codeController.text.split('\n');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(_documentTitle, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            ),
            pw.SizedBox(height: 12),
            ...rawLines.map((l) => pw.Text(l, style: pw.TextStyle(fontSize: 9))),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      final file = await FileHelper.savePdfFile(
        bytes: pdfBytes,
        fileName: '${_documentTitle.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}_web.pdf',
      );
      await RecentFilesService.addRecentFile(file.path);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChromePdfViewerScreen(initialFilePath: file.path)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF Export error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _shareHtml() async {
    try {
      final cleanName = _documentTitle.endsWith('.html') ? _documentTitle : '$_documentTitle.html';
      final file = await FileHelper.saveDocumentText(
        content: _codeController.text,
        fileName: cleanName,
      );
      await FileHelper.shareFile(file.path, text: 'Sharing $_documentTitle');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share error: $e')));
    }
  }

  Future<void> _exportGdrm() async {
    try {
      final pdf = pw.Document(title: _documentTitle);
      final rawLines = _codeController.text.split('\n');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(_documentTitle, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            ),
            pw.SizedBox(height: 12),
            ...rawLines.map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 9))),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      if (!mounted) return;
      GdrmExportDialog.show(
        context,
        pdfBytes: pdfBytes,
        defaultFileName: _documentTitle,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('GDRM Export error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: FidgetSpinnerLoader(message: 'Loading HTML Studio...')),
      );
    }

    return PopScope(
      canPop: !widget.isExternalIntent,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.isExternalIntent) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          titleSpacing: 0,
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (widget.isExternalIntent) {
                SystemNavigator.pop();
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.html, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: _documentTitle,
                  onChanged: (val) => _documentTitle = val,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Page Title (index.html)',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save, color: Color(0xFF0EA5E9)),
              tooltip: 'Save HTML',
              onPressed: _exportHtml,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onSelected: (val) {
                if (val == 'gdrm') _exportGdrm();
                if (val == 'pdf') _exportPdf();
                if (val == 'share') _shareHtml();
              },
              itemBuilder: (ctx) => const [
                PopupMenuItem(
                  value: 'gdrm',
                  child: Row(
                    children: [
                      Icon(Icons.shield_moon_rounded, color: Color(0xFF06B6D4), size: 18),
                      SizedBox(width: 8),
                      Text('Export as .gdrm File'),
                    ],
                  ),
                ),
                PopupMenuItem(value: 'pdf', child: Text('Export Web PDF')),
                PopupMenuItem(value: 'share', child: Text('Share HTML')),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            // HTML Toolbar ribbon
            _buildHtmlRibbon(),

          // Main Workspace
          Expanded(
            child: _buildWorkspace(),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildHtmlRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // View Mode Selector
            SegmentedButton<HtmlStudioViewMode>(
              segments: const [
                ButtonSegment(value: HtmlStudioViewMode.code, label: Text('Code', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: HtmlStudioViewMode.split, label: Text('Split', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: HtmlStudioViewMode.livePreview, label: Text('Preview', style: TextStyle(fontSize: 11))),
              ],
              selected: <HtmlStudioViewMode>{_viewMode},
              onSelectionChanged: (val) => setState(() => _viewMode = val.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
            const VerticalDivider(width: 16, thickness: 1, color: Color(0xFF334155)),

            ActionChip(
              label: const Text('<h1>', style: TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: const Color(0xFF334155),
              onPressed: () => _insertTag('<h1>', '</h1>'),
            ),
            const SizedBox(width: 6),
            ActionChip(
              label: const Text('<p>', style: TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: const Color(0xFF334155),
              onPressed: () => _insertTag('<p>', '</p>'),
            ),
            const SizedBox(width: 6),
            ActionChip(
              label: const Text('<button>', style: TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: const Color(0xFF334155),
              onPressed: () => _insertTag('<button class="btn">', '</button>'),
            ),
            const SizedBox(width: 6),
            ActionChip(
              label: const Text('<card>', style: TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: const Color(0xFF334155),
              onPressed: () => _insertTag('<div class="card">\n  ', '\n</div>'),
            ),
            const SizedBox(width: 6),
            ActionChip(
              label: const Text('<ul>', style: TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: const Color(0xFF334155),
              onPressed: () => _insertTag('<ul>\n  <li>', '</li>\n</ul>'),
            ),
            const VerticalDivider(width: 16, thickness: 1, color: Color(0xFF334155)),

            // Beautifier
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_fix_high, size: 14, color: Color(0xFF38BDF8)),
              label: const Text('Format', style: TextStyle(color: Colors.white, fontSize: 11)),
              onPressed: _beautifyHtml,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF475569)),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const VerticalDivider(width: 16, thickness: 1, color: Color(0xFF334155)),

            // Viewport Switcher for Preview
            IconButton(
              icon: Icon(Icons.desktop_windows, size: 16, color: _previewWidth >= 800 ? const Color(0xFF38BDF8) : Colors.white38),
              tooltip: 'Desktop (Full)',
              onPressed: () => setState(() => _previewWidth = 800),
            ),
            IconButton(
              icon: Icon(Icons.tablet, size: 16, color: (_previewWidth >= 500 && _previewWidth < 800) ? const Color(0xFF38BDF8) : Colors.white38),
              tooltip: 'Tablet (500px)',
              onPressed: () => setState(() => _previewWidth = 500),
            ),
            IconButton(
              icon: Icon(Icons.smartphone, size: 16, color: _previewWidth < 500 ? const Color(0xFF38BDF8) : Colors.white38),
              tooltip: 'Mobile (340px)',
              onPressed: () => setState(() => _previewWidth = 340),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        if (_viewMode == HtmlStudioViewMode.code) {
          return _buildCodeEditorPane();
        } else if (_viewMode == HtmlStudioViewMode.livePreview || _viewMode == HtmlStudioViewMode.visual) {
          return _buildPreviewPane();
        } else {
          // Split mode
          if (isWide) {
            return Row(
              children: [
                Expanded(child: _buildCodeEditorPane()),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF334155)),
                Expanded(child: _buildPreviewPane()),
              ],
            );
          } else {
            // Stack vertically on narrow mobile screens
            return Column(
              children: [
                Expanded(child: _buildCodeEditorPane()),
                const Divider(height: 1, thickness: 1, color: Color(0xFF334155)),
                Expanded(child: _buildPreviewPane()),
              ],
            );
          }
        }
      },
    );
  }

  Widget _buildCodeEditorPane() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _codeController,
        maxLines: null,
        expands: true,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Color(0xFFE2E8F0),
          height: 1.5,
        ),
        decoration: const InputDecoration(
          filled: false,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildPreviewPane() {
    return Container(
      color: const Color(0xFF1E293B),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: _previewWidth,
            constraints: const BoxConstraints(minHeight: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: _buildSimulatedHtmlDom(),
          ),
        ),
      ),
    );
  }

  Widget _buildSimulatedHtmlDom() {
    final text = _codeController.text;
    final List<Widget> widgets = [];

    final h1Match = RegExp(r'<h1[^>]*>(.*?)</h1>', dotAll: true, caseSensitive: false).firstMatch(text);
    final h2Matches = RegExp(r'<h2[^>]*>(.*?)</h2>', dotAll: true, caseSensitive: false).allMatches(text);
    final pMatches = RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true, caseSensitive: false).allMatches(text);
    final liMatches = RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true, caseSensitive: false).allMatches(text);
    final btnMatches = RegExp(r'<button[^>]*>(.*?)</button>|<a[^>]*class="btn"[^>]*>(.*?)</a>', dotAll: true, caseSensitive: false).allMatches(text);

    if (text.contains('hero')) {
      widgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                h1Match?.group(1) ?? 'Zen Web Page',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              if (pMatches.isNotEmpty)
                Text(
                  pMatches.first.group(1) ?? '',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    } else if (h1Match != null) {
      widgets.add(
        Text(
          h1Match.group(1)!,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }

    for (final h2 in h2Matches) {
      widgets.add(
        Text(
          h2.group(1)!,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }

    final bodyPs = text.contains('hero') && pMatches.isNotEmpty ? pMatches.skip(1) : pMatches;
    for (final p in bodyPs) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            p.group(1)!,
            style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5),
          ),
        ),
      );
    }

    if (liMatches.isNotEmpty) {
      widgets.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: liMatches.map((li) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                    Expanded(
                      child: Text(
                        li.group(1)!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    for (final btn in btnMatches) {
      final label = btn.group(1) ?? btn.group(2) ?? 'Click Action';
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: Text(label),
          ),
        ),
      );
    }

    if (widgets.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }
}
