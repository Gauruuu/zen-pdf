import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/scanned_image.dart';
import '../../services/image_filter_service.dart';

class ImageFilterEditor extends StatefulWidget {
  final ScannedImage image;

  const ImageFilterEditor({super.key, required this.image});

  @override
  State<ImageFilterEditor> createState() => _ImageFilterEditorState();
}

class _ImageFilterEditorState extends State<ImageFilterEditor> {
  late DocumentFilter _currentFilter;
  late int _rotationQuarterTurns;
  Uint8List? _previewBytes;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.image.filter;
    _rotationQuarterTurns = widget.image.rotationQuarterTurns;
    _previewBytes = widget.image.previewBytes;
    _updatePreview();
  }

  Future<void> _updatePreview() async {
    setState(() => _isProcessing = true);
    final processed = await ImageFilterService.processImage(
      inputBytes: widget.image.originalBytes,
      filter: _currentFilter,
      rotationQuarterTurns: _rotationQuarterTurns,
      maxDimension: 1080,
      quality: 75,
    );
    if (mounted) {
      setState(() {
        _previewBytes = processed;
        _isProcessing = false;
      });
    }
  }

  void _onSelectFilter(DocumentFilter filter) {
    if (_currentFilter == filter) return;
    setState(() => _currentFilter = filter);
    _updatePreview();
  }

  void _rotateClockwise() {
    setState(() => _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4);
    _updatePreview();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Filter & Clean Picture', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right),
            tooltip: 'Rotate 90�',
            onPressed: _rotateClockwise,
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(
                context,
                widget.image.copyWith(
                  filter: _currentFilter,
                  rotationQuarterTurns: _rotationQuarterTurns,
                  previewBytes: _previewBytes,
                ),
              );
            },
            child: const Text('Done', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview Canvas
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : _previewBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _previewBytes!,
                              fit: BoxFit.contain,
                            ),
                          )
                        : const SizedBox(),
              ),
            ),
          ),
          // Filter Selector Drawer
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Text(
                    _currentFilter.simpleDescription,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: DocumentFilter.values.map((filter) {
                      final isSelected = _currentFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter.displayName),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: const Color(0xFF334155),
                          onSelected: (_) => _onSelectFilter(filter),
                        ),
                      );
                    }).toList(),
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
