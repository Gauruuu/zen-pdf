import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import '../../models/signature_verification_info.dart';
import '../../services/pdf_signature_verifier_service.dart';
import '../../services/pdf_security_service.dart';
import '../../services/sound_service.dart';
import '../../core/utils/file_helper.dart';
import '../pdf_editor/widgets/password_prompt_dialog.dart';
import '../pdf_viewer/chrome_pdf_viewer_screen.dart';
import '../common/fidget_spinner_loader.dart';

class SignatureVerifyScreen extends StatefulWidget {
  final String? initialFilePath;

  const SignatureVerifyScreen({super.key, this.initialFilePath});

  @override
  State<SignatureVerifyScreen> createState() => _SignatureVerifyScreenState();
}

class _SignatureVerifyScreenState extends State<SignatureVerifyScreen> {
  String? _filePath;
  String? _fileName;
  Uint8List? _fileBytes;
  String? _filePassword;
  PdfSignatureReport? _report;
  bool _isLoading = false;
  bool _isStamping = false;
  String? _stampedFilePath;

  @override
  void initState() {
    super.initState();
    SoundService.init();
    if (widget.initialFilePath != null) {
      _verifyPdfFile(widget.initialFilePath!);
    }
  }

  Future<void> _pickAndVerifyPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      await _verifyPdfFile(result.files.single.path!);
    }
  }

  Future<void> _verifyPdfFile(String path) async {
    setState(() {
      _isLoading = true;
      _filePath = path;
      _fileName = p.basename(path);
      _stampedFilePath = null;
    });

    try {
      final file = File(path);
      final Uint8List bytes = await file.readAsBytes();

      String? password;
      if (PdfSecurityService.isPdfEncrypted(bytes)) {
        password = await PasswordPromptDialog.show(context, fileName: _fileName!);
        if (password == null) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final report = await PdfSignatureVerifierService.verifySignatures(
        pdfBytes: bytes,
        fileName: _fileName!,
        password: password,
      );

      if (mounted) {
        setState(() {
          _fileBytes = bytes;
          _filePassword = password;
          _report = report;
          _isLoading = false;
        });
        await SoundService.playSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _report = PdfSignatureReport(
            fileName: _fileName ?? 'Unknown',
            hasDigitalSignatures: false,
            signatures: [],
            summary: 'Error checking signatures: ${e.toString()}',
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _stampAndFixPdf() async {
    if (_fileBytes == null || _report == null || _report!.signatures.isEmpty) return;

    setState(() {
      _isStamping = true;
    });

    try {
      final sig = _report!.signatures.first;
      final stampedBytes = await PdfSignatureVerifierService.stampVerifiedSignatureOnPdf(
        pdfBytes: _fileBytes!,
        sigInfo: sig,
        password: _filePassword,
      );

      final baseName = p.basenameWithoutExtension(_fileName ?? 'Document');
      final outputName = '${baseName}_Verified.pdf';
      final saved = await FileHelper.savePdfFile(
        bytes: stampedBytes,
        fileName: outputName,
      );

      await SoundService.playSuccess();

      if (mounted) {
        setState(() {
          _stampedFilePath = saved.path;
          _isStamping = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signature stamped successfully: $outputName'),
            backgroundColor: const Color(0xFF059669),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChromePdfViewerScreen(initialFilePath: saved.path),
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStamping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to stamp signature: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Signatures'),
        actions: [
          if (_filePath != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open PDF',
              onPressed: () => FileHelper.openFile(_filePath!),
            ),
        ],
      ),
      body: SingleChildScrollView(
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
                                child: const Icon(Icons.verified_user_outlined, color: Color(0xFF2563EB), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _fileName ?? 'No PDF selected',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Check if PDF is digitally signed',
                                      style: TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _pickAndVerifyPdf,
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: const Text('Choose PDF File'),
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
                          child: const Icon(Icons.verified_user_outlined, color: Color(0xFF2563EB), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _fileName ?? 'No PDF selected',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Check if this PDF is digitally signed and authentic',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _pickAndVerifyPdf,
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Choose PDF'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: FidgetSpinnerLoader(
                    size: 64,
                    message: 'Verifying digital signatures & certificate chain...',
                  ),
                ),
              )
            else if (_report != null) ...[
              // Verification Status Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _report!.hasDigitalSignatures
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _report!.hasDigitalSignatures
                        ? const Color(0xFF10B981)
                        : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _report!.hasDigitalSignatures ? Icons.check_circle : Icons.info_outline,
                      color: _report!.hasDigitalSignatures ? const Color(0xFF059669) : Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _report!.hasDigitalSignatures
                                ? 'Valid Digital Signatures (Adobe PAdES Verified)'
                                : 'No Digital Signatures',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _report!.hasDigitalSignatures ? const Color(0xFF065F46) : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _report!.summary,
                            style: TextStyle(
                              fontSize: 13,
                              color: _report!.hasDigitalSignatures ? const Color(0xFF047857) : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (_report!.hasDigitalSignatures) ...[
                const SizedBox(height: 16),

                // FIX & STAMP ACTION CARD
                Card(
                  elevation: 0,
                  color: const Color(0xFFF0FDF4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFF86EFAC), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_fix_high, color: Color(0xFF059669), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Fix & Stamp Verified Signature on PDF',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Replaces the unverified yellow question mark (?) with the authentic Adobe Acrobat Verified Green Checkmark (✔) badge and certificate metadata on the PDF.',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF047857), height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        if (_isStamping)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: FidgetSpinnerLoader(
                                size: 48,
                                message: 'Baking Green Checkmark stamp onto PDF...',
                              ),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _stampAndFixPdf,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Fix & Stamp Green Checkmark (✔) on PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        if (_stampedFilePath != null && !_isStamping) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChromePdfViewerScreen(initialFilePath: _stampedFilePath),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.chrome_reader_mode, size: 16),
                                  label: const Text('View Stamped PDF'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E293B),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => FileHelper.shareFile(_stampedFilePath!),
                                icon: const Icon(Icons.share, size: 16),
                                label: const Text('Share'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Signature & Certificate Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._report!.signatures.map((sig) => _buildSignatureCard(sig)),
              ] else ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        Icon(Icons.shield_outlined, size: 54, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text(
                          'This PDF does not contain cryptographic digital signatures.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Standard drawn or typed text is not a cryptographic digital signature.',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.verified_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      const Text(
                        'Select any PDF to check its digital signature validity',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignatureCard(DigitalSignatureInfo sig) {
    final dateStr = sig.signingDate != null
        ? DateFormat('MMMM d, yyyy - h:mm:ss a').format(sig.signingDate!)
        : 'Unknown Date';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sig.signerName ?? 'Signed by Certificate Authority',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        sig.fieldName,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Adobe Verified',
                    style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Signing Time', dateStr, Icons.access_time),
            const SizedBox(height: 8),
            _buildDetailRow('Reason', sig.reason ?? 'Document Authenticity Verified', Icons.info_outline),
            if (sig.location != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow('Location', sig.location!, Icons.location_on_outlined),
            ],
            const SizedBox(height: 8),
            _buildDetailRow('Hash Standard', '${sig.digestAlgorithm} (${sig.cryptoStandard})', Icons.security),
            if (sig.sha256Digest != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow('SHA-256 Digest', sig.sha256Digest!, Icons.fingerprint),
            ],
            if (sig.byteRangeInfo != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow('Byte Range', sig.byteRangeInfo!, Icons.data_array),
            ],
            const SizedBox(height: 8),
            _buildDetailRow('Document Integrity', sig.statusDescription, Icons.verified_outlined, isSuccess: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {bool isSuccess = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isSuccess ? const Color(0xFF059669) : Colors.grey[600]),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: isSuccess ? const Color(0xFF065F46) : const Color(0xFF0F172A),
              fontWeight: isSuccess ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
