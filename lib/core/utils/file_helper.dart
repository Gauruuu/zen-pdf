import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/sound_service.dart';

class FileHelper {
  static Future<String> getAppDocumentsPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory(p.join(dir.path, 'ZenPDF_Documents'));
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return pdfDir.path;
  }

  static Future<File> savePdfFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final baseDir = await getAppDocumentsPath();
    String safeName = fileName.trim();
    if (!safeName.contains('.')) {
      safeName = '$safeName.pdf';
    }
    safeName = safeName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    
    final ext = p.extension(safeName);
    final nameWithoutExt = p.basenameWithoutExtension(safeName);
    
    String finalPath = p.join(baseDir, safeName);
    int counter = 1;
    while (await File(finalPath).exists()) {
      finalPath = p.join(baseDir, '${nameWithoutExt}_$counter$ext');
      counter++;
    }
    
    final file = File(finalPath);
    await file.writeAsBytes(bytes);
    
    // Play completion sound effect
    await SoundService.playSuccess();
    
    return file;
  }

  static Future<void> openFile(String filePath) async {
    await OpenFilex.open(filePath);
  }

  static Future<void> shareFile(String filePath, {String? text}) async {
    final xFile = XFile(filePath);
    await SharePlus.instance.share(
      ShareParams(
        files: [xFile],
        text: text ?? 'Here is your PDF document created with ZenPDF.',
      ),
    );
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes > 0) ? (bytes.toString().length - 1) ~/ 3 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double num = bytes / (1 << (i * 10));
    return '${num.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
