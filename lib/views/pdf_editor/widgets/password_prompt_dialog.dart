import 'package:flutter/material.dart';

class PasswordPromptDialog extends StatefulWidget {
  final String fileName;
  final String? errorMessage;

  const PasswordPromptDialog({
    super.key,
    required this.fileName,
    this.errorMessage,
  });

  static Future<String?> show(BuildContext context, {required String fileName, String? errorMessage}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PasswordPromptDialog(fileName: fileName, errorMessage: errorMessage),
    );
  }

  @override
  State<PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<PasswordPromptDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.errorMessage;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final pwd = _passwordController.text.trim();
    if (pwd.isEmpty) {
      setState(() => _error = 'Please enter the PDF password');
      return;
    }
    Navigator.pop(context, pwd);
  }

  @override
  Widget build(BuildContext context) {
    final isAadhaar = widget.fileName.toLowerCase().contains('aadhaar');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_outline, color: Color(0xFF2563EB), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Password Protected PDF',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            const Text(
              'This document is locked with a password. Please enter the password to open and view it.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'PDF Password',
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.key, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (isAadhaar) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: Color(0xFFB45309), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aadhaar Password Format:\nFirst 4 letters of your Name in CAPITAL + Year of Birth (e.g. GAUR1995)',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Unlock PDF'),
        ),
      ],
    );
  }
}
