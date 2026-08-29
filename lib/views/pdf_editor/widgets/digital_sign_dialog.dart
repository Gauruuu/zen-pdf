import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class DigitalSignResult {
  final String signerName;
  final String reason;
  final String location;
  final String? contactInfo;
  final Uint8List? certificateBytes;
  final String? certificatePassword;

  DigitalSignResult({
    required this.signerName,
    required this.reason,
    required this.location,
    this.contactInfo,
    this.certificateBytes,
    this.certificatePassword,
  });
}

class DigitalSignDialog extends StatefulWidget {
  const DigitalSignDialog({super.key});

  static Future<DigitalSignResult?> show(BuildContext context) {
    return showDialog<DigitalSignResult>(
      context: context,
      builder: (context) => const DigitalSignDialog(),
    );
  }

  @override
  State<DigitalSignDialog> createState() => _DigitalSignDialogState();
}

class _DigitalSignDialogState extends State<DigitalSignDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Authorized Signer');
  final _reasonController = TextEditingController(text: 'Document Authenticity and Integrity Verified');
  final _locationController = TextEditingController(text: 'India');
  final _contactController = TextEditingController();
  final _certPasswordController = TextEditingController();

  String _certMode = 'instant'; // 'instant' or 'custom'
  String? _certFileName;
  Uint8List? _certBytes;

  final List<String> _reasonSuggestions = [
    'Document Authenticity and Integrity Verified',
    'I have reviewed and approve this document',
    'I agree to the specified terms and conditions',
    'Approved as Authorized Signatory',
    'Certified Copy of Original Record',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _reasonController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    _certPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickCertificateFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pfx', 'p12', 'crt', 'cer', 'pem'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      setState(() {
        _certFileName = result.files.single.name;
        _certBytes = bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified, color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sign PDF Digitally', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  'Add an Adobe Acrobat-compatible digital signature',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Signer Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Signer Full Name *',
                    hintText: 'e.g. Gaurang Dalal or Company Name',
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a signer name' : null,
                ),

                const SizedBox(height: 14),

                // Reason for Signing
                TextFormField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason for Signing *',
                    hintText: 'Select or type a reason',
                    prefixIcon: const Icon(Icons.description_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: PopupMenuButton<String>(
                      icon: const Icon(Icons.arrow_drop_down),
                      onSelected: (val) => setState(() => _reasonController.text = val),
                      itemBuilder: (context) {
                        return _reasonSuggestions.map((r) {
                          return PopupMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)));
                        }).toList();
                      },
                    ),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please provide a reason' : null,
                ),

                const SizedBox(height: 14),

                // Location & Contact
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Location / City',
                          hintText: 'e.g. Akola, India',
                          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _contactController,
                        decoration: InputDecoration(
                          labelText: 'Email / Phone (Optional)',
                          hintText: 'e.g. info@domain.com',
                          prefixIcon: const Icon(Icons.contact_mail_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Certificate Mode
                const Text(
                  'Digital Certificate & Encryption',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 8),

                RadioListTile<String>(
                  value: 'instant',
                  groupValue: _certMode,
                  title: const Text('Instant Digital Certificate (Standard SHA-256)', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Generates standard 2048-bit digital ID automatically', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _certMode = val!),
                ),

                RadioListTile<String>(
                  value: 'custom',
                  groupValue: _certMode,
                  title: const Text('Load Custom Certificate File (.pfx / .p12 / .cer)', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Use your official e-Token or organizational certificate', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _certMode = val!),
                ),

                if (_certMode == 'custom') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickCertificateFile,
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Browse File'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _certFileName ?? 'No certificate file selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: _certFileName != null ? const Color(0xFF059669) : Colors.grey,
                            fontWeight: _certFileName != null ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _certPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Certificate Password',
                      hintText: 'Enter password for .pfx/.p12 file',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(
                context,
                DigitalSignResult(
                  signerName: _nameController.text.trim(),
                  reason: _reasonController.text.trim(),
                  location: _locationController.text.trim(),
                  contactInfo: _contactController.text.trim().isNotEmpty ? _contactController.text.trim() : null,
                  certificateBytes: _certBytes,
                  certificatePassword: _certPasswordController.text.isNotEmpty ? _certPasswordController.text : null,
                ),
              );
            }
          },
          icon: const Icon(Icons.draw, size: 18),
          label: const Text('Sign PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
