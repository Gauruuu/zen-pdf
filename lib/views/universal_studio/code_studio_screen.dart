import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';
import '../../core/utils/file_helper.dart';
import '../../services/recent_files_service.dart';
import '../common/fidget_spinner_loader.dart';
import '../pdf_viewer/chrome_pdf_viewer_screen.dart';
import '../gdrm/gdrm_export_dialog.dart';
import 'package:flutter/services.dart';

class CodeStudioScreen extends StatefulWidget {
  final String? initialFilePath;
  final String? initialFileName;
  final String? initialContent;
  final bool isExternalIntent;

  const CodeStudioScreen({
    super.key,
    this.initialFilePath,
    this.initialFileName,
    this.initialContent,
    this.isExternalIntent = false,
  });

  @override
  State<CodeStudioScreen> createState() => _CodeStudioScreenState();
}

class _CodeStudioScreenState extends State<CodeStudioScreen> {
  late String _fileName;
  bool _isLoading = true;
  String? _filePath;

  double _fontSize = 13.0;
  bool _isWordWrap = false;
  bool _showSearch = false;

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fileName = widget.initialFileName ?? 'script.json';
    _filePath = widget.initialFilePath;
    _initCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  Future<void> _initCode() async {
    setState(() => _isLoading = true);

    if (widget.initialContent != null) {
      _codeController.text = widget.initialContent!;
    } else if (_filePath != null && File(_filePath!).existsSync()) {
      final content = await File(_filePath!).readAsString();
      _codeController.text = content;
      _fileName = FileHelper.getFileName(_filePath!);
    } else {
      _codeController.text = '''{
  "name": "Zen Universal Studio",
  "version": "1.0.0",
  "description": "Full native document, spreadsheet, slide, and code editor",
  "capabilities": [
    "DOCX Word Processing",
    "XLSX Spreadsheets & Formulas",
    "PPTX Slide Decks",
    "Live HTML/CSS Web Studio",
    "Universal Code & Text Editing"
  ],
  "offline": true
}''';
    }

    setState(() => _isLoading = false);
  }

  void _formatCode() {
    final lower = _fileName.toLowerCase();
    final text = _codeController.text.trim();

    if (lower.endsWith('.json') || text.startsWith('{') || text.startsWith('[')) {
      try {
        final decoded = json.decode(text);
        const encoder = JsonEncoder.withIndent('  ');
        setState(() {
          _codeController.text = encoder.convert(decoded);
        });
        _showToast('JSON Formatted successfully');
        return;
      } catch (e) {
        _showToast('Invalid JSON: $e', isError: true);
      }
    }

    if (lower.endsWith('.xml') || text.startsWith('<')) {
      try {
        final doc = XmlDocument.parse(text);
        setState(() {
          _codeController.text = doc.toXmlString(pretty: true, indent: '  ');
        });
        _showToast('XML Formatted successfully');
        return;
      } catch (e) {
        _showToast('Invalid XML: $e', isError: true);
      }
    }

    _showToast('Formatting completed');
  }

  void _performReplaceAll() {
    final search = _searchController.text;
    final replace = _replaceController.text;
    if (search.isEmpty) return;

    final current = _codeController.text;
    final count = search.allMatches(current).length;
    setState(() {
      _codeController.text = current.replaceAll(search, replace);
    });
    _showToast('Replaced $count occurrences');
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFF2563EB),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveFile() async {
    try {
      final file = await FileHelper.saveDocumentText(
        content: _codeController.text,
        fileName: _fileName,
      );
      await RecentFilesService.addRecentFile(file.path);

      if (!mounted) return;
      _showToast('Saved file: ${FileHelper.getFileName(file.path)}');
    } catch (e) {
      if (!mounted) return;
      _showToast('Save error: $e', isError: true);
    }
  }

  Future<void> _exportPdf() async {
    try {
      final pdf = pw.Document(title: _fileName);
      final rawLines = _codeController.text.split('\n');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(_fileName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: List.generate(rawLines.length, (idx) {
                  return pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(
                        width: 28,
                        child: pw.Text('${idx + 1}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                      ),
                      pw.Expanded(
                        child: pw.Text(rawLines[idx], style: pw.TextStyle(fontSize: 8)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final file = await FileHelper.savePdfFile(
        bytes: bytes,
        fileName: '${_fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}_code.pdf',
      );
      await RecentFilesService.addRecentFile(file.path);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChromePdfViewerScreen(initialFilePath: file.path)),
      );
    } catch (e) {
      if (!mounted) return;
      _showToast('PDF Export error: $e', isError: true);
    }
  }

  Future<void> _shareFile() async {
    try {
      final file = await FileHelper.saveDocumentText(
        content: _codeController.text,
        fileName: _fileName,
      );
      await FileHelper.shareFile(file.path, text: 'Sharing $_fileName');
    } catch (e) {
      if (!mounted) return;
      _showToast('Share error: $e', isError: true);
    }
  }

  Future<void> _exportGdrm() async {
    try {
      final pdf = pw.Document(title: _fileName);
      final rawLines = _codeController.text.split('\n');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(_fileName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            ),
            pw.SizedBox(height: 12),
            ...rawLines.map((l) => pw.Text(l, style: const pw.TextStyle(fontSize: 8.5))),
          ],
        ),
      );

      final pdfBytes = await pdf.save();
      if (!mounted) return;
      GdrmExportDialog.show(
        context,
        pdfBytes: pdfBytes,
        defaultFileName: _fileName,
      );
    } catch (e) {
      if (!mounted) return;
      _showToast('GDRM Export error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: FidgetSpinnerLoader(message: 'Loading Code Studio...')),
      );
    }

    final lineCount = '\n'.allMatches(_codeController.text).length + 1;

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
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.code, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: _fileName,
                  onChanged: (val) => _fileName = val,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'filename.ext',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.search, color: _showSearch ? const Color(0xFF6366F1) : Colors.white70),
              tooltip: 'Search & Replace',
              onPressed: () => setState(() => _showSearch = !_showSearch),
            ),
            IconButton(
              icon: const Icon(Icons.auto_fix_high, color: Color(0xFF38BDF8)),
              tooltip: 'Format / Prettify (JSON/XML)',
              onPressed: _formatCode,
            ),
            IconButton(
              icon: const Icon(Icons.save, color: Color(0xFF6366F1)),
              tooltip: 'Save File',
              onPressed: _saveFile,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onSelected: (val) {
                if (val == 'gdrm') _exportGdrm();
                if (val == 'pdf') _exportPdf();
                if (val == 'share') _shareFile();
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
                PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
                PopupMenuItem(value: 'share', child: Text('Share File')),
              ],
            ),
          ],
        ),
        body: Column(
        children: [
          // Search & Replace Bar if opened
          if (_showSearch) _buildSearchBar(),

          // Toolbar / Gutter status (wrapped in SingleChildScrollView to prevent overflow)
          _buildStatusBar(lineCount),

          // Code Editor Area with Line Numbers
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Line numbers column
                Container(
                  width: 48,
                  color: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(lineCount, (idx) {
                        return Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: _fontSize,
                            color: const Color(0xFF64748B),
                            height: 1.5,
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF334155)),

                // Code input field
                Expanded(
                  child: Container(
                    color: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: TextField(
                      controller: _codeController,
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: _fontSize,
                        color: const Color(0xFFF1F5F9),
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 160,
              height: 32,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              height: 32,
              child: TextField(
                controller: _replaceController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Replace with...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _performReplaceAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Replace All'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(int lineCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$lineCount lines | ${_codeController.text.length} chars',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
            const SizedBox(width: 12),
            ActionChip(
              label: Text('Wrap: ${_isWordWrap ? "ON" : "OFF"}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              backgroundColor: const Color(0xFF334155),
              onPressed: () => setState(() => _isWordWrap = !_isWordWrap),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.zoom_out, size: 18, color: Colors.white70),
              tooltip: 'Zoom Out',
              onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(10.0, 24.0)),
            ),
            Text('${_fontSize.toInt()}pt', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 18, color: Colors.white70),
              tooltip: 'Zoom In',
              onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(10.0, 24.0)),
            ),
          ],
        ),
      ),
    );
  }
}
