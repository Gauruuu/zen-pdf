import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/file_helper.dart';
import '../../services/pdf_security_service.dart';
import '../pdf_editor/widgets/password_prompt_dialog.dart';
import '../pdf_editor/pdf_editor_screen.dart';
import '../document_converter/document_converter_screen.dart';
import '../common/fidget_spinner_loader.dart';

class ChromePdfViewerScreen extends StatefulWidget {
  final String? initialFilePath;
  final Uint8List? initialBytes;
  final String? initialFileName;

  const ChromePdfViewerScreen({
    super.key,
    this.initialFilePath,
    this.initialBytes,
    this.initialFileName,
  });

  @override
  State<ChromePdfViewerScreen> createState() => _ChromePdfViewerScreenState();
}

class _ChromePdfViewerScreenState extends State<ChromePdfViewerScreen> {
  String? _filePath;
  String? _fileName;
  Uint8List? _pdfBytes;
  bool _isLoading = false;
  int _currentPage = 1;
  int _totalPages = 0;
  double _zoomLevel = 1.0;
  bool _showThumbnails = false;
  late final PdfViewerController _pdfViewerController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _pdfViewerController.addListener(_onViewerControllerUpdate);
    if (widget.initialBytes != null) {
      _loadPdfFromBytes(widget.initialBytes!, widget.initialFileName ?? 'Document.pdf');
    } else if (widget.initialFilePath != null) {
      _loadPdfFromFile(widget.initialFilePath!);
    }
  }

  void _onViewerControllerUpdate() {
    if (_pdfViewerController.isReady && mounted) {
      final page = _pdfViewerController.pageNumber ?? 1;
      final count = _pdfViewerController.pageCount;
      final zoom = _pdfViewerController.currentZoom;
      if (page != _currentPage || count != _totalPages || (zoom - _zoomLevel).abs() > 0.05) {
        setState(() {
          _currentPage = page;
          _totalPages = count;
          _zoomLevel = zoom;
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfViewerController.removeListener(_onViewerControllerUpdate);
    super.dispose();
  }

  Future<void> _pickAndOpenPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      await _loadPdfFromFile(result.files.single.path!);
    }
  }

  Future<void> _loadPdfFromFile(String path) async {
    setState(() {
      _isLoading = true;
      _filePath = path;
      _fileName = p.basename(path);
    });

    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      await _loadPdfFromBytes(bytes, _fileName!);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading PDF: ')),
        );
      }
    }
  }

  Future<void> _loadPdfFromBytes(Uint8List bytes, String name) async {
    setState(() {
      _isLoading = true;
      _fileName = name;
    });

    Uint8List workingBytes = bytes;

    if (PdfSecurityService.isPdfEncrypted(workingBytes)) {
      final password = await PasswordPromptDialog.show(context, fileName: name);
      if (password == null) {
        setState(() => _isLoading = false);
        return;
      }
      try {
        workingBytes = await PdfSecurityService.unlockPdf(inputBytes: workingBytes, password: password);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _pdfBytes = workingBytes;
        _isLoading = false;
        _zoomLevel = 1.0;
      });
    }
  }

  void _zoomIn() {
    final current = _pdfViewerController.currentZoom;
    double target = current;
    if (current < 2.0) {
      target += 0.25;
    } else if (current < 5.0) {
      target += 0.5;
    } else {
      target += 1.5;
    }
    target = target.clamp(0.1, 50.0);
    _pdfViewerController.setZoom(
      _pdfViewerController.centerPosition,
      target,
    );
    setState(() => _zoomLevel = target);
  }

  void _zoomOut() {
    final current = _pdfViewerController.currentZoom;
    double target = current;
    if (current > 5.0) {
      target -= 1.5;
    } else if (current > 2.0) {
      target -= 0.5;
    } else {
      target -= 0.25;
    }
    target = target.clamp(0.1, 50.0);
    _pdfViewerController.setZoom(
      _pdfViewerController.centerPosition,
      target,
    );
    setState(() => _zoomLevel = target);
  }

  void _resetZoom() {
    _pdfViewerController.setZoom(
      _pdfViewerController.centerPosition,
      1.0,
    );
    setState(() => _zoomLevel = 1.0);
  }

  void _jumpToPageDialog() async {
    final controller = TextEditingController(text: '');
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Page Number (1 - )',
            hintText: 'Enter page number',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, page);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );

    if (target != null && target >= 1 && target <= _totalPages) {
      _pdfViewerController.goToPage(pageNumber: target);
      setState(() => _currentPage = target);
    }
  }

  Future<void> _printDocument() async {
    if (_pdfBytes == null) return;
    await Printing.layoutPdf(
      onLayout: (_) async => _pdfBytes!,
      name: _fileName ?? 'Document.pdf',
    );
  }

  Future<void> _downloadOrShare() async {
    if (_pdfBytes == null) return;
    final saved = await FileHelper.savePdfFile(
      bytes: _pdfBytes!,
      fileName: _fileName ?? 'Document.pdf',
    );
    await FileHelper.shareFile(saved.path);
  }

  void _convertToOtherFormats() {
    if (_filePath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentConverterScreen(
            initialFilePath: _filePath,
            initialMode: ConverterMode.pdfToAny,
          ),
        ),
      );
    }
  }

  void _editInZenPdf() {
    if (_filePath != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfEditorScreen(initialFilePath: _filePath),
        ),
      );
    } else if (_pdfBytes != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PdfEditorScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF323639), // Authentic Chrome PDF background
      body: SafeArea(
        child: Column(
          children: [
            _buildChromeAppBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: FidgetSpinnerLoader(
                        size: 64,
                        primaryColor: Color(0xFF8AB4F8),
                        message: 'Opening PDF...',
                      ),
                    )
                  : _pdfBytes == null
                      ? _buildEmptyState()
                      : Row(
                          children: [
                            if (_showThumbnails) _buildThumbnailsSidebar(),
                            Expanded(child: _buildPdfrxViewer()),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChromeAppBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 650;
        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: const BoxDecoration(
            color: Color(0xFF202124), // Chrome Top Bar
            border: Border(bottom: BorderSide(color: Color(0xFF3C4043), width: 1)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 20),
                tooltip: 'Back',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.maybePop(context),
              ),
              IconButton(
                icon: Icon(
                  _showThumbnails ? Icons.view_sidebar : Icons.view_sidebar_outlined,
                  color: _showThumbnails ? const Color(0xFF8AB4F8) : Colors.white70,
                  size: 20,
                ),
                tooltip: 'Toggle Thumbnails Panel',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _showThumbnails = !_showThumbnails),
              ),
              const SizedBox(width: 6),

              // File Title
              Expanded(
                child: Text(
                  _fileName ?? 'Zen PDF Viewer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if (_pdfBytes != null) ...[
                // Page Indicator: [ 1 ] / N (Clickable jump)
                InkWell(
                  onTap: _jumpToPageDialog,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3C4043),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          ' / ',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                if (isWide) ...[
                  _buildDivider(),

                  // Zoom Controls
                  IconButton(
                    icon: const Icon(Icons.remove, color: Colors.white70, size: 18),
                    tooltip: 'Zoom Out',
                    onPressed: _zoomOut,
                  ),
                  InkWell(
                    onTap: _resetZoom,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(
                        '%',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white70, size: 18),
                    tooltip: 'Zoom In',
                    onPressed: _zoomIn,
                  ),

                  _buildDivider(),

                  // Print
                  IconButton(
                    icon: const Icon(Icons.print, color: Colors.white70, size: 20),
                    tooltip: 'Print Document',
                    onPressed: _printDocument,
                  ),

                  // Convert / Export to Word, PPT, Excel, etc.
                  IconButton(
                    icon: const Icon(Icons.transform, color: Color(0xFF38BDF8), size: 20),
                    tooltip: 'Convert PDF to Word, PPT, Excel, Text...',
                    onPressed: _convertToOtherFormats,
                  ),

                  // Download / Share
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white70, size: 20),
                    tooltip: 'Download / Share',
                    onPressed: _downloadOrShare,
                  ),

                  const SizedBox(width: 4),

                  // Quick Jump to Studio Editor
                  ElevatedButton.icon(
                    onPressed: _editInZenPdf,
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text('Edit in Zen PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                ] else ...[
                  // Mobile compact action icons
                  IconButton(
                    icon: const Icon(Icons.transform, color: Color(0xFF38BDF8), size: 20),
                    tooltip: 'Convert PDF',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: _convertToOtherFormats,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Color(0xFF8AB4F8), size: 22),
                    tooltip: 'Edit in Zen PDF',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    onPressed: _editInZenPdf,
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    color: const Color(0xFF2D3033),
                    onSelected: (val) {
                      switch (val) {
                        case 'convert':
                          _convertToOtherFormats();
                          break;
                        case 'share':
                          _downloadOrShare();
                          break;
                        case 'print':
                          _printDocument();
                          break;
                        case 'zoom_in':
                          _zoomIn();
                          break;
                        case 'zoom_out':
                          _zoomOut();
                          break;
                        case 'reset_zoom':
                          _resetZoom();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'convert',
                        child: Row(
                          children: [
                            Icon(Icons.transform, color: Color(0xFF38BDF8), size: 18),
                            SizedBox(width: 10),
                            Text('Convert to Word/Excel/PPT', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, color: Colors.white70, size: 18),
                            SizedBox(width: 10),
                            Text('Share / Save', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'print',
                        child: Row(
                          children: [
                            Icon(Icons.print, color: Colors.white70, size: 18),
                            SizedBox(width: 10),
                            Text('Print Document', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 1),
                      PopupMenuItem(
                        value: 'reset_zoom',
                        child: Row(
                          children: [
                            const Icon(Icons.zoom_in, color: Colors.white70, size: 18),
                            const SizedBox(width: 10),
                            Text('Reset Zoom (100%)', style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ] else
                ElevatedButton.icon(
                  onPressed: _pickAndOpenPdf,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Open'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 20,
      color: const Color(0xFF3C4043),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildThumbnailsSidebar() {
    return Container(
      width: 130,
      decoration: const BoxDecoration(
        color: Color(0xFF282A2D),
        border: Border(right: BorderSide(color: Color(0xFF3C4043), width: 1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            alignment: Alignment.centerLeft,
            child: const Text(
              'PAGES',
              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: _totalPages > 0 ? _totalPages : 1,
              itemBuilder: (context, index) {
                final pageNum = index + 1;
                final isSelected = pageNum == _currentPage;
                return GestureDetector(
                  onTap: () {
                    _pdfViewerController.goToPage(pageNumber: pageNum);
                    setState(() => _currentPage = pageNum);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF3C4043) : const Color(0xFF202124),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF8AB4F8) : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.description, color: Colors.white70, size: 36),
                        const SizedBox(height: 4),
                        Text(
                          'Page ',
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF8AB4F8) : Colors.white60,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfrxViewer() {
    return PdfViewer.data(
      _pdfBytes!,
      sourceName: _fileName ?? 'Document.pdf',
      controller: _pdfViewerController,
      params: PdfViewerParams(
        margin: 16,
        backgroundColor: const Color(0xFF323639),
        maxScale: 50.0,
        minScale: 0.1,
        enableTextSelection: false,
        viewerOverlayBuilder: (context, size, handleLinkTap) => [
          PdfViewerScrollThumb(
            controller: _pdfViewerController,
            orientation: ScrollbarOrientation.right,
            thumbSize: const Size(28, 48),
            margin: 4,
            thumbBuilder: (context, thumbSize, pageNumber, controller) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pageNumber != null && _totalPages > 1)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      'Page  / ',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                Container(
                  width: 24,
                  height: thumbSize.height,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A73E8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.unfold_more, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
        onViewerReady: (document, controller) {
          if (mounted) {
            setState(() {
              _totalPages = document.pages.length;
              _currentPage = controller.pageNumber ?? 1;
            });
          }
        },
        onPageChanged: (pageNumber) {
          if (mounted && pageNumber != null) {
            setState(() {
              _currentPage = pageNumber;
            });
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF3C4043),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.picture_as_pdf, color: Color(0xFF8AB4F8), size: 64),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chrome-Style PDF Viewer',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ultra-fast, butter-smooth 120 FPS PDF viewing powered by pdfrx',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickAndOpenPdf,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose PDF to View'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A73E8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
