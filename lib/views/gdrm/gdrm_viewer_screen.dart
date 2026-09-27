import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gdrm_sdk/gdrm_sdk.dart';
import 'package:pdfrx/pdfrx.dart';
import '../../core/utils/file_helper.dart';
import '../../services/gdrm_service.dart';

class GdrmViewerScreen extends StatefulWidget {
  final String? filePath;
  final Uint8List? rawBytes;
  final bool isExternalIntent;

  const GdrmViewerScreen({
    super.key,
    this.filePath,
    this.rawBytes,
    this.isExternalIntent = false,
  });

  @override
  State<GdrmViewerScreen> createState() => _GdrmViewerScreenState();
}

class _GdrmViewerScreenState extends State<GdrmViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  GdrmMetadata? _metadata;
  Uint8List? _decryptedPdfBytes;
  String? _currentDeviceKey;
  final TextEditingController _passwordController = TextEditingController();

  late final PdfViewerController _pdfViewerController;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    _loadGdrmDocument();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (widget.isExternalIntent) {
      SystemNavigator.pop();
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _loadGdrmDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _currentDeviceKey = await GdrmService.getDeviceHardwareKey();

      Uint8List bytes;
      if (widget.rawBytes != null) {
        bytes = widget.rawBytes!;
      } else if (widget.filePath != null) {
        bytes = await File(widget.filePath!).readAsBytes();
      } else {
        throw Exception('No GDRM file provided.');
      }

      if (!GdrmService.isGdrmFile(bytes)) {
        throw Exception('This file is not a valid .gdrm cryptographic container.');
      }

      final parseResult = GdrmService.parseGdrm(bytes);
      final meta = parseResult.metadata;
      _metadata = meta;

      // 1. Check ChronoLock Time Bomb Expiry
      if (meta.isTimeBombed) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'CHRONOLOCK EXPIRED: This secure document has reached its self-destruction limit (${meta.riggedExpiry}). Access revoked.';
        });
        return;
      }

      // 2. Check Device Hardware Binding
      if (meta.senderDeviceKey.isNotEmpty) {
        if (_currentDeviceKey != null &&
            meta.senderDeviceKey.toLowerCase() != _currentDeviceKey!.toLowerCase()) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'HARDWARE MISMATCH: This document is strictly locked to host machine [${meta.senderDeviceKey}]. Current machine is [$_currentDeviceKey]. Access denied.';
          });
          return;
        }
      }

      // 3. Check Password Lock
      if (meta.hasPassword) {
        setState(() {
          _isLoading = false;
        });
        // Prompt for password
        _promptForPassword(parseResult.pdfBytes, meta.passwordHash);
        return;
      }

      // Document is unlocked and ready
      setState(() {
        _decryptedPdfBytes = parseResult.pdfBytes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _promptForPassword(Uint8List rawPdf, String expectedHash) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Enter GDRM Password'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This .gdrm container is protected with cryptographic password hashing.',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Document Password',
                prefixIcon: Icon(Icons.key),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                Navigator.pop(ctx);
                _verifyPassword(rawPdf, expectedHash);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleBack();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _verifyPassword(rawPdf, expectedHash);
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  void _verifyPassword(Uint8List rawPdf, String expectedHash) {
    final entered = _passwordController.text.trim();
    if (GdrmDeviceService.hashPassword(entered) == expectedHash) {
      setState(() {
        _decryptedPdfBytes = rawPdf;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _errorMessage = 'AUTHENTICATION FAILED: Invalid password entered for this .gdrm file.';
      });
    }
  }

  void _showSnailTrailAudit() {
    if (_metadata == null) return;
    final meta = _metadata!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.history_edu_rounded, color: Color(0xFF06B6D4)),
            SizedBox(width: 8),
            Text('SnailTrail Forensic Audit'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fingerprint: ${meta.fingerprint}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text('Licensed To: ${meta.licensedTo}', style: const TextStyle(fontSize: 12)),
              Text('Author / Owner: ${meta.copyrightOwner}', style: const TextStyle(fontSize: 12)),
              Text('Timestamp: ${meta.timestamp}', style: const TextStyle(fontSize: 12)),
              if (meta.riggedExpiry.isNotEmpty)
                Text('Expiry: ${meta.riggedExpiry}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
              const Divider(height: 20),
              const Text('IMMUTABLE TRAIL LOGS:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 8),
              if (meta.trailLogs.isEmpty)
                const Text('Container initialized and secured at authoring origin.', style: TextStyle(fontSize: 11.5, color: Colors.grey))
              else
                ...meta.trailLogs.map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• [${log.timestamp}] ${log.action}: ${log.details}', style: const TextStyle(fontSize: 11)),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isExternalIntent,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.isExternalIntent) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E293B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Back to origin',
            onPressed: _handleBack,
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF06B6D4)),
                ),
                child: const Text(
                  'GDRM SECURE',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.filePath != null ? FileHelper.getFileName(widget.filePath!) : 'Secured .gdrm Document',
                  style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            if (_metadata != null)
              IconButton(
                icon: const Icon(Icons.history_edu, color: Color(0xFF38BDF8)),
                tooltip: 'SnailTrail Audit Logs',
                onPressed: _showSnailTrailAudit,
              ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF38BDF8)),
            SizedBox(height: 16),
            Text(
              'Decrypting GDRM Container & Validating Hardware Key...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEF4444)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gpp_bad_rounded, color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 16),
              const Text(
                'GDRM Zero-Trust Access Refused',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                onPressed: _handleBack,
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                label: const Text('Exit Viewer', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_decryptedPdfBytes != null) {
      return Stack(
        children: [
          // PDF Viewer
          PdfViewer.data(
            _decryptedPdfBytes!,
            sourceName: widget.filePath ?? 'secured_document.pdf',
            controller: _pdfViewerController,
            params: const PdfViewerParams(
              enableTextSelection: false, // Anti-clipboard extraction
            ),
          ),

          // Dynamic 18% Indelible Forensic Watermark Overlay
          IgnorePointer(
            child: _buildForensicWatermark(),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildForensicWatermark() {
    final signature = _metadata?.memeSignature.isNotEmpty == true
        ? _metadata!.memeSignature
        : 'GDRM ZERO-TRUST SECURE // LICENSED TO ${_metadata?.licensedTo ?? "AUTHORIZED USER"}';
    final deviceKey = _currentDeviceKey ?? 'GDRM-DEVICE';

    return LayoutBuilder(
      builder: (context, constraints) {
        return Opacity(
          opacity: 0.16,
          child: Transform.rotate(
            angle: -0.35,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  6,
                  (index) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        signature.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'DEVICE KEY: $deviceKey | TIMESTAMP: ${DateTime.now().toIso8601String().substring(0, 19)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
