import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/utils/file_helper.dart';
import '../../services/gdrm_service.dart';
import '../../services/sound_service.dart';
import 'gdrm_viewer_screen.dart';

class GdrmExportDialog extends StatefulWidget {
  final Uint8List pdfBytes;
  final String defaultFileName;

  const GdrmExportDialog({
    super.key,
    required this.pdfBytes,
    this.defaultFileName = 'Secured_Document',
  });

  static Future<void> show(
    BuildContext context, {
    required Uint8List pdfBytes,
    String defaultFileName = 'Secured_Document',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GdrmExportDialog(
        pdfBytes: pdfBytes,
        defaultFileName: defaultFileName,
      ),
    );
  }

  @override
  State<GdrmExportDialog> createState() => _GdrmExportDialogState();
}

class _GdrmExportDialogState extends State<GdrmExportDialog> {
  late final TextEditingController _fileNameController;
  final TextEditingController _licensedToController = TextEditingController(text: 'Authorized Recipient');
  final TextEditingController _targetUsernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _watermarkController = TextEditingController(
    text: 'CONFIDENTIAL // DO NOT DISTRIBUTE // GDRM PROTECTED',
  );

  bool _lockToCurrentDevice = false;
  String _currentDeviceKey = 'Detecting...';
  bool _allowPrint = false;
  bool _isProcessing = false;
  String _expiryOption = 'never'; // 'never', '1h', '24h', '3d', '7d', 'custom'
  DateTime? _customExpiryDate;

  @override
  void initState() {
    super.initState();
    String baseName = widget.defaultFileName.replaceAll(RegExp(r'\.pdf|\.gdrm', caseSensitive: false), '');
    _fileNameController = TextEditingController(text: baseName);
    _detectDeviceKey();
  }

  Future<void> _detectDeviceKey() async {
    final key = await GdrmService.getDeviceHardwareKey();
    if (mounted) {
      setState(() {
        _currentDeviceKey = key;
      });
    }
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _licensedToController.dispose();
    _targetUsernameController.dispose();
    _passwordController.dispose();
    _watermarkController.dispose();
    super.dispose();
  }

  DateTime? _calculateExpiry() {
    final now = DateTime.now();
    switch (_expiryOption) {
      case '1h':
        return now.add(const Duration(hours: 1));
      case '24h':
        return now.add(const Duration(hours: 24));
      case '3d':
        return now.add(const Duration(days: 3));
      case '7d':
        return now.add(const Duration(days: 7));
      case 'custom':
        return _customExpiryDate;
      case 'never':
      default:
        return null;
    }
  }

  Future<void> _pickCustomDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
    );

    if (pickedTime != null && mounted) {
      setState(() {
        _customExpiryDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        _expiryOption = 'custom';
      });
    }
  }

  Future<void> _exportGdrm() async {
    setState(() => _isProcessing = true);

    try {
      final expiry = _calculateExpiry();
      final gdrmBytes = await GdrmService.packPdfToGdrm(
        pdfBytes: widget.pdfBytes,
        licensedTo: _licensedToController.text.trim(),
        copyrightOwner: 'Zen PDF Studio & GDRM',
        memeSignature: _watermarkController.text.trim(),
        password: _passwordController.text.trim(),
        targetUsername: _targetUsernameController.text.trim(),
        lockToCurrentDevice: _lockToCurrentDevice,
        riggedExpiry: expiry,
        allowPrint: _allowPrint,
      );

      final savedFile = await GdrmService.saveGdrmFile(
        bytes: gdrmBytes,
        fileName: _fileNameController.text.trim(),
      );

      await SoundService.playSuccess();

      if (!mounted) return;
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      
      nav.pop(); // Close export dialog

      _showSuccessDialog(nav, messenger, savedFile.path, gdrmBytes);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export .gdrm: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSuccessDialog(NavigatorState nav, ScaffoldMessengerState messenger, String filePath, Uint8List gdrmBytes) {
    showDialog(
      context: nav.context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text('GDRM Locked & Exported!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your document has been sealed into a zero-trust cryptographic .gdrm container.',
              style: TextStyle(fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FileHelper.getFileName(filePath),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    filePath,
                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
                ],
              ),
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
              FileHelper.shareFile(filePath, text: 'GDRM Encrypted Document Package');
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share .gdrm'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              nav.push(
                MaterialPageRoute(
                  builder: (_) => GdrmViewerScreen(filePath: filePath, rawBytes: gdrmBytes),
                ),
              );
            },
            icon: const Icon(Icons.lock_open, size: 16),
            label: const Text('Open in GDRM Viewer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.shield_moon_rounded, color: Color(0xFF06B6D4), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Export as .gdrm File',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Granular Digital Right Manager & Hardware Lock',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Scrollable Form Options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File Name Field
                    const Text(
                      'OUTPUT FILE NAME',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _fileNameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.insert_drive_file_outlined, size: 20),
                        suffixText: '.gdrm',
                        suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Recipient & User Lock
                    const Text(
                      'RECIPIENT & USER LOCK (OPTIONAL)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _licensedToController,
                            decoration: InputDecoration(
                              labelText: 'Licensed To Organization/Name',
                              prefixIcon: const Icon(Icons.business, size: 18),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _targetUsernameController,
                            decoration: InputDecoration(
                              labelText: 'Target @username',
                              prefixIcon: const Icon(Icons.alternate_email, size: 18),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Password Lock
                    const Text(
                      'PASSWORD PROTECTION (OPTIONAL)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Salted & Hashed Password (Leave blank for no password)',
                        prefixIcon: const Icon(Icons.key, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hardware Machine Anchor
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.devices, color: Color(0xFF0F172A), size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Machine Hardware Binding (Kdevice)',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              Switch(
                                value: _lockToCurrentDevice,
                                activeThumbColor: const Color(0xFF2563EB),
                                onChanged: (val) => setState(() => _lockToCurrentDevice = val),
                              ),
                            ],
                          ),
                          Text(
                            _lockToCurrentDevice
                                ? 'Document will ONLY unlock on this specific host machine ($_currentDeviceKey).'
                                : 'Allows opening on any authorized device.',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ChronoLock Time Bomb Expiry
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.timer_outlined, color: Color(0xFFD97706), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'ChronoLock Self-Destruction / Expiry',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _expiryOption,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'never', child: Text('Never Expires (Permanent)')),
                              DropdownMenuItem(value: '1h', child: Text('Self-destruct after 1 Hour')),
                              DropdownMenuItem(value: '24h', child: Text('Self-destruct after 24 Hours')),
                              DropdownMenuItem(value: '3d', child: Text('Self-destruct after 3 Days')),
                              DropdownMenuItem(value: '7d', child: Text('Self-destruct after 7 Days')),
                              DropdownMenuItem(value: 'custom', child: Text('Custom Date & Time...')),
                            ],
                            onChanged: (val) {
                              if (val == 'custom') {
                                _pickCustomDate();
                              } else {
                                setState(() => _expiryOption = val ?? 'never');
                              }
                            },
                          ),
                          if (_expiryOption == 'custom' && _customExpiryDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'Expires on: ${_customExpiryDate!.toLocal().toString().substring(0, 16)}',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Print Permission & Watermark
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.print_outlined, color: Color(0xFF0F172A), size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Allow Physical Printing',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              Switch(
                                value: _allowPrint,
                                activeThumbColor: const Color(0xFF2563EB),
                                onChanged: (val) => setState(() => _allowPrint = val),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          const Text(
                            'Indelible Forensic Watermark / Anti-AI Directive:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _watermarkController,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.all(10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: const Color(0xFF38BDF8),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isProcessing ? null : _exportGdrm,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                          )
                        : const Icon(Icons.lock, size: 18),
                    label: Text(
                      _isProcessing ? 'Packaging .GDRM...' : 'Seal & Export .GDRM',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
