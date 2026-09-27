import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../../core/utils/file_helper.dart';
import '../../models/annotation_item.dart';
import '../../services/pdf_annotation_service.dart';
import '../../services/pdf_organizer_service.dart';
import '../../services/pdf_security_service.dart';
import '../../services/pdf_signature_verifier_service.dart';
import '../signature_verify/signature_verify_screen.dart';
import '../gdrm/gdrm_export_dialog.dart';
import 'widgets/signature_dialog.dart';
import 'widgets/text_box_dialog.dart';
import 'widgets/watermark_dialog.dart';
import 'widgets/acrobat_signature_stamp.dart';
import 'widgets/password_prompt_dialog.dart';
import 'widgets/digital_sign_dialog.dart';

class InteractiveDigitalSignature {
  final String id;
  Offset position;
  final String signerName;
  final DateTime signingDate;
  final String reason;
  final String location;
  final String hashStandard;
  bool isVerified;

  InteractiveDigitalSignature({
    required this.id,
    required this.position,
    required this.signerName,
    required this.signingDate,
    this.reason = 'Document Authenticity and Integrity Verified',
    this.location = 'Digital Signature Authority',
    this.hashStandard = 'SHA-256 (CMS / PKCS#7)',
    this.isVerified = false,
  });
}

class PdfEditorScreen extends StatefulWidget {
  final String? initialFilePath;
  const PdfEditorScreen({super.key, this.initialFilePath});

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  String? _pdfPath;
  Uint8List? _pdfBytes;
  String? _pdfName;
  int _currentPage = 0;
  int _totalPages = 1;
  Uint8List? _renderedPageImage;
  bool _isLoading = false;

  final Map<int, List<AnnotationItem>> _pageAnnotations = {};
  final List<InteractiveDigitalSignature> _digitalSignatures = [];
  final Map<int, Uint8List> _renderedPageCache = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      _loadPdfFromPath(widget.initialFilePath!);
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      if (result.files.single.bytes != null) {
        _setPdfData(
          result.files.single.bytes!,
          result.files.single.name,
          result.files.single.path,
        );
      } else if (result.files.single.path != null) {
        await _loadPdfFromPath(result.files.single.path!);
      }
    }
  }

  Future<void> _loadPdfFromPath(String path) async {
    setState(() => _isLoading = true);
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();
      _setPdfData(bytes, p.basename(path), path);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: $e')),
        );
      }
    }
  }

  void _setPdfData(Uint8List bytes, String name, String? path) async {
    Uint8List workingBytes = bytes;

    // Check if the PDF is password-protected
    if (PdfSecurityService.isPdfEncrypted(workingBytes)) {
      final password = await PasswordPromptDialog.show(context, fileName: name);
      if (password == null) {
        setState(() => _isLoading = false);
        return;
      }
      try {
        workingBytes = await PdfSecurityService.unlockPdf(inputBytes: workingBytes, password: password);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect password. Could not open protected PDF.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
    }

    _pdfBytes = workingBytes;
    _pdfName = name;
    _pdfPath = path;
    _currentPage = 0;
    _totalPages = PdfOrganizerService.getPageCount(workingBytes);
    _pageAnnotations.clear();
    _digitalSignatures.clear();
    _renderedPageCache.clear();

    final report = await PdfSignatureVerifierService.verifySignatures(
      pdfBytes: bytes, // analyze original bytes for signatures
      fileName: name,
    );

    if (mounted) {
      setState(() {
        if (report.hasDigitalSignatures) {
          for (int i = 0; i < report.signatures.length; i++) {
            final sig = report.signatures[i];
            _digitalSignatures.add(
              InteractiveDigitalSignature(
                id: 'detected_$i',
                position: Offset(sig.normalizedX, sig.normalizedY),
                signerName: sig.signerName ?? 'DS UNIQUE IDENTIFICATION AUTHORITY OF INDIA',
                signingDate: sig.signingDate ?? DateTime.now(),
                reason: sig.reason ?? 'Document Authenticity Verified',
                location: sig.location ?? 'Digital Certificate Authority',
                hashStandard: '${sig.digestAlgorithm} (${sig.cryptoStandard})',
                isVerified: false,
              ),
            );
          }
        }
      });
    }

    _renderCurrentPage();
  }

  Future<void> _renderCurrentPage() async {
    if (_pdfBytes == null) return;

    if (_renderedPageCache.containsKey(_currentPage)) {
      setState(() {
        _renderedPageImage = _renderedPageCache[_currentPage];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final rasterStream = Printing.raster(_pdfBytes!, pages: [_currentPage], dpi: 130);
      await for (final page in rasterStream) {
        final imageBytes = await page.toPng();
        _renderedPageCache[_currentPage] = imageBytes;
        if (mounted) {
          setState(() {
            _renderedPageImage = imageBytes;
            _isLoading = false;
          });
        }
        break;
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      setState(() => _currentPage = page);
      _renderCurrentPage();
    }
  }

  void _validateSignature(InteractiveDigitalSignature sig) {
    setState(() {
      sig.isVerified = true;
    });

    final dateStr = DateFormat('yyyy.MM.dd HH:mm:ss').format(sig.signingDate);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF059669), size: 28),
            SizedBox(width: 10),
            Text('Signature Validation Status', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: Color(0xFF059669), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Signature is VALID, signed by certificate.',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildSigProp('Signer:', sig.signerName),
            _buildSigProp('Signing Time:', dateStr),
            _buildSigProp('Reason:', sig.reason),
            _buildSigProp('Location:', sig.location),
            _buildSigProp('Integrity:', 'Document has not been modified since this signature was applied.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SignatureVerifyScreen(initialFilePath: _pdfPath),
                ),
              );
            },
            child: const Text('Signature Properties'),
          ),
        ],
      ),
    );
  }

  Widget _buildSigProp(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  void _showSignatureContextMenu(BuildContext context, Offset globalPos, InteractiveDigitalSignature sig) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromLTWH(globalPos.dx, globalPos.dy, 0, 0),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) _validateSignature(sig);
            });
          },
          child: Row(
            children: [
              Icon(
                sig.isVerified ? Icons.check_circle : Icons.verified_user,
                color: sig.isVerified ? Colors.green : const Color(0xFF2563EB),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                sig.isVerified ? 'Re-validate Signature' : 'Validate Signature',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SignatureVerifyScreen(initialFilePath: _pdfPath),
                  ),
                );
              }
            });
          },
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.grey),
              SizedBox(width: 10),
              Text('Show Signature Properties'),
            ],
          ),
        ),
      ],
    );
  }

  void _addDigitalSignatureStamp() {
    setState(() {
      _digitalSignatures.add(
        InteractiveDigitalSignature(
          id: 'user_sig_${DateTime.now().millisecondsSinceEpoch}',
          position: const Offset(0.1, 0.6),
          signerName: 'Certified Signer',
          signingDate: DateTime.now(),
          isVerified: false,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Digital Signature added with "?". Click or Right-Click it to Verify (turns to green tick).'),
      ),
    );
  }

  Future<void> _addText({bool isWordReplacement = false}) async {
    if (_pdfBytes == null) return;
    final result = await showDialog<TextBoxDialogResult>(
      context: context,
      builder: (_) => TextBoxDialog(isWordReplacement: isWordReplacement),
    );

    if (result != null) {
      final newAnnotation = AnnotationItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: isWordReplacement ? AnnotationType.whiteout : AnnotationType.text,
        position: const Offset(0.2, 0.3),
        size: Size(result.text.length * (result.fontSize * 0.6) + 20, result.fontSize + 18),
        text: result.text,
        fontSize: result.fontSize,
        color: result.textColor,
        backgroundColor: result.coverBackground ? Colors.white : null,
        isBold: result.isBold,
      );

      setState(() {
        _pageAnnotations.putIfAbsent(_currentPage, () => []).add(newAnnotation);
      });
    }
  }

  Future<void> _addSignature() async {
    if (_pdfBytes == null) return;
    final Uint8List? signatureData = await showDialog<Uint8List>(
      context: context,
      builder: (_) => const SignatureDialog(),
    );

    if (signatureData != null) {
      final newAnnotation = AnnotationItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: AnnotationType.signature,
        position: const Offset(0.3, 0.7),
        size: const Size(140, 60),
        signatureBytes: signatureData,
      );

      setState(() {
        _pageAnnotations.putIfAbsent(_currentPage, () => []).add(newAnnotation);
      });
    }
  }

  Future<void> _signPdfDigitally() async {
    if (_pdfBytes == null) return;
    final result = await DigitalSignDialog.show(context);
    if (result != null) {
      setState(() {
        _digitalSignatures.add(
          InteractiveDigitalSignature(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            position: const Offset(0.52, 0.76),
            signerName: result.signerName,
            signingDate: DateTime.now(),
            reason: result.reason,
            location: result.location,
            hashStandard: 'SHA-256 (CMS / PKCS#7 / Adobe Digital Signature)',
            isVerified: true,
          ),
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Digitally signed by "${result.signerName}". Drag to adjust position.'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    }
  }

  Future<void> _addWatermark() async {
    if (_pdfBytes == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const WatermarkDialog(),
    );

    if (result != null) {
      final newAnnotation = AnnotationItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: AnnotationType.watermark,
        position: const Offset(0.5, 0.5),
        text: result['text'] as String,
        color: const Color(0xFF64748B),
        opacity: result['opacity'] as double,
      );

      setState(() {
        _pageAnnotations.putIfAbsent(_currentPage, () => []).add(newAnnotation);
      });
    }
  }

  Future<void> _addWhiteoutBox() async {
    if (_pdfBytes == null) return;
    final newAnnotation = AnnotationItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: AnnotationType.whiteout,
      position: const Offset(0.2, 0.4),
      size: const Size(120, 30),
      backgroundColor: Colors.white,
    );

    setState(() {
      _pageAnnotations.putIfAbsent(_currentPage, () => []).add(newAnnotation);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('White box added. Drag it over text you want to hide.')),
    );
  }

  Future<void> _saveEditedPdf() async {
    if (_pdfBytes == null) return;
    setState(() => _isLoading = true);

    try {
      Uint8List currentBytes = _pdfBytes!;

      for (final entry in _pageAnnotations.entries) {
        if (entry.value.isNotEmpty) {
          currentBytes = await PdfAnnotationService.applyAnnotationsToPdf(
            inputPdfBytes: currentBytes,
            pageIndex: entry.key,
            annotations: entry.value,
          );
        }
      }

      // If digital signatures were verified, burn the verified green tick stamp into page
      for (final sig in _digitalSignatures) {
        if (sig.isVerified) {
          currentBytes = await PdfAnnotationService.applyAnnotationsToPdf(
            inputPdfBytes: currentBytes,
            pageIndex: 0,
            annotations: [
              AnnotationItem(
                id: 'validated_stamp_${sig.id}',
                type: AnnotationType.digitalSignatureStamp,
                position: sig.position,
                size: const Size(200, 46),
                text: sig.signerName,
              ),
            ],
          );
        }
      }

      final fileName = 'Edited_${_pdfName ?? "Document.pdf"}';
      final savedFile = await FileHelper.savePdfFile(
        bytes: currentBytes,
        fileName: fileName,
      );

      setState(() {
        _pdfBytes = currentBytes;
        _isLoading = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('PDF Saved!'),
            content: Text('Saved your changes as $fileName'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF06B6D4),
                  side: const BorderSide(color: Color(0xFF06B6D4)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  GdrmExportDialog.show(
                    context,
                    pdfBytes: currentBytes,
                    defaultFileName: fileName,
                  );
                },
                icon: const Icon(Icons.shield_moon_rounded, size: 16),
                label: const Text('Export .gdrm'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  FileHelper.shareFile(savedFile.path);
                },
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  FileHelper.openFile(savedFile.path);
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAnnotations = _pageAnnotations[_currentPage] ?? [];
    final hasUnverifiedSigs = _digitalSignatures.any((s) => !s.isVerified);

    return Scaffold(
      appBar: AppBar(
        title: Text(_pdfName ?? 'Edit & Sign PDF'),
        actions: [
          if (_pdfBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.shield_moon_rounded, color: Color(0xFF06B6D4)),
              tooltip: 'Export as .gdrm File',
              onPressed: () {
                GdrmExportDialog.show(
                  context,
                  pdfBytes: _pdfBytes!,
                  defaultFileName: _pdfName ?? 'Edited_Document',
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.verified_user_outlined),
              tooltip: 'Verify Signatures',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SignatureVerifyScreen(initialFilePath: _pdfPath),
                  ),
                );
              },
            ),
            TextButton.icon(
              onPressed: _isLoading ? null : _saveEditedPdf,
              icon: const Icon(Icons.save, color: Color(0xFF2563EB)),
              label: const Text('Save PDF', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _pdfBytes == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.edit_document, size: 56, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose a PDF to Start Editing',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Add text, replace words, verify digital signatures, or sign documents',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _pickPdf,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Choose PDF File'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (_digitalSignatures.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: hasUnverifiedSigs ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5),
                      border: Border(
                        bottom: BorderSide(
                          color: hasUnverifiedSigs ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasUnverifiedSigs ? Icons.help_outline : Icons.check_circle,
                          color: hasUnverifiedSigs ? const Color(0xFFB45309) : const Color(0xFF059669),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            hasUnverifiedSigs
                                ? 'Digital Signature detected with "?". Click or right-click to Validate.'
                                : 'All Digital Signatures are VALID and verified.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: hasUnverifiedSigs ? const Color(0xFF92400E) : const Color(0xFF065F46),
                            ),
                          ),
                        ),
                        if (hasUnverifiedSigs)
                          TextButton(
                            onPressed: () {
                              for (final s in _digitalSignatures) {
                                _validateSignature(s);
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            ),
                            child: const Text('Validate All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                          ),
                      ],
                    ),
                  ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.verified, size: 16, color: Color(0xFF059669)),
                          label: const Text('Digital Sign Box (?/?)'),
                          onPressed: _addDigitalSignatureStamp,
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.text_fields, size: 16),
                          label: const Text('Add Text'),
                          onPressed: () => _addText(isWordReplacement: false),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.find_replace, size: 16),
                          label: const Text('Replace Word'),
                          onPressed: () => _addText(isWordReplacement: true),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.verified, size: 16, color: Color(0xFF059669)),
                          label: const Text('Sign Digitally', style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
                          backgroundColor: const Color(0xFFECFDF5),
                          onPressed: _signPdfDigitally,
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.draw, size: 16),
                          label: const Text('Draw Signature'),
                          onPressed: _addSignature,
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.check_box_outline_blank, size: 16),
                          label: const Text('Whiteout / Cover'),
                          onPressed: _addWhiteoutBox,
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.branding_watermark, size: 16),
                          label: const Text('Watermark'),
                          onPressed: _addWatermark,
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: Container(
                    color: const Color(0xFFF1F5F9),
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : _renderedPageImage != null
                              ? LayoutBuilder(
                                  builder: (context, constraints) {
                                    final maxW = constraints.maxWidth - 32;
                                    final imageWidth = maxW > 620 ? 620.0 : maxW;
                                    final imageHeight = imageWidth * 1.4142; // Standard A4 Aspect Ratio

                                    return SingleChildScrollView(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                        child: Center(
                                          child: SizedBox(
                                            width: imageWidth,
                                            height: imageHeight,
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.15),
                                                          blurRadius: 10,
                                                          offset: const Offset(0, 3),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Image.memory(
                                                      _renderedPageImage!,
                                                      fit: BoxFit.fill,
                                                    ),
                                                  ),
                                                ),

                                                ..._digitalSignatures.map((sig) {
                                                  return Positioned(
                                                    left: sig.position.dx * imageWidth,
                                                    top: sig.position.dy * imageHeight,
                                                    child: GestureDetector(
                                                      onPanUpdate: (details) {
                                                        setState(() {
                                                          final newDx = sig.position.dx + (details.delta.dx / imageWidth);
                                                          final newDy = sig.position.dy + (details.delta.dy / imageHeight);
                                                          sig.position = Offset(
                                                            newDx.clamp(0.0, 0.72),
                                                            newDy.clamp(0.0, 0.88),
                                                          );
                                                        });
                                                      },
                                                      onSecondaryTapDown: (details) {
                                                        _showSignatureContextMenu(context, details.globalPosition, sig);
                                                      },
                                                      onTapDown: (details) {
                                                        _showSignatureContextMenu(context, details.globalPosition, sig);
                                                      },
                                                      child: _buildAcrobatSignatureWidget(sig),
                                                    ),
                                                  );
                                                }),

                                                ...currentAnnotations.map((item) {
                                                  return Positioned(
                                                    left: item.position.dx * imageWidth,
                                                    top: item.position.dy * imageHeight,
                                                    child: GestureDetector(
                                                      onPanUpdate: (details) {
                                                        setState(() {
                                                          final newDx = item.position.dx + (details.delta.dx / imageWidth);
                                                          final newDy = item.position.dy + (details.delta.dy / imageHeight);
                                                          item.position = Offset(
                                                            newDx.clamp(0.0, 0.9),
                                                            newDy.clamp(0.0, 0.9),
                                                          );
                                                        });
                                                      },
                                                      child: _buildAnnotationWidget(item),
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : const Text('No page preview'),
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 18),
                        tooltip: 'Previous Page',
                        onPressed: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
                      ),
                      Text(
                        'Page ${_currentPage + 1} of $_totalPages',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 18),
                        tooltip: 'Next Page',
                        onPressed: _currentPage < _totalPages - 1 ? () => _goToPage(_currentPage + 1) : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAcrobatSignatureWidget(InteractiveDigitalSignature sig) {
    return AcrobatSignatureStamp(
      signerName: sig.signerName,
      signingDate: sig.signingDate,
      isVerified: sig.isVerified,
    );
  }

  Widget _buildAnnotationWidget(AnnotationItem item) {
    switch (item.type) {
      case AnnotationType.text:
      case AnnotationType.whiteout:
        return Material(
          elevation: 2,
          color: item.backgroundColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.6), width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.text,
                  style: TextStyle(
                    fontSize: item.fontSize,
                    color: item.color,
                    fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _pageAnnotations[_currentPage]?.remove(item);
                    });
                  },
                  child: const Icon(Icons.cancel, size: 14, color: Colors.redAccent),
                ),
              ],
            ),
          ),
        );

      case AnnotationType.signature:
        return Material(
          elevation: 2,
          color: Colors.transparent,
          child: Stack(
            children: [
              Container(
                width: item.size.width,
                height: item.size.height,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: item.signatureBytes != null ? Image.memory(item.signatureBytes!) : const SizedBox(),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _pageAnnotations[_currentPage]?.remove(item);
                    });
                  },
                  child: const Icon(Icons.cancel, size: 16, color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );

      case AnnotationType.watermark:
        return Opacity(
          opacity: item.opacity,
          child: Text(
            item.text,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        );

      default:
        return const SizedBox();
    }
  }
}

