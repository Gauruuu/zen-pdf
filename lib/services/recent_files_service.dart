import 'dart:io';
import '../core/utils/file_helper.dart';
import '../models/recent_file.dart';
import 'package:path/path.dart' as p;

class RecentFilesService {
  static Future<List<RecentFile>> getRecentFiles() async {
    try {
      final docPath = await FileHelper.getAppDocumentsPath();
      final dir = Directory(docPath);
      if (!await dir.exists()) return [];

      final files = await dir.list().toList();
      final List<RecentFile> recentFiles = [];

      for (final entity in files) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          final stat = await entity.stat();
          recentFiles.add(
            RecentFile(
              path: entity.path,
              name: p.basename(entity.path),
              sizeInBytes: stat.size,
              modifiedDate: stat.modified,
            ),
          );
        }
      }

      recentFiles.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
      return recentFiles;
    } catch (e) {
      return [];
    }
  }

  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<File?> renameFile(String filePath, String newName) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      String safeName = newName.trim();
      if (!safeName.toLowerCase().endsWith('.pdf')) {
        safeName = '$safeName.pdf';
      }
      safeName = safeName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      final dir = p.dirname(filePath);
      final newPath = p.join(dir, safeName);
      return await file.rename(newPath);
    } catch (_) {
      return null;
    }
  }
}
