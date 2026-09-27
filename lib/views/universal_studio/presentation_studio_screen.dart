import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/file_helper.dart';
import '../../models/universal_document_model.dart';
import '../../services/pptx_engine_service.dart';
import '../../services/recent_files_service.dart';
import '../common/fidget_spinner_loader.dart';
import '../pdf_viewer/chrome_pdf_viewer_screen.dart';
import '../gdrm/gdrm_export_dialog.dart';

class PresentationStudioScreen extends StatefulWidget {
  final String? initialFilePath;
  final String? initialDeckTitle;
  final List<PresentationSlide>? initialSlides;
  final bool isExternalIntent;

  const PresentationStudioScreen({
    super.key,
    this.initialFilePath,
    this.initialDeckTitle,
    this.initialSlides,
    this.isExternalIntent = false,
  });

  @override
  State<PresentationStudioScreen> createState() => _PresentationStudioScreenState();
}

class _PresentationStudioScreenState extends State<PresentationStudioScreen> {
  late String _deckTitle;
  List<PresentationSlide> _slides = [];
  bool _isLoading = true;
  String? _filePath;

  int _currentSlideIndex = 0;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _footerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _deckTitle = widget.initialDeckTitle ?? 'Untitled Deck';
    _filePath = widget.initialFilePath;
    _initPresentation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _initPresentation() async {
    setState(() => _isLoading = true);

    if (widget.initialSlides != null && widget.initialSlides!.isNotEmpty) {
      _slides = List.from(widget.initialSlides!);
    } else if (_filePath != null && File(_filePath!).existsSync()) {
      final bytes = await File(_filePath!).readAsBytes();
      _deckTitle = FileHelper.getFileName(_filePath!).replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      _slides = PptxEngineService.parsePptx(bytes, title: _deckTitle);
    } else {
      _slides = [
        PresentationSlide(
          id: 's_1',
          title: 'Zen Presentation Studio',
          subtitle: 'Create, edit and present stunning slide decks offline',
          layout: SlideLayout.titleSlide,
          backgroundColor: const Color(0xFF0F172A),
          accentColor: const Color(0xFF38BDF8),
        ),
        PresentationSlide(
          id: 's_2',
          title: 'Key Capabilities & Features',
          subtitle: 'Everything you need in a modern slide deck',
          layout: SlideLayout.titleAndContent,
          backgroundColor: const Color(0xFF1E293B),
          accentColor: const Color(0xFF818CF8),
          bullets: [
            'Live slide editing with title, subtitle, and bullet points',
            'Full-screen slideshow presentation mode',
            'Export to crisp landscape PDF presentation',
            'Multiple layouts: Title, 2-Column, Highlights',
          ],
        ),
      ];
    }

    _syncActiveSlideControllers();
    setState(() => _isLoading = false);
  }

  void _syncActiveSlideControllers() {
    if (_slides.isEmpty) return;
    final active = _slides[_currentSlideIndex];
    _titleController.text = active.title;
    _subtitleController.text = active.subtitle;
    _footerController.text = active.footerText;
  }

  void _selectSlide(int index) {
    setState(() {
      _currentSlideIndex = index;
      _syncActiveSlideControllers();
    });
  }

  void _addNewSlide() {
    final newSlide = PresentationSlide(
      id: 's_${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Slide ${_slides.length + 1}',
      subtitle: 'Slide Description',
      layout: SlideLayout.titleAndContent,
      backgroundColor: const Color(0xFF0F172A),
      accentColor: const Color(0xFF38BDF8),
      bullets: ['Enter key takeaway or point here'],
    );

    setState(() {
      _slides.add(newSlide);
      _currentSlideIndex = _slides.length - 1;
      _syncActiveSlideControllers();
    });
  }

  void _deleteCurrentSlide() {
    if (_slides.length <= 1) return;
    setState(() {
      _slides.removeAt(_currentSlideIndex);
      if (_currentSlideIndex >= _slides.length) {
        _currentSlideIndex = _slides.length - 1;
      }
      _syncActiveSlideControllers();
    });
  }

  void _addBulletPoint() {
    final active = _slides[_currentSlideIndex];
    setState(() {
      active.bullets.add('New key point');
    });
  }

  void _removeBulletPoint(int index) {
    final active = _slides[_currentSlideIndex];
    if (active.bullets.isEmpty) return;
    setState(() {
      active.bullets.removeAt(index);
    });
  }

  void _updateBulletPoint(int index, String text) {
    final active = _slides[_currentSlideIndex];
    if (index >= 0 && index < active.bullets.length) {
      active.bullets[index] = text;
    }
  }

  void _startFullscreenPresentation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenPresentationViewer(
          slides: _slides,
          deckTitle: _deckTitle,
          initialIndex: _currentSlideIndex,
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    try {
      final pdfBytes = await PptxEngineService.exportToPdf(_slides, title: _deckTitle);
      final cleanName = _deckTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
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
        SnackBar(content: Text('Failed to export slides: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _shareDeck() async {
    try {
      final pdfBytes = await PptxEngineService.exportToPdf(_slides, title: _deckTitle);
      final cleanName = _deckTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = await FileHelper.savePdfFile(
        bytes: pdfBytes,
        fileName: '$cleanName.pdf',
      );
      await FileHelper.shareFile(file.path, text: 'Sharing presentation $_deckTitle');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  Future<void> _exportGdrm() async {
    try {
      final pdfBytes = await PptxEngineService.exportToPdf(_slides, title: _deckTitle);
      if (!mounted) return;
      GdrmExportDialog.show(
        context,
        pdfBytes: pdfBytes,
        defaultFileName: _deckTitle,
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
        body: Center(child: FidgetSpinnerLoader(message: 'Loading Presentation...')),
      );
    }

    final activeSlide = _slides[_currentSlideIndex];

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
                  color: const Color(0xFFF97316),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.slideshow, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: _deckTitle,
                  onChanged: (val) => _deckTitle = val,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Deck Title',
                    hintStyle: TextStyle(color: Colors.white38),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: _startFullscreenPresentation,
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Present'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onSelected: (val) {
                if (val == 'gdrm') _exportGdrm();
                if (val == 'pdf') _exportPdf();
                if (val == 'share') _shareDeck();
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
                PopupMenuItem(value: 'pdf', child: Text('Export PDF Slides')),
                PopupMenuItem(value: 'share', child: Text('Share Presentation')),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          if (isWide) {
            return Row(
              children: [
                _buildThumbnailDrawer(isVertical: true),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF334155)),
                Expanded(
                  child: Column(
                    children: [
                      _buildSlideToolRibbon(activeSlide),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildSlideCanvas(activeSlide),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            // Mobile layout: horizontal slide strip at top + responsive canvas
            return Column(
              children: [
                _buildSlideToolRibbon(activeSlide),
                _buildThumbnailDrawer(isVertical: false),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                     child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildSlideCanvas(activeSlide),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    ),
  );
}

  Widget _buildThumbnailDrawer({required bool isVertical}) {
    if (isVertical) {
      return Container(
        width: 170,
        color: const Color(0xFF1E293B),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Slides', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF38BDF8), size: 22),
                    tooltip: 'Add Slide',
                    onPressed: _addNewSlide,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF334155)),
            Expanded(
              child: ListView.builder(
                itemCount: _slides.length,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                itemBuilder: (context, index) => _buildThumbnailCard(index),
              ),
            ),
          ],
        ),
      );
    } else {
      // Horizontal slide strip
      return Container(
        height: 64,
        color: const Color(0xFF1E293B),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF38BDF8), size: 24),
              tooltip: 'Add Slide',
              onPressed: _addNewSlide,
            ),
            const VerticalDivider(width: 8, color: Color(0xFF334155)),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final isSelected = index == _currentSlideIndex;
                  return GestureDetector(
                    onTap: () => _selectSlide(index),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _slides[index].backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        '${index + 1}. ${_slides[index].title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
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
  }

  Widget _buildThumbnailCard(int index) {
    final slide = _slides[index];
    final isSelected = index == _currentSlideIndex;

    return GestureDetector(
      onTap: () => _selectSlide(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: slide.backgroundColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: slide.accentColor, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              slide.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlideToolRibbon(PresentationSlide activeSlide) {
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
            // Layout Selector
            DropdownButton<SlideLayout>(
              value: activeSlide.layout,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: SlideLayout.titleSlide, child: Text('Title Layout')),
                DropdownMenuItem(value: SlideLayout.titleAndContent, child: Text('Title & Content')),
                DropdownMenuItem(value: SlideLayout.twoColumns, child: Text('Two Columns')),
              ],
              onChanged: (layout) {
                if (layout != null) {
                  setState(() => activeSlide.layout = layout);
                }
              },
            ),
            const VerticalDivider(width: 20, thickness: 1, color: Color(0xFF334155)),

            // Accent Color Choosers
            const Text('Accent:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 6),
            _buildColorDot(activeSlide, const Color(0xFF38BDF8)),
            _buildColorDot(activeSlide, const Color(0xFF818CF8)),
            _buildColorDot(activeSlide, const Color(0xFF34D399)),
            _buildColorDot(activeSlide, const Color(0xFFF472B6)),
            _buildColorDot(activeSlide, const Color(0xFFFBBF24)),
            const VerticalDivider(width: 20, thickness: 1, color: Color(0xFF334155)),

            // Add bullet
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 14, color: Color(0xFF38BDF8)),
              label: const Text('Add Bullet', style: TextStyle(color: Colors.white, fontSize: 12)),
              onPressed: _addBulletPoint,
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF475569))),
            ),
            const SizedBox(width: 8),

            // Delete Slide
            if (_slides.length > 1)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                tooltip: 'Delete Slide',
                onPressed: _deleteCurrentSlide,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorDot(PresentationSlide slide, Color color) {
    final isSelected = slide.accentColor.toARGB32() == color.toARGB32();
    return GestureDetector(
      onTap: () => setState(() => slide.accentColor = color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
      ),
    );
  }

  Widget _buildSlideCanvas(PresentationSlide slide) {
    return Container(
      width: 750,
      height: 422, // 16:9 aspect ratio
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      decoration: BoxDecoration(
        color: slide.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Accent Bar
          Container(
            height: 4,
            width: 70,
            decoration: BoxDecoration(
              color: slide.accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Slide Title Field
          TextField(
            controller: _titleController,
            onChanged: (val) => slide.title = val,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            decoration: const InputDecoration(
              isDense: true,
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: 'Slide Title',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),

          // Slide Subtitle Field
          TextField(
            controller: _subtitleController,
            onChanged: (val) => slide.subtitle = val,
            style: TextStyle(
              fontSize: 14,
              color: slide.accentColor,
            ),
            decoration: const InputDecoration(
              isDense: true,
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: 'Slide Subtitle / Description',
              hintStyle: TextStyle(color: Colors.white24),
            ),
          ),
          const SizedBox(height: 16),

          // Slide Bullets / Body Content
          if (slide.layout != SlideLayout.titleSlide) ...[
            Expanded(
              child: ListView.builder(
                itemCount: slide.bullets.length,
                itemBuilder: (context, bIdx) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(color: slide.accentColor, shape: BoxShape.circle),
                        ),
                        Expanded(
                          child: TextFormField(
                            initialValue: slide.bullets[bIdx],
                            onChanged: (val) => _updateBulletPoint(bIdx, val),
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            decoration: const InputDecoration(
                              isDense: true,
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: 'Bullet point...',
                              hintStyle: TextStyle(color: Colors.white24),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 14, color: Colors.white24),
                          onPressed: () => _removeBulletPoint(bIdx),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            const Spacer(),
          ],

          // Slide Footer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _deckTitle,
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
              Text(
                '${_currentSlideIndex + 1} / ${_slides.length}',
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Interactive Fullscreen Slide Show Mode
class FullscreenPresentationViewer extends StatefulWidget {
  final List<PresentationSlide> slides;
  final String deckTitle;
  final int initialIndex;

  const FullscreenPresentationViewer({
    super.key,
    required this.slides,
    required this.deckTitle,
    this.initialIndex = 0,
  });

  @override
  State<FullscreenPresentationViewer> createState() => _FullscreenPresentationViewerState();
}

class _FullscreenPresentationViewerState extends State<FullscreenPresentationViewer> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _nextSlide() {
    if (_currentIndex < widget.slides.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _prevSlide() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slides[_currentIndex];

    return Scaffold(
      backgroundColor: slide.backgroundColor,
      body: Stack(
        children: [
          // Slide Content
          GestureDetector(
            onTap: _nextSlide,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 5,
                    width: 90,
                    decoration: BoxDecoration(
                      color: slide.accentColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    slide.title,
                    style: TextStyle(
                      fontSize: slide.layout == SlideLayout.titleSlide ? 44 : 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (slide.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      slide.subtitle,
                      style: TextStyle(
                        fontSize: slide.layout == SlideLayout.titleSlide ? 22 : 16,
                        color: slide.accentColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 36),
                  if (slide.layout != SlideLayout.titleSlide) ...[
                    Expanded(
                      child: ListView(
                        children: slide.bullets.map((b) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(top: 8, right: 16),
                                  decoration: BoxDecoration(
                                    color: slide.accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    b,
                                    style: const TextStyle(fontSize: 20, color: Colors.white, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.deckTitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      Text('${_currentIndex + 1} of ${widget.slides.length}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Exit & Navigation Controls (Overlay)
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white70, size: 32),
                  onPressed: _prevSlide,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white70, size: 32),
                  onPressed: _nextSlide,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
