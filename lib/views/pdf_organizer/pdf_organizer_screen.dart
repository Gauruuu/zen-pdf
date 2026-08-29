import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/file_helper.dart';
import '../../services/pdf_organizer_service.dart';

class PdfOrganizerScreen extends StatefulWidget {
  const PdfOrganizerScreen({super.key});

  @override
  State<PdfOrganizerScreen> createState() => _PdfOrganizerScreenState();
}

class _PdfOrganizerScreenState extends State<PdfOrganizerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<File> _filesToMerge = [];
  bool _isMerging = false;

  File? _splitPdfFile;
  int _splitPdfPageCount = 0;
  final TextEditingController _pageRangeController = TextEditingController(text: '1-2');
  bool _isSplitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageRangeController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfsToMerge() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      for (final path in result.paths) {
        if (path != null) {
          setState(() {
            _filesToMerge.add(File(path));
          });
        }
      }
    }
  }

  Future<void> _mergePdfs() async {
    if (_filesToMerge.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 2 PDF files to combine.')),
      );
      return;
    }

    setState(() => _isMerging = true);

    try {
      final List<Uint8List> bytesList = [];
      for (final file in _filesToMerge) {
        bytesList.add(await file.readAsBytes());
      }

      final mergedBytes = await PdfOrganizerService.mergePdfs(bytesList);
      final savedFile = await FileHelper.savePdfFile(
        bytes: mergedBytes,
        fileName: 'Combined_Document.pdf',
      );

      setState(() => _isMerging = false);

      if (mounted) {
        _showSuccessDialog('Combined PDF Created', savedFile.path);
      }
    } catch (e) {
      setState(() => _isMerging = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error combining PDFs: $e')),
        );
      }
    }
  }

  Future<void> _pickPdfToSplit() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final count = PdfOrganizerService.getPageCount(bytes);

      setState(() {
        _splitPdfFile = file;
        _splitPdfPageCount = count;
        _pageRangeController.text = count > 1 ? '1-2' : '1';
      });
    }
  }

  List<int> _parsePageRange(String input, int maxPages) {
    final Set<int> pageNumbers = {};
    final parts = input.split(RegExp(r'[,;]'));

    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.contains('-')) {
        final bounds = trimmed.split('-');
        if (bounds.length == 2) {
          final start = int.tryParse(bounds[0].trim());
          final end = int.tryParse(bounds[1].trim());
          if (start != null && end != null) {
            final low = start < end ? start : end;
            final high = start < end ? end : start;
            for (int i = low; i <= high; i++) {
              if (i >= 1 && i <= maxPages) pageNumbers.add(i);
            }
          }
        }
      } else {
        final single = int.tryParse(trimmed);
        if (single != null && single >= 1 && single <= maxPages) {
          pageNumbers.add(single);
        }
      }
    }

    final sorted = pageNumbers.toList()..sort();
    return sorted;
  }

  Future<void> _splitPdf() async {
    if (_splitPdfFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file first.')),
      );
      return;
    }

    final pagesToExtract = _parsePageRange(_pageRangeController.text, _splitPdfPageCount);
    if (pagesToExtract.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter valid page numbers between 1 and $_splitPdfPageCount')),
      );
      return;
    }

    setState(() => _isSplitting = true);

    try {
      final bytes = await _splitPdfFile!.readAsBytes();
      final extractedBytes = await PdfOrganizerService.extractPages(
        inputPdfBytes: bytes,
        pageNumbers: pagesToExtract,
      );

      final baseName = p.basenameWithoutExtension(_splitPdfFile!.path);
      final savedFile = await FileHelper.savePdfFile(
        bytes: extractedBytes,
        fileName: '${baseName}_Pages_${pagesToExtract.join("_")}.pdf',
      );

      setState(() => _isSplitting = false);

      if (mounted) {
        _showSuccessDialog('Pages Extracted Successfully', savedFile.path);
      }
    } catch (e) {
      setState(() => _isSplitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting pages: $e')),
        );
      }
    }
  }

  void _showSuccessDialog(String title, String filePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text('Saved to: $filePath'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              FileHelper.shareFile(filePath);
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              FileHelper.openFile(filePath);
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Pages'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          indicatorColor: const Color(0xFF2563EB),
          tabs: const [
            Tab(text: 'Combine PDFs', icon: Icon(Icons.merge_type)),
            Tab(text: 'Split PDF', icon: Icon(Icons.call_split)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Combine Multiple PDFs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                '${_filesToMerge.length} file${_filesToMerge.length == 1 ? "" : "s"} selected. Drag to reorder if needed.',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickPdfsToMerge,
                          icon: const Icon(Icons.add),
                          label: const Text('Add PDF'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _filesToMerge.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.picture_as_pdf_outlined, size: 54, color: Colors.grey[400]),
                              const SizedBox(height: 10),
                              const Text('No PDF files added yet', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          itemCount: _filesToMerge.length,
                          onReorder: (oldIndex, newIndex) {
                            setState(() {
                              if (oldIndex < newIndex) newIndex -= 1;
                              final item = _filesToMerge.removeAt(oldIndex);
                              _filesToMerge.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final file = _filesToMerge[index];
                            return Card(
                              key: ValueKey(file.path),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.drag_handle, color: Colors.grey),
                                title: Text(p.basename(file.path), style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(file.path, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => setState(() => _filesToMerge.removeAt(index)),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isMerging || _filesToMerge.length < 2 ? null : _mergePdfs,
                  child: _isMerging
                      ? const Text('Combining PDFs...')
                      : const Text('Combine into One PDF'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _splitPdfFile != null ? p.basename(_splitPdfFile!.path) : 'No PDF selected',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _splitPdfFile != null ? 'Total Pages: $_splitPdfPageCount' : 'Choose a PDF to extract pages from',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickPdfToSplit,
                          icon: const Icon(Icons.file_upload_outlined),
                          label: const Text('Choose PDF'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_splitPdfFile != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pages to Extract', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 6),
                          const Text('Example: 1-3, 5 (Extracts pages 1, 2, 3, and 5)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pageRangeController,
                            decoration: const InputDecoration(
                              labelText: 'Page Numbers / Range',
                              hintText: 'e.g. 1-3, 5',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _isSplitting ? null : _splitPdf,
                    child: _isSplitting ? const Text('Extracting Pages...') : const Text('Extract & Save Pages'),
                  ),
                ] else
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.call_split, size: 54, color: Colors.grey[400]),
                          const SizedBox(height: 10),
                          const Text('Select a PDF to extract or split pages', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
