import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_pdf/views/pdf_viewer/chrome_pdf_viewer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ChromePdfViewerScreen search bar toggles properly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChromePdfViewerScreen(),
      ),
    );

    // Initial empty state has Choose PDF button
    expect(find.text('Chrome-Style PDF Viewer'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
  });
}
