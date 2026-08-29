import 'package:flutter_test/flutter_test.dart';
import 'package:zen_pdf/main.dart';

void main() {
  testWidgets('App renders successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ZenPdfApp());
    expect(find.text('Zen PDF'), findsAtLeastNWidgets(1));
  });
}
