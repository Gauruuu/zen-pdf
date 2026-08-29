import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../services/ocr_service.dart';
import '../../core/utils/file_helper.dart';

class OcrScreen extends StatefulWidget {
  final String? initialFilePath;

  const OcrScreen({super.key, this.initialFilePath});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  String? _selectedFileName;
  String _extractedText = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      _processFile(widget.initialFilePath!);
    }
  }

  Future<void> _pickAndProcessPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      await _processFile(result.files.single.path!);
    }
  }

  Future<void> _processFile(String filePath) async {
    setState(() {
      _isLoading = true;
      _selectedFileName = p.basename(filePath);
    });

    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final text = await OcrService.extractTextFromPdf(bytes);
      if (mounted) {
        setState(() {
          _extractedText = text;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _extractedText = 'Error reading text: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard() {
    if (_extractedText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _extractedText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text copied to clipboard!')),
      );
    }
  }

  Future<void> _saveAsTextFile() async {
    if (_extractedText.isEmpty) return;
    try {
      final baseDir = await FileHelper.getAppDocumentsPath();
      final fileName = 'Extracted_Text_${DateTime.now().millisecondsSinceEpoch}.txt';
      final path = p.join(baseDir, fileName);
      final file = File(path);
      await file.writeAsString(_extractedText);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved as $fileName'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => FileHelper.openFile(path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read Text (OCR)'),
        actions: [
          if (_extractedText.isNotEmpty && !_isLoading) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy Text',
              onPressed: _copyToClipboard,
            ),
            IconButton(
              icon: const Icon(Icons.save_alt),
              tooltip: 'Save as Text File',
              onPressed: _saveAsTextFile,
            ),
          ]
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 450;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.document_scanner, color: Color(0xFF2563EB), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedFileName ?? 'No PDF selected',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Extract readable text words',
                                      style: TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _pickAndProcessPdf,
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Choose PDF'),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.document_scanner, color: Color(0xFF2563EB), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedFileName ?? 'No PDF selected',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Extract all readable text words from document',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _pickAndProcessPdf,
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Choose PDF'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Reading text from document...'),
                            ],
                          ),
                        )
                      : _extractedText.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.text_snippet_outlined, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Choose a PDF to view extracted text here',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              child: SelectableText(
                                _extractedText,
                                style: const TextStyle(fontSize: 14, height: 1.6),
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
}
