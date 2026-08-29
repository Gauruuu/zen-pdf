import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/utils/file_helper.dart';
import '../../models/recent_file.dart';
import '../../services/recent_files_service.dart';
import '../pdf_editor/pdf_editor_screen.dart';
import '../ocr/ocr_screen.dart';
import '../signature_verify/signature_verify_screen.dart';
import '../pdf_viewer/chrome_pdf_viewer_screen.dart';
import '../document_converter/document_converter_screen.dart';
import '../common/fidget_spinner_loader.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const HomeScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<RecentFile> _recentFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    setState(() => _isLoading = true);
    final files = await RecentFilesService.getRecentFiles();
    if (mounted) {
      setState(() {
        _recentFiles = files;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteFile(RecentFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete from Recent?'),
        content: Text('Remove "${file.name}" from your recent files list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await RecentFilesService.deleteFile(file.path);
      _loadRecentFiles();
    }
  }

  Future<void> _renameFile(RecentFile file) async {
    final controller = TextEditingController(text: file.name.replaceAll('.pdf', ''));
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename PDF'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await RecentFilesService.renameFile(file.path, newName);
      _loadRecentFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _recentFiles.where((f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zen PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh files',
            onPressed: _loadRecentFiles,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecentFiles,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Zen PDF Studio',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Fast, lightweight PDF viewing, scanning, editing, and signature verification.',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ChromePdfViewerScreen()),
                              );
                            },
                            icon: const Icon(Icons.chrome_reader_mode, size: 16),
                            label: const Text('Open in PDF Viewer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 36),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text('Quick Tools', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Tool Cards Grid (including Chrome PDF Viewer)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return GridView.count(
                    crossAxisCount: isWide ? 6 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: isWide ? 1.3 : 1.15,
                    children: [
                      _buildToolCard(
                        icon: Icons.chrome_reader_mode,
                        iconColor: const Color(0xFFEA4335),
                        title: 'PDF Viewer',
                        desc: 'Chrome-style view & zoom',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChromePdfViewerScreen()),
                          );
                        },
                      ),
                      _buildToolCard(
                        icon: Icons.photo_library,
                        iconColor: const Color(0xFF2563EB),
                        title: 'Images to PDF',
                        desc: 'Filter & scan photos',
                        onTap: () => widget.onNavigateTab(1),
                      ),
                      _buildToolCard(
                        icon: Icons.edit_document,
                        iconColor: const Color(0xFF7C3AED),
                        title: 'Edit & Sign PDF',
                        desc: 'Add text & signatures',
                        onTap: () => widget.onNavigateTab(2),
                      ),
                      _buildToolCard(
                        icon: Icons.verified_user_outlined,
                        iconColor: const Color(0xFF059669),
                        title: 'Verify Signatures',
                        desc: 'Check digital certificates',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignatureVerifyScreen()),
                          );
                        },
                      ),
                      _buildToolCard(
                        icon: Icons.merge_type,
                        iconColor: const Color(0xFF0284C7),
                        title: 'Manage Pages',
                        desc: 'Combine or split files',
                        onTap: () => widget.onNavigateTab(3),
                      ),
                      _buildToolCard(
                        icon: Icons.picture_as_pdf,
                        iconColor: const Color(0xFFEA4335),
                        title: 'PDF to Any Format',
                        desc: 'To Word, PPT, Excel, TXT, CSV',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DocumentConverterScreen(initialMode: ConverterMode.pdfToAny),
                            ),
                          );
                        },
                      ),
                      _buildToolCard(
                        icon: Icons.transform_rounded,
                        iconColor: const Color(0xFF0D9488),
                        title: 'Any File to PDF',
                        desc: 'Word, PPT, Excel, TXT to PDF',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DocumentConverterScreen(initialMode: ConverterMode.anyToPdf),
                            ),
                          );
                        },
                      ),
                      _buildToolCard(
                        icon: Icons.lock,
                        iconColor: const Color(0xFFD97706),
                        title: 'Lock & Protect',
                        desc: 'Set or remove password',
                        onTap: () => widget.onNavigateTab(4),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Recent Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${_recentFiles.length} files', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),

              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search documents by name...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 12),

              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(24.0), child: FidgetSpinnerLoader(size: 48, message: 'Loading documents...')))
              else if (filtered.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty ? 'No files match your search' : 'No documents saved yet',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final dateStr = DateFormat('MMM d, y � h:mm a').format(item.modifiedDate);
                    return Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.picture_as_pdf, color: Color(0xFF2563EB)),
                        ),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          '${FileHelper.formatBytes(item.sizeInBytes)} � $dateStr',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            switch (action) {
                              case 'open':
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChromePdfViewerScreen(initialFilePath: item.path),
                                  ),
                                );
                                break;
                              case 'verify':
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SignatureVerifyScreen(initialFilePath: item.path),
                                  ),
                                );
                                break;
                              case 'share':
                                FileHelper.shareFile(item.path);
                                break;
                              case 'edit':
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PdfEditorScreen(initialFilePath: item.path),
                                  ),
                                );
                                break;
                              case 'ocr':
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OcrScreen(initialFilePath: item.path),
                                  ),
                                );
                                break;
                              case 'rename':
                                _renameFile(item);
                                break;
                              case 'delete':
                                _deleteFile(item);
                                break;
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'open', child: Text('Open in Viewer')),
                            const PopupMenuItem(value: 'verify', child: Text('Verify Signatures')),
                            const PopupMenuItem(value: 'share', child: Text('Share')),
                            const PopupMenuItem(value: 'edit', child: Text('Edit in Studio')),
                            const PopupMenuItem(value: 'ocr', child: Text('Read Text (OCR)')),
                            const PopupMenuItem(value: 'rename', child: Text('Rename')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChromePdfViewerScreen(initialFilePath: item.path),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}
