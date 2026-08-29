import 'package:flutter/material.dart';

class TextBoxDialogResult {
  final String text;
  final double fontSize;
  final Color textColor;
  final bool coverBackground; // White background to replace text
  final bool isBold;

  TextBoxDialogResult({
    required this.text,
    required this.fontSize,
    required this.textColor,
    required this.coverBackground,
    required this.isBold,
  });
}

class TextBoxDialog extends StatefulWidget {
  final String initialText;
  final bool isWordReplacement;

  const TextBoxDialog({
    super.key,
    this.initialText = '',
    this.isWordReplacement = false,
  });

  @override
  State<TextBoxDialog> createState() => _TextBoxDialogState();
}

class _TextBoxDialogState extends State<TextBoxDialog> {
  late TextEditingController _textController;
  double _fontSize = 14.0;
  Color _textColor = Colors.black;
  bool _coverBackground = false;
  bool _isBold = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _coverBackground = widget.isWordReplacement;
  }

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
        width: 420,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isWordReplacement ? 'Replace Word / Text' : 'Add Text Box',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _textController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Type text here...',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Text Size:', style: TextStyle(fontWeight: FontWeight.w500)),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 8.0,
                    max: 36.0,
                    divisions: 14,
                    label: '${_fontSize.toInt()} pt',
                    onChanged: (val) => setState(() => _fontSize = val),
                  ),
                ),
                Text('${_fontSize.toInt()} pt', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              children: [
                const Text('Color:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 10),
                ...[Colors.black, const Color(0xFF1E3A8A), const Color(0xFFB91C1C), const Color(0xFF047857)].map((color) {
                  final isSelected = _textColor == color;
                  return GestureDetector(
                    onTap: () => setState(() => _textColor = color),
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
                FilterChip(
                  label: const Text('Bold'),
                  selected: _isBold,
                  onSelected: (val) => setState(() => _isBold = val),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cover text underneath with white box', style: TextStyle(fontSize: 13)),
              subtitle: const Text('Useful for correcting typos or replacing words', style: TextStyle(fontSize: 11, color: Colors.grey)),
              value: _coverBackground,
              onChanged: (val) => setState(() => _coverBackground = val ?? false),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  Navigator.pop(
                    context,
                    TextBoxDialogResult(
                      text: _textController.text,
                      fontSize: _fontSize,
                      textColor: _textColor,
                      coverBackground: _coverBackground,
                      isBold: _isBold,
                    ),
                  );
                }
              },
              child: const Text('Add to Page'),
            ),
          ],
        ),
      ),
    );
  }
}
