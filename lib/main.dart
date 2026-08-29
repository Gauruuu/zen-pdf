import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'views/main_navigation_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZenPdfApp());
}

class ZenPdfApp extends StatelessWidget {
  const ZenPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zen PDF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigationShell(),
    );
  }
}
