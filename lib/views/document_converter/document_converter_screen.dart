import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/file_helper.dart';
import '../../services/document_converter_service.dart';
import '../../services/sound_service.dart';
import '../common/fidget_spinner_loader.dart';
import '../pdf_viewer/chrome_pdf_viewer_screen.dart';

enum ConverterMode {
  pdfToAny('PDF to Any Format'),
  anyToPdf('Any File to PDF');

  final String title;
  const ConverterMode(this.title);
}

class DocumentConverterScreen extends StatefulWidget {
  final String? initialFilePath;
  final ConverterMode initialMode;

  const DocumentConverterScreen({
    super.key,
    this.initialFilePath,
    this.initialMode = ConverterMode.pdfToAny,
  });

  @override
  State<DocumentConverterScreen> createState() => _DocumentConverterScreenState();
}

class _DocumentConverterScreenState extends State<DocumentConverterScreen> {
  late ConverterMode _activeMode;
  String? _selectedFilePath;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  DocumentFormatType _sourceFormat = DocumentFormatType.pdf;
  String _targetFormat = 'docx'; // 'pdf', 'docx', 'pptx', 'xlsx', 'txt', 'csv', 'html', 'json'
  
  bool _isConverting = false;
  String _statusMessage = 'Converting document...';
  String? _convertedFilePath;

  @override
  void initState() {
    super.initState();
    SoundService.init();
    _activeMode = widget.initialMode;
    if (widget.initialFilePath != null) {
      _loadFile(widget.initialFilePath!);
    }
  }

  void _switchMode(ConverterMode mode) {
    if (_activeMode == mode) return;
    setState(() {
      _activeMode = mode;
      _selectedFilePath = null;
      _selectedFileName = null;
      _selectedFileBytes = null;
      _convertedFilePath = null;
      if (mode == ConverterMode.pdfToAny) {
        _sourceFormat = DocumentFormatType.pdf;
        _targetFormat = 'docx';
      } else {
        _sourceFormat = DocumentFormatType.docx;
        _targetFormat = 'pdf';
      }
    });
  }

  Future<void> _pickFile() async {
    final List<String> extensions;
    if (_activeMode == ConverterMode.pdfToAny) {
      extensions = ['pdf'];
    } else {
      extensions = [
        'docx', 'doc', 'pptx', 'ppt', 'xlsx', 'xls',
        'txt', 'csv', 'json', 'html',
        'jpg', 'jpeg', 'png', 'webp', 'bmp',
      ];
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );

    if (result != null && result.files.single.path != null) {
      await _loadFile(result.files.single.path!);
    }
  }

  Future<void> _loadFile(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final ext = p.extension(path);
    final format = DocumentFormatType.fromExtension(ext);

    setState(() {
      _selectedFilePath = path;
      _selectedFileName = p.basename(path);
      _selectedFileBytes = bytes;
      _sourceFormat = format;
      _convertedFilePath = null;

      if (format == DocumentFormatType.pdf) {
        _activeMode = ConverterMode.pdfToAny;
        _targetFormat = 'docx';
      } else {
        _activeMode = ConverterMode.anyToPdf;
        _targetFormat = 'pdf';
      }
    });
  }

  Future<void> _performConversion() async {
    if (_selectedFileBytes == null || _selectedFileName == null) return;

    setState(() {
      _isConverting = true;
      _statusMessage = 'Preparing document...';
    });

    try {
      final baseName = p.basenameWithoutExtension(_selectedFileName!);
      Uint8List? outputBytes;
      String outputFileName = '';

      if (_sourceFormat == DocumentFormatType.pdf) {
        // PDF to Any Format
        switch (_targetFormat) {
          case 'docx':
            setState(() => _statusMessage = 'Converting PDF to Word (.docx)...');
            outputBytes = await DocumentConverterService.pdfToDocx(_selectedFileBytes!, title: baseName);
            outputFileName = '${baseName}_Converted.docx';
            break;
          case 'pptx':
            setState(() => _statusMessage = 'Converting PDF to PowerPoint (.pptx)...');
            outputBytes = await DocumentConverterService.pdfToPptx(_selectedFileBytes!, title: baseName);
            outputFileName = '${baseName}_Presentation.pptx';
            break;
          case 'xlsx':
            setState(() => _statusMessage = 'Converting PDF to Excel (.xlsx)...');
            outputBytes = await DocumentConverterService.pdfToXlsx(_selectedFileBytes!, title: baseName);
            outputFileName = '${baseName}_Spreadsheet.xlsx';
            break;
          case 'txt':
            setState(() => _statusMessage = 'Extracting text from PDF...');
            final text = await DocumentConverterService.pdfToText(_selectedFileBytes!);
            outputBytes = Uint8List.fromList(text.codeUnits);
            outputFileName = '${baseName}_Text.txt';
            break;
          case 'csv':
            setState(() => _statusMessage = 'Extracting data table to CSV...');
            final csv = await DocumentConverterService.pdfToCsv(_selectedFileBytes!);
            outputBytes = Uint8List.fromList(csv.codeUnits);
            outputFileName = '${baseName}_Data.csv';
            break;
          case 'html':
            setState(() => _statusMessage = 'Generating HTML webpage...');
            final html = await DocumentConverterService.pdfToHtml(_selectedFileBytes!, title: baseName);
            outputBytes = Uint8List.fromList(html.codeUnits);
            outputFileName = '${baseName}_Webpage.html';
            break;
          case 'json':
            setState(() => _statusMessage = 'Parsing PDF structure to JSON...');
            final json = await DocumentConverterService.pdfToJson(_selectedFileBytes!, title: baseName);
            outputBytes = Uint8List.fromList(json.codeUnits);
            outputFileName = '${baseName}_Data.json';
            break;
        }
      } else {
        // Any Format to PDF
        outputBytes = await DocumentConverterService.convertToPdf(
          inputBytes: _selectedFileBytes!,
          sourceFormat: _sourceFormat,
          title: baseName,
          onProgress: (msg) {
            if (mounted) setState(() => _statusMessage = msg);
          },
        );
        outputFileName = '${baseName}_Converted.pdf';
      }

      if (outputBytes != null) {
        setState(() => _statusMessage = 'Saving converted file...');
        final saved = await FileHelper.savePdfFile(
          bytes: outputBytes,
          fileName: outputFileName,
        );

        await SoundService.playSuccess();

        if (mounted) {
          setState(() {
            _convertedFilePath = saved.path;
            _isConverting = false;
          });
          _showSuccessSnackbar(saved.path);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConverting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversion failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showSuccessSnackbar(String path) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Converted successfully: ${p.basename(path)}'),
        backgroundColor: const Color(0xFF059669),
        action: SnackBarAction(
          label: 'OPEN',
          textColor: Colors.white,
          onPressed: () => FileHelper.openFile(path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPdfToAny = _activeMode == ConverterMode.pdfToAny;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isPdfToAny ? 'PDF to Any Format' : 'Any File to PDF'),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Switcher Segmented Control
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _switchMode(ConverterMode.pdfToAny),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isPdfToAny ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: isPdfToAny
                              ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.picture_as_pdf,
                              size: 18,
                              color: isPdfToAny ? const Color(0xFFEA4335) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'PDF to Any Format',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isPdfToAny ? FontWeight.bold : FontWeight.w500,
                                color: isPdfToAny ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _switchMode(ConverterMode.anyToPdf),
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isPdfToAny ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: !isPdfToAny
                              ? [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.transform,
                              size: 18,
                              color: !isPdfToAny ? const Color(0xFF0D9488) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Any File to PDF',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: !isPdfToAny ? FontWeight.bold : FontWeight.w500,
                                color: !isPdfToAny ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Header Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPdfToAny
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFF0F766E), const Color(0xFF115E59)],
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
                        Text(
                          isPdfToAny
                              ? 'Convert PDF to Word, PPT, Excel & More'
                              : 'Convert Any Document to PDF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isPdfToAny
                              ? 'Convert PDF to Microsoft Word (.docx), PowerPoint (.pptx), Excel (.xlsx), Text, CSV, HTML & JSON 100% offline.'
                              : 'Convert Word (.docx), PowerPoint (.pptx), Excel (.xlsx), Text, and CSV into PDF 100% offline.',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPdfToAny ? Icons.picture_as_pdf : Icons.transform,
                      color: isPdfToAny ? const Color(0xFF38BDF8) : const Color(0xFF5EEAD4),
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // File Pick Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (_selectedFileName == null) ...[
                      Icon(
                        isPdfToAny ? Icons.picture_as_pdf_outlined : Icons.cloud_upload_outlined,
                        size: 48,
                        color: isPdfToAny ? const Color(0xFFEA4335) : const Color(0xFF0D9488),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isPdfToAny ? 'Select a PDF document' : 'Select a document to convert',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPdfToAny
                            ? 'Convert to Word, PPTX, Excel, TXT, CSV, HTML, JSON'
                            : 'Word, PowerPoint, Excel, Text, CSV, or Images',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.folder_open),
                        label: Text(isPdfToAny ? 'Choose PDF File' : 'Choose File to Convert'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPdfToAny ? const Color(0xFFEA4335) : const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _sourceFormat == DocumentFormatType.pdf
                                  ? Icons.picture_as_pdf
                                  : Icons.description,
                              color: _sourceFormat == DocumentFormatType.pdf
                                  ? const Color(0xFFEA4335)
                                  : const Color(0xFF2563EB),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFileName!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _sourceFormat.displayName,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (_selectedFilePath != null) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _selectedFilePath!,
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
                            tooltip: 'Change File',
                            onPressed: _pickFile,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_selectedFileName != null) ...[
              const SizedBox(height: 18),

              // Target Format Selector Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Output Format:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 12),
                      if (_sourceFormat == DocumentFormatType.pdf) ...[
                        _buildFormatOption('docx', 'Microsoft Word (.docx)', Icons.article, const Color(0xFF2563EB)),
                        const SizedBox(height: 8),
                        _buildFormatOption('pptx', 'PowerPoint Presentation (.pptx)', Icons.slideshow, const Color(0xFFEA580C)),
                        const SizedBox(height: 8),
                        _buildFormatOption('xlsx', 'Excel Spreadsheet (.xlsx)', Icons.table_view, const Color(0xFF16A34A)),
                        const SizedBox(height: 8),
                        _buildFormatOption('txt', 'Plain Text (.txt)', Icons.text_snippet, const Color(0xFF7C3AED)),
                        const SizedBox(height: 8),
                        _buildFormatOption('csv', 'Spreadsheet Data (.csv)', Icons.table_chart, const Color(0xFF059669)),
                        const SizedBox(height: 8),
                        _buildFormatOption('html', 'HTML Webpage (.html)', Icons.code, const Color(0xFF0284C7)),
                        const SizedBox(height: 8),
                        _buildFormatOption('json', 'Structured JSON (.json)', Icons.data_object, const Color(0xFFD97706)),
                      ] else ...[
                        _buildFormatOption('pdf', 'Adobe PDF Document (.pdf)', Icons.picture_as_pdf, const Color(0xFFEA4335)),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Conversion Action Button / Fidget Spinner Loader
              if (_isConverting) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: FidgetSpinnerLoader(
                      size: 72,
                      message: _statusMessage,
                    ),
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _performConversion,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text('Convert to ${_targetFormat.toUpperCase()}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: isPdfToAny ? const Color(0xFFEA4335) : const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],

            // Converted File Success Result Card
            if (_convertedFilePath != null && !_isConverting) ...[
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                color: const Color(0xFFF0FDF4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFBBF7D0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Conversion Complete!',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF065F46)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.basename(_convertedFilePath!),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF047857)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (_convertedFilePath!.endsWith('.pdf')) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChromePdfViewerScreen(initialFilePath: _convertedFilePath),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.chrome_reader_mode, size: 16),
                                label: const Text('View PDF'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ] else ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => FileHelper.openFile(_convertedFilePath!),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open File'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          OutlinedButton.icon(
                            onPressed: () => FileHelper.shareFile(_convertedFilePath!),
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('Share'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormatOption(String value, String title, IconData icon, Color color) {
    final isSelected = _targetFormat == value;
    return InkWell(
      onTap: () => setState(() => _targetFormat = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13.5,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 20)
            else
              const Icon(Icons.radio_button_unchecked, color: Color(0xFF94A3B8), size: 20),
          ],
        ),
      ),
    );
  }
}
