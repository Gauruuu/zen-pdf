import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/file_helper.dart';
import '../../services/pdf_security_service.dart';

class PdfSecurityScreen extends StatefulWidget {
  const PdfSecurityScreen({super.key});

  @override
  State<PdfSecurityScreen> createState() => _PdfSecurityScreenState();
}

class _PdfSecurityScreenState extends State<PdfSecurityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  File? _lockFile;
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isLocking = false;

  File? _unlockFile;
  final TextEditingController _currentPasswordController = TextEditingController();
  bool _isUnlocking = false;

  File? _metaFile;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  bool _isSavingMeta = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newPasswordController.dispose();
    _currentPasswordController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _pickLockFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (res != null && res.files.single.path != null) {
      setState(() => _lockFile = File(res.files.single.path!));
    }
  }

  Future<void> _lockPdf() async {
    if (_lockFile == null || _newPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a PDF and enter a password.')),
      );
      return;
    }

    setState(() => _isLocking = true);

    try {
      final bytes = await _lockFile!.readAsBytes();
      final securedBytes = await PdfSecurityService.lockPdf(
        inputBytes: bytes,
        password: _newPasswordController.text.trim(),
      );

      final baseName = p.basenameWithoutExtension(_lockFile!.path);
      final savedFile = await FileHelper.savePdfFile(
        bytes: securedBytes,
        fileName: '${baseName}_Protected.pdf',
      );

      setState(() => _isLocking = false);
      if (mounted) {
        _showSuccessDialog('PDF Locked Successfully', savedFile.path);
      }
    } catch (e) {
      setState(() => _isLocking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error locking PDF: $e')));
      }
    }
  }

  Future<void> _pickUnlockFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (res != null && res.files.single.path != null) {
      setState(() => _unlockFile = File(res.files.single.path!));
    }
  }

  Future<void> _unlockPdf() async {
    if (_unlockFile == null || _currentPasswordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a locked PDF and enter its current password.')),
      );
      return;
    }

    setState(() => _isUnlocking = true);

    try {
      final bytes = await _unlockFile!.readAsBytes();
      final unlockedBytes = await PdfSecurityService.unlockPdf(
        inputBytes: bytes,
        password: _currentPasswordController.text.trim(),
      );

      final baseName = p.basenameWithoutExtension(_unlockFile!.path);
      final savedFile = await FileHelper.savePdfFile(
        bytes: unlockedBytes,
        fileName: '${baseName}_Unlocked.pdf',
      );

      setState(() => _isUnlocking = false);
      if (mounted) {
        _showSuccessDialog('Password Removed Successfully', savedFile.path);
      }
    } catch (e) {
      setState(() => _isUnlocking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect password or unable to unlock.')),
        );
      }
    }
  }

  Future<void> _pickMetaFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (res != null && res.files.single.path != null) {
      setState(() {
        _metaFile = File(res.files.single.path!);
        _titleController.text = p.basenameWithoutExtension(res.files.single.path!);
      });
    }
  }

  Future<void> _saveMetadata() async {
    if (_metaFile == null) return;
    setState(() => _isSavingMeta = true);

    try {
      final bytes = await _metaFile!.readAsBytes();
      final updatedBytes = await PdfSecurityService.updateMetadata(
        inputBytes: bytes,
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
      );

      final savedFile = await FileHelper.savePdfFile(
        bytes: updatedBytes,
        fileName: '${_titleController.text.trim().isNotEmpty ? _titleController.text.trim() : "Updated"}.pdf',
      );

      setState(() => _isSavingMeta = false);
      if (mounted) {
        _showSuccessDialog('Document Info Updated', savedFile.path);
      }
    } catch (e) {
      setState(() => _isSavingMeta = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating info: $e')));
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
        title: const Text('Lock & Protect'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          indicatorColor: const Color(0xFF2563EB),
          tabs: const [
            Tab(text: 'Set Password', icon: Icon(Icons.lock)),
            Tab(text: 'Remove Password', icon: Icon(Icons.lock_open)),
            Tab(text: 'Change Info', icon: Icon(Icons.badge)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
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
                                _lockFile != null ? p.basename(_lockFile!.path) : 'No PDF selected',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              const Text('Choose a PDF to encrypt with a password', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickLockFile,
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Choose PDF'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Enter Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        const Text('Anyone opening this PDF will be asked to enter this password', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New Password',
                            hintText: 'Enter a secure password',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isLocking || _lockFile == null ? null : _lockPdf,
                  icon: const Icon(Icons.lock),
                  label: Text(_isLocking ? 'Locking PDF...' : 'Protect PDF with Password'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
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
                                _unlockFile != null ? p.basename(_unlockFile!.path) : 'No PDF selected',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              const Text('Choose a password-locked PDF', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickUnlockFile,
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Choose PDF'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 6),
                        const Text('Enter the password currently locking this document to unlock it', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _currentPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Current Password',
                            hintText: 'Type password to unlock',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isUnlocking || _unlockFile == null ? null : _unlockPdf,
                  icon: const Icon(Icons.lock_open),
                  label: Text(_isUnlocking ? 'Unlocking PDF...' : 'Remove Password & Save'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
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
                                _metaFile != null ? p.basename(_metaFile!.path) : 'No PDF selected',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              const Text('Choose PDF to update title or author name', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickMetaFile,
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Choose PDF'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Document Title',
                            hintText: 'e.g. Invoice 2026',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _authorController,
                          decoration: const InputDecoration(
                            labelText: 'Author Name',
                            hintText: 'e.g. Gaurav',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _isSavingMeta || _metaFile == null ? null : _saveMetadata,
                  icon: const Icon(Icons.save),
                  label: Text(_isSavingMeta ? 'Saving...' : 'Save Updated Info'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
