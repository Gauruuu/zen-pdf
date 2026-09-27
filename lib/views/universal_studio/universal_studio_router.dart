import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/utils/file_helper.dart';
import '../../services/recent_files_service.dart';
import '../pdf_viewer/chrome_pdf_viewer_screen.dart';
import '../gdrm/gdrm_viewer_screen.dart';
import 'code_studio_screen.dart';
import 'html_studio_screen.dart';
import 'presentation_studio_screen.dart';
import 'sheet_studio_screen.dart';
import 'word_studio_screen.dart';

class UniversalStudioRouter {
  /// Opens a file picker accepting any file format and automatically routes to the matching studio
  static Future<void> pickAndOpenAnyFile(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final path = result.files.single.path!;
        if (!context.mounted) return;
        await openFileInStudio(context, path);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Opens a specific file path in its corresponding studio editor or viewer
  static Future<void> openFileInStudio(
    BuildContext context,
    String filePath, {
    bool isExternalIntent = false,
  }) async {
    final ext = FileHelper.getFileExtension(filePath).toLowerCase();
    await RecentFilesService.addRecentFile(filePath);

    if (!context.mounted) return;

    if (ext == 'gdrm') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GdrmViewerScreen(
            filePath: filePath,
            isExternalIntent: isExternalIntent,
          ),
        ),
      );
    } else if (ext == 'docx' || ext == 'doc' || ext == 'rtf' || ext == 'odt') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WordStudioScreen(
            initialFilePath: filePath,
            isExternalIntent: isExternalIntent,
          ),
        ),
      );
    } else if (ext == 'xlsx' || ext == 'xls' || ext == 'csv' || ext == 'tsv') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SheetStudioScreen(
            initialFilePath: filePath,
            isExternalIntent: isExternalIntent,
          ),
        ),
      );
    } else if (ext == 'pptx' || ext == 'ppt') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PresentationStudioScreen(
            initialFilePath: filePath,
            isExternalIntent: isExternalIntent,
          ),
        ),
      );
    } else if (ext == 'html' || ext == 'htm') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HtmlStudioScreen(
            initialFilePath: filePath,
            isExternalIntent: isExternalIntent,
          ),
        ),
      );
    } else if (ext == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChromePdfViewerScreen(
            initialFilePath: filePath,
            isExternalIntent: isExternalIntent,
          ),
        ),
      );
    } else {
      // All other files (JSON, XML, Code, TXT, Markdown, YAML, SQL, etc.)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CodeStudioScreen(
            initialFilePath: filePath,
            isExternalIntent: isExternalIntent,
          ),
        ),
      );
    }
  }

  /// Creates a new document from scratch
  static void createNewDocument(BuildContext context, {required String format}) {
    switch (format.toLowerCase()) {
      case 'word':
      case 'docx':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WordStudioScreen()));
        break;
      case 'sheet':
      case 'excel':
      case 'xlsx':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SheetStudioScreen()));
        break;
      case 'presentation':
      case 'pptx':
      case 'slides':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PresentationStudioScreen()));
        break;
      case 'html':
      case 'web':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const HtmlStudioScreen()));
        break;
      case 'code':
      case 'text':
      default:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CodeStudioScreen()));
        break;
    }
  }
}
