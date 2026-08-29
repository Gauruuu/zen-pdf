import 'package:flutter/material.dart';

class WatermarkDialog extends StatefulWidget {
  const WatermarkDialog({super.key});

  @override
  State<WatermarkDialog> createState() => _WatermarkDialogState();
}

class _WatermarkDialogState extends State<WatermarkDialog> {
  final _textController = TextEditingController(text: 'CONFIDENTIAL');
  double _opacity = 0.25;

  final List<String> _presets = ['CONFIDENTIAL', 'DRAFT', 'COPY', 'APPROVED', 'URGENT'];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add Watermark',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Places a light text across the center of your page',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Watermark Text',
                hintText: 'Enter word or phrase',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _presets.map((preset) {
                return ActionChip(
                  label: Text(preset, style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() => _textController.text = preset),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Visibility:', style: TextStyle(fontWeight: FontWeight.w500)),
                Expanded(
                  child: Slider(
                    value: _opacity,
                    min: 0.1,
                    max: 0.8,
                    divisions: 7,
                    label: '${(_opacity * 100).toInt()}%',
                    onChanged: (val) => setState(() => _opacity = val),
                  ),
                ),
                Text('${(_opacity * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  Navigator.pop(context, {
                    'text': _textController.text.trim(),
                    'opacity': _opacity,
                  });
                }
              },
              child: const Text('Apply Watermark'),
            ),
          ],
        ),
      ),
    );
  }
}
