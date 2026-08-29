import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignatureDialog extends StatefulWidget {
  const SignatureDialog({super.key});

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  late SignatureController _controller;
  Color _penColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: _penColor,
      exportBackgroundColor: Colors.transparent,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changeColor(Color color) {
    setState(() {
      _penColor = color;
      _controller = SignatureController(
        penStrokeWidth: 3,
        penColor: color,
        exportBackgroundColor: Colors.transparent,
        points: _controller.points,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Draw Signature',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign your name inside the box below',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Signature(
                  controller: _controller,
                  height: 180,
                  backgroundColor: const Color(0xFFF8FAFC),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Ink Color:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(width: 10),
                ...[Colors.black, const Color(0xFF1E3A8A), const Color(0xFF991B1B)].map((color) {
                  final isSelected = _penColor == color;
                  return GestureDetector(
                    onTap: () => _changeColor(color),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _controller.clear(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (_controller.isNotEmpty) {
                  final Uint8List? data = await _controller.toPngBytes();
                  if (context.mounted) {
                    Navigator.pop(context, data);
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please draw your signature first')),
                  );
                }
              },
              child: const Text('Use Signature'),
            ),
          ],
        ),
      ),
    );
  }
}
