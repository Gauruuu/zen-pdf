import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/file_helper.dart';
import '../../models/scanned_image.dart';
import '../../services/pdf_generator_service.dart';
import '../../services/sound_service.dart';
import 'image_filter_editor.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<ScannedImage> _scannedImages = [];
  PageSizeOption _pageSize = PageSizeOption.a4;
  PageMarginOption _pageMargin = PageMarginOption.none;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fileNameController = TextEditingController(text: 'My_Scanned_Document');
  bool _isCreating = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImagesFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      for (final file in result.files) {
        if (file.bytes != null) {
          setState(() {
            _scannedImages.add(
              ScannedImage(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                originalPath: file.path,
                originalBytes: file.bytes!,
              ),
            );
          });
        } else if (file.path != null) {
          final bytes = await File(file.path!).readAsBytes();
          setState(() {
            _scannedImages.add(
              ScannedImage(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                originalPath: file.path,
                originalBytes: bytes,
              ),
            );
          });
        }
      }
    }
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() {
        _scannedImages.add(
          ScannedImage(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            originalPath: photo.path,
            originalBytes: bytes,
          ),
        );
      });
    }
  }

  Future<void> _openFilterEditor(int index) async {
    final result = await Navigator.push<ScannedImage>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageFilterEditor(image: _scannedImages[index]),
      ),
    );

    if (result != null) {
      setState(() {
        _scannedImages[index] = result;
      });
    }
  }

  void _applyFilterToAll(DocumentFilter filter) {
    setState(() {
      for (int i = 0; i < _scannedImages.length; i++) {
        _scannedImages[i].filter = filter;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied "${filter.displayName}" to all ${_scannedImages.length} pictures.')),
    );
  }

  String _progressStatus = 'Preparing pictures...';
  double _progressPercent = 0.0;

  Future<void> _createPdf() async {
    if (_scannedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one picture first.')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
      _progressStatus = 'Preparing pictures...';
      _progressPercent = 0.0;
    });

    try {
      final pdfBytes = await PdfGeneratorService.createPdfFromImages(
        images: _scannedImages,
        pageSize: _pageSize,
        margin: _pageMargin,
        password: _passwordController.text.trim().isNotEmpty ? _passwordController.text.trim() : null,
        onProgress: (current, total, status) {
          if (mounted) {
            setState(() {
              _progressPercent = current / total;
              _progressStatus = status;
            });
          }
        },
      );

      final savedFile = await FileHelper.savePdfFile(
        bytes: pdfBytes,
        fileName: _fileNameController.text.trim().isNotEmpty ? _fileNameController.text.trim() : 'Document',
      );

      await SoundService.playSuccess();

      if (mounted) {
        setState(() => _isCreating = false);
        _showSuccessDialog(savedFile.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create PDF: $e')),
        );
      }
    }
  }

  void _showSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('PDF Created!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your PDF document has been created and saved successfully.'),
            const SizedBox(height: 10),
            Text(
              filePath,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
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
            label: const Text('Open PDF'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Images to PDF'),
        actions: [
          if (_scannedImages.isNotEmpty)
            PopupMenuButton<DocumentFilter>(
              tooltip: 'Apply Filter to All',
              icon: const Icon(Icons.auto_fix_high),
              onSelected: _applyFilterToAll,
              itemBuilder: (ctx) => DocumentFilter.values.map((f) {
                return PopupMenuItem(
                  value: f,
                  child: Text('Filter All: ${f.displayName}'),
                );
              }).toList(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Top Buttons to add images
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImagesFromFiles,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Add Pictures'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                  ),
                ),
              ],
            ),
          ),
          // Images Reorderable List / Grid
          Expanded(
            child: _scannedImages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text(
                          'No pictures added yet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Click "Add Pictures" or "Take Photo" above to start',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _scannedImages.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final item = _scannedImages.removeAt(oldIndex);
                        _scannedImages.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _scannedImages[index];
                      return Card(
                        key: ValueKey(item.id),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Row(
                            children: [
                              // Drag handle
                              const Icon(Icons.drag_handle, color: Colors.grey),
                              const SizedBox(width: 10),
                              // Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  item.previewBytes ?? item.originalBytes,
                                  width: 60,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Page details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Page ${index + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Filter: ${item.filter.displayName}',
                                      style: const TextStyle(fontSize: 13, color: Colors.blueAccent),
                                    ),
                                    if (item.rotationQuarterTurns > 0)
                                      Text(
                                        'Rotated: ${item.rotationQuarterTurns * 90}�',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ),
                              // Actions
                              IconButton(
                                icon: const Icon(Icons.tune, color: Color(0xFF2563EB)),
                                tooltip: 'Filter & Clean',
                                onPressed: () => _openFilterEditor(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                tooltip: 'Remove Page',
                                onPressed: () {
                                  setState(() => _scannedImages.removeAt(index));
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Bottom Settings Sheet
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fileNameController,
                        decoration: const InputDecoration(
                          labelText: 'File Name',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<PageSizeOption>(
                        initialValue: _pageSize,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Page Size',
                          isDense: true,
                        ),
                        items: PageSizeOption.values.map((opt) {
                          return DropdownMenuItem(
                            value: opt,
                            child: Text(opt.displayName, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _pageSize = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<PageMarginOption>(
                        initialValue: _pageMargin,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Margins',
                          isDense: true,
                        ),
                        items: PageMarginOption.values.map((opt) {
                          return DropdownMenuItem(
                            value: opt,
                            child: Text(opt.displayName, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _pageMargin = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password (Optional)',
                          hintText: 'Lock with password',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: _isCreating ? null : _createPdf,
                  child: _isCreating
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _progressStatus,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      : Text('Create PDF (${_scannedImages.length} ${_scannedImages.length == 1 ? "page" : "pages"})'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
