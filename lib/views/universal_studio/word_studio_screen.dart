import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/utils/file_helper.dart';
import '../../models/universal_document_model.dart';
import '../../services/docx_engine_service.dart';
import '../../services/recent_files_service.dart';
import '../common/fidget_spinner_loader.dart';
import '../pdf_viewer/chrome_pdf_viewer_screen.dart';
import '../gdrm/gdrm_export_dialog.dart';
import 'package:flutter/services.dart';

class WordStudioScreen extends StatefulWidget {
  final String? initialFilePath;
  final String? initialDocTitle;
  final List<DocParagraph>? initialParagraphs;
  final bool isExternalIntent;

  const WordStudioScreen({
    super.key,
    this.initialFilePath,
    this.initialDocTitle,
    this.initialParagraphs,
    this.isExternalIntent = false,
  });

  @override
  State<WordStudioScreen> createState() => _WordStudioScreenState();
}

class _WordStudioScreenState extends State<WordStudioScreen> {
  late String _docTitle;
  List<DocParagraph> _paragraphs = [];
  bool _isLoading = true;
  String? _filePath;

  int _selectedBlockIndex = 0;
  bool _isBold = false;
  bool _isItalic = false;
  DocParagraphAlign _activeAlign = DocParagraphAlign.left;
  DocBlockType _activeBlockType = DocBlockType.body;

  final List<TextEditingController> _controllers = [];

  @override
  void initState() {
    super.initState();
    _docTitle = widget.initialDocTitle ?? 'Untitled Document';
    _filePath = widget.initialFilePath;
    _initDocument();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initDocument() async {
    setState(() => _isLoading = true);

    if (widget.initialParagraphs != null && widget.initialParagraphs!.isNotEmpty) {
      _paragraphs = List.from(widget.initialParagraphs!);
    } else if (_filePath != null && File(_filePath!).existsSync()) {
      final bytes = await File(_filePath!).readAsBytes();
      _paragraphs = DocxEngineService.parseDocx(bytes);
      _docTitle = FileHelper.getFileName(_filePath!).replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    } else {
      _paragraphs = [
        DocParagraph(
          id: 'p_1',
          type: DocBlockType.heading1,
          runs: [TextRun(text: 'Welcome to Zen Word Studio', isBold: true, fontSize: 24)],
        ),
        DocParagraph(
          id: 'p_2',
          type: DocBlockType.body,
          runs: [
            TextRun(
              text: 'This is a rich visual document processor. You can write headings, body paragraphs, bullet points, format text styles, and export directly to Microsoft Word (.docx) or PDF.',
              fontSize: 14,
            )
          ],
        ),
        DocParagraph(
          id: 'p_3',
          type: DocBlockType.bullet,
          runs: [TextRun(text: 'Real-time rich text styling and paragraph blocks', fontSize: 14)],
        ),
        DocParagraph(
          id: 'p_4',
          type: DocBlockType.bullet,
          runs: [TextRun(text: 'Native Microsoft Word (.docx) zip packaging', fontSize: 14)],
        ),
        DocParagraph(
          id: 'p_5',
          type: DocBlockType.quote,
          runs: [TextRun(text: 'Clean, distraction-free document creation with offline speed.', isItalic: true, fontSize: 14)],
        ),
      ];
    }

    _syncControllers();
    setState(() => _isLoading = false);
  }

  void _syncControllers() {
    for (final c in _controllers) {
      c.dispose();
    }
    _controllers.clear();

    for (int i = 0; i < _paragraphs.length; i++) {
      final p = _paragraphs[i];
      final c = TextEditingController(text: p.plainText);
      c.addListener(() {
        if (p.runs.isEmpty) {
          p.runs.add(TextRun(text: c.text));
        } else {
          p.runs[0].text = c.text;
        }
      });
      _controllers.add(c);
    }
  }

  void _addParagraph({DocBlockType type = DocBlockType.body, int? afterIndex}) {
    final newP = DocParagraph(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      runs: [TextRun(text: '')],
    );

    final insertIdx = (afterIndex != null ? afterIndex + 1 : _paragraphs.length).clamp(0, _paragraphs.length);
    setState(() {
      _paragraphs.insert(insertIdx, newP);
      _selectedBlockIndex = insertIdx;
      _syncControllers();
    });
  }

  void _deleteParagraph(int index) {
    if (_paragraphs.length <= 1) return;
    setState(() {
      _paragraphs.removeAt(index);
      if (_selectedBlockIndex >= _paragraphs.length) {
        _selectedBlockIndex = _paragraphs.length - 1;
      }
      _syncControllers();
    });
  }

  void _updateActiveBlockType(DocBlockType newType) {
    if (_selectedBlockIndex < 0 || _selectedBlockIndex >= _paragraphs.length) return;
    setState(() {
      _paragraphs[_selectedBlockIndex].type = newType;
      _activeBlockType = newType;
    });
  }

  void _updateActiveAlignment(DocParagraphAlign align) {
    if (_selectedBlockIndex < 0 || _selectedBlockIndex >= _paragraphs.length) return;
    setState(() {
      _paragraphs[_selectedBlockIndex].align = align;
      _activeAlign = align;
    });
  }

  void _toggleBold() {
    if (_selectedBlockIndex < 0 || _selectedBlockIndex >= _paragraphs.length) return;
    setState(() {
      _isBold = !_isBold;
      final p = _paragraphs[_selectedBlockIndex];
      for (final r in p.runs) {
        r.isBold = _isBold;
      }
    });
  }

  void _toggleItalic() {
    if (_selectedBlockIndex < 0 || _selectedBlockIndex >= _paragraphs.length) return;
    setState(() {
      _isItalic = !_isItalic;
      final p = _paragraphs[_selectedBlockIndex];
      for (final r in p.runs) {
        r.isItalic = _isItalic;
      }
    });
  }

  int get _wordCount {
    int count = 0;
    for (final p in _paragraphs) {
      final words = p.plainText.trim().split(RegExp(r'\s+'));
      if (words.length == 1 && words.first.isEmpty) continue;
      count += words.length;
    }
    return count;
  }

  int get _charCount {
    int count = 0;
    for (final p in _paragraphs) {
      count += p.plainText.length;
    }
    return count;
  }

  Future<void> _exportDocx() async {
    try {
      final docxBytes = DocxEngineService.exportToDocx(_paragraphs, title: _docTitle);
      final cleanName = _docTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = await FileHelper.saveDocumentFile(
        bytes: docxBytes,
        fileName: '$cleanName.docx',
      );
      await RecentFilesService.addRecentFile(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved Word document: ${FileHelper.getFileName(file.path)}'),
          backgroundColor: const Color(0xFF2563EB),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => FileHelper.openFile(file.path),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save Word doc: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportPdf() async {
    try {
      final pdfBytes = await DocxEngineService.exportToPdf(_paragraphs, title: _docTitle);
      final cleanName = _docTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = await FileHelper.savePdfFile(
        bytes: pdfBytes,
        fileName: '$cleanName.pdf',
      );
      await RecentFilesService.addRecentFile(file.path);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChromePdfViewerScreen(initialFilePath: file.path)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _shareFile() async {
    try {
      final docxBytes = DocxEngineService.exportToDocx(_paragraphs, title: _docTitle);
      final cleanName = _docTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = await FileHelper.saveDocumentFile(
        bytes: docxBytes,
        fileName: '$cleanName.docx',
      );
      await FileHelper.shareFile(file.path, text: 'Sharing $_docTitle');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  Future<void> _exportGdrm() async {
    try {
      final pdfBytes = await DocxEngineService.exportToPdf(_paragraphs, title: _docTitle);
      if (!mounted) return;
      GdrmExportDialog.show(
        context,
        pdfBytes: pdfBytes,
        defaultFileName: _docTitle,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to prepare GDRM: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: FidgetSpinnerLoader(message: 'Loading Document...')),
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
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          titleSpacing: 0,
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
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
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.description, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: _docTitle,
                  onChanged: (val) => _docTitle = val,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Document Title',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save, color: Color(0xFF2563EB)),
              tooltip: 'Save as Word (.docx)',
              onPressed: _exportDocx,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
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
                PopupMenuItem(value: 'share', child: Text('Share Document')),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            // Formatting Ribbon / Toolbar
            _buildFormattingRibbon(),

          // Document Workspace Canvas
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document Header Banner
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _docTitle.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            '$_wordCount words  |  $_charCount chars',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const Divider(height: 24, thickness: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 8),

                      // Paragraph Blocks
                      ...List.generate(_paragraphs.length, (index) {
                        return _buildParagraphRow(index);
                      }),

                      const SizedBox(height: 16),
                      // Add block button
                      OutlinedButton.icon(
                        onPressed: () => _addParagraph(afterIndex: _paragraphs.length - 1),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Paragraph / Block'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildFormattingRibbon() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Block Type Dropdown
            DropdownButton<DocBlockType>(
              value: _activeBlockType,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: DocBlockType.heading1, child: Text('Heading 1', style: TextStyle(fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: DocBlockType.heading2, child: Text('Heading 2', style: TextStyle(fontWeight: FontWeight.bold))),
                DropdownMenuItem(value: DocBlockType.heading3, child: Text('Heading 3')),
                DropdownMenuItem(value: DocBlockType.body, child: Text('Normal Body')),
                DropdownMenuItem(value: DocBlockType.bullet, child: Text('Bullet Point')),
                DropdownMenuItem(value: DocBlockType.quote, child: Text('Quote Block')),
                DropdownMenuItem(value: DocBlockType.code, child: Text('Code Snippet')),
              ],
              onChanged: (val) {
                if (val != null) _updateActiveBlockType(val);
              },
            ),
            const VerticalDivider(width: 20, thickness: 1, color: Color(0xFFE2E8F0)),

            // Bold & Italic
            IconButton(
              icon: Icon(Icons.format_bold, color: _isBold ? const Color(0xFF2563EB) : Colors.black87),
              tooltip: 'Bold',
              onPressed: _toggleBold,
            ),
            IconButton(
              icon: Icon(Icons.format_italic, color: _isItalic ? const Color(0xFF2563EB) : Colors.black87),
              tooltip: 'Italic',
              onPressed: _toggleItalic,
            ),
            const VerticalDivider(width: 20, thickness: 1, color: Color(0xFFE2E8F0)),

            // Alignments
            IconButton(
              icon: Icon(Icons.format_align_left, color: _activeAlign == DocParagraphAlign.left ? const Color(0xFF2563EB) : Colors.black54),
              tooltip: 'Align Left',
              onPressed: () => _updateActiveAlignment(DocParagraphAlign.left),
            ),
            IconButton(
              icon: Icon(Icons.format_align_center, color: _activeAlign == DocParagraphAlign.center ? const Color(0xFF2563EB) : Colors.black54),
              tooltip: 'Align Center',
              onPressed: () => _updateActiveAlignment(DocParagraphAlign.center),
            ),
            IconButton(
              icon: Icon(Icons.format_align_right, color: _activeAlign == DocParagraphAlign.right ? const Color(0xFF2563EB) : Colors.black54),
              tooltip: 'Align Right',
              onPressed: () => _updateActiveAlignment(DocParagraphAlign.right),
            ),
            IconButton(
              icon: Icon(Icons.format_align_justify, color: _activeAlign == DocParagraphAlign.justify ? const Color(0xFF2563EB) : Colors.black54),
              tooltip: 'Justify',
              onPressed: () => _updateActiveAlignment(DocParagraphAlign.justify),
            ),
            const VerticalDivider(width: 20, thickness: 1, color: Color(0xFFE2E8F0)),

            // Quick block inserters
            ActionChip(
              avatar: const Icon(Icons.format_list_bulleted, size: 14),
              label: const Text('Bullet'),
              onPressed: () => _addParagraph(type: DocBlockType.bullet, afterIndex: _selectedBlockIndex),
            ),
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.format_quote, size: 14),
              label: const Text('Quote'),
              onPressed: () => _addParagraph(type: DocBlockType.quote, afterIndex: _selectedBlockIndex),
            ),
            const SizedBox(width: 6),
            ActionChip(
              avatar: const Icon(Icons.code, size: 14),
              label: const Text('Code'),
              onPressed: () => _addParagraph(type: DocBlockType.code, afterIndex: _selectedBlockIndex),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParagraphRow(int index) {
    final p = _paragraphs[index];
    final isSelected = index == _selectedBlockIndex;
    final controller = _controllers[index];

    TextStyle style;
    TextAlign align = TextAlign.left;
    if (p.align == DocParagraphAlign.center) align = TextAlign.center;
    if (p.align == DocParagraphAlign.right) align = TextAlign.right;
    if (p.align == DocParagraphAlign.justify) align = TextAlign.justify;

    switch (p.type) {
      case DocBlockType.heading1:
        style = const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.4);
        break;
      case DocBlockType.heading2:
        style = const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), height: 1.4);
        break;
      case DocBlockType.heading3:
        style = const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF334155), height: 1.4);
        break;
      case DocBlockType.quote:
        style = const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF475569), height: 1.5);
        break;
      case DocBlockType.code:
        style = const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFF0F172A));
        break;
      case DocBlockType.bullet:
      case DocBlockType.numbered:
      case DocBlockType.body:
        style = TextStyle(
          fontSize: 14,
          fontWeight: p.runs.any((r) => r.isBold) ? FontWeight.bold : FontWeight.normal,
          fontStyle: p.runs.any((r) => r.isItalic) ? FontStyle.italic : FontStyle.normal,
          color: const Color(0xFF1E293B),
          height: 1.6,
        );
    }

    Widget contentField = TextField(
      controller: controller,
      textAlign: align,
      style: style,
      maxLines: null,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        border: InputBorder.none,
        hintText: p.type == DocBlockType.heading1 ? 'Heading 1...' : 'Type text here...',
        hintStyle: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.normal),
      ),
      onTap: () {
        setState(() {
          _selectedBlockIndex = index;
          _activeBlockType = p.type;
          _activeAlign = p.align;
        });
      },
    );

    if (p.type == DocBlockType.bullet) {
      contentField = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 10, left: 4),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(child: contentField),
        ],
      );
    } else if (p.type == DocBlockType.quote) {
      contentField = Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFF2563EB), width: 3)),
        ),
        child: contentField,
      );
    } else if (p.type == DocBlockType.code) {
      contentField = Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: contentField,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: isSelected ? Border.all(color: const Color(0xFF93C5FD).withValues(alpha: 0.5), width: 1) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: contentField),
          if (isSelected && _paragraphs.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
              tooltip: 'Delete Block',
              onPressed: () => _deleteParagraph(index),
            ),
        ],
      ),
    );
  }
}
