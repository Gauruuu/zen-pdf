import 'dart:io';
import 'dart:typed_data';
import 'package:gdrm_sdk/gdrm_sdk.dart';
import 'package:path/path.dart' as p;
import '../core/utils/file_helper.dart';
import 'recent_files_service.dart';
import 'sound_service.dart';

class GdrmService {
  /// Fetches persistent hardware key for the current host device
  static Future<String> getDeviceHardwareKey() async {
    try {
      return GdrmDeviceService.getActiveDeviceKey();
    } catch (_) {
      return 'GDRM-HOST-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Checks if binary data represents a valid .gdrm file
  static bool isGdrmFile(Uint8List bytes) {
    return GdrmEngine.isGdrmFile(bytes);
  }

  /// Encrypts and packages raw PDF bytes into a .gdrm container
  static Future<Uint8List> packPdfToGdrm({
    required Uint8List pdfBytes,
    String licensedTo = 'Authorized Reader',
    String copyrightOwner = 'Zen PDF Studio & GDRM Ecosystem',
    String memeSignature = 'CONFIDENTIAL // DO NOT DISTRIBUTE // GDRM PROTECTED',
    String? password,
    String? targetUsername,
    bool lockToCurrentDevice = false,
    String? targetDeviceKey,
    DateTime? chronoLockOpenAt,
    DateTime? riggedExpiry,
    bool allowPrint = false,
    bool membersOnly = false,
    int maxAttempts = 0,
    int maxOpens = 0,
  }) async {
    String deviceKey = '';
    if (lockToCurrentDevice) {
      deviceKey = await getDeviceHardwareKey();
    } else if (targetDeviceKey != null && targetDeviceKey.trim().isNotEmpty) {
      deviceKey = targetDeviceKey.trim();
    }

    final gdrmBytes = GdrmEngine.pack(
      pdfBytes: pdfBytes,
      licensedTo: licensedTo.trim().isNotEmpty ? licensedTo.trim() : 'Authorized Reader',
      copyrightOwner: copyrightOwner.trim().isNotEmpty ? copyrightOwner.trim() : 'Zen PDF User',
      memeSignature: memeSignature.trim().isNotEmpty ? memeSignature.trim() : 'GDRM ZERO-TRUST PROTECTED',
      password: (password != null && password.trim().isNotEmpty) ? password.trim() : '',
      senderDeviceKey: deviceKey,
      targetUsername: (targetUsername != null && targetUsername.trim().isNotEmpty) ? targetUsername.trim() : '',
      openAt: chronoLockOpenAt,
      riggedExpiry: riggedExpiry,
      allowPrint: allowPrint,
      membersOnly: membersOnly,
      maxAttempts: maxAttempts,
      maxOpens: maxOpens,
    );

    return gdrmBytes;
  }

  /// Saves .gdrm bytes to disk and registers with recent files
  static Future<File> saveGdrmFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final baseDir = await FileHelper.getAppDocumentsPath();
    String safeName = fileName.trim();
    if (!safeName.toLowerCase().endsWith('.gdrm')) {
      safeName = '$safeName.gdrm';
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
    await RecentFilesService.addRecentFile(file.path);
    await SoundService.playSuccess();
    return file;
  }

  /// Decrypts a .gdrm package in-memory
  static GdrmParseResult parseGdrm(Uint8List gdrmBytes) {
    return GdrmEngine.parse(gdrmBytes);
  }
}
