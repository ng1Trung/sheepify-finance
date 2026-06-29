import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class TransactionImageStore {
  static const String _directoryName = 'transaction_images';
  static late final Directory _documentsDirectory;
  static late final Directory _imageDirectory;

  static Future<void> initialize() async {
    _documentsDirectory = await getApplicationDocumentsDirectory();
    _imageDirectory = Directory(
      path.join(_documentsDirectory.path, _directoryName),
    );
    if (!await _imageDirectory.exists()) {
      await _imageDirectory.create(recursive: true);
    }
  }

  static Future<String> saveFromSourcePath(String sourcePath) async {
    final source = File(sourcePath);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${path.basename(sourcePath)}';
    final target = File(path.join(_imageDirectory.path, fileName));
    await source.copy(target.path);
    return path.join(_directoryName, fileName);
  }

  static Future<String> saveBytesFromBackup(
    String preferredFileName,
    List<int> bytes,
  ) async {
    await initialize();
    final fileName = await _availableFileName(preferredFileName);
    final target = File(path.join(_imageDirectory.path, fileName));
    await target.writeAsBytes(bytes, flush: true);
    return path.join(_directoryName, fileName);
  }

  static File? resolve(String? storedRef) {
    if (storedRef == null || storedRef.isEmpty) return null;

    if (path.isAbsolute(storedRef)) {
      return File(storedRef);
    }

    return File(path.join(_documentsDirectory.path, storedRef));
  }

  static Future<String?> migrateLegacyRef(String? storedRef) async {
    if (storedRef == null || storedRef.isEmpty || !path.isAbsolute(storedRef)) {
      return storedRef;
    }

    final legacyFile = File(storedRef);
    if (!await legacyFile.exists()) return storedRef;

    final currentDocumentsPath = _documentsDirectory.path;
    if (path.isWithin(currentDocumentsPath, legacyFile.path)) {
      final relativePath = path.relative(
        legacyFile.path,
        from: currentDocumentsPath,
      );
      if (relativePath.startsWith('$_directoryName${path.separator}')) {
        return relativePath;
      }
    }

    return saveFromSourcePath(legacyFile.path);
  }

  static Future<String> _availableFileName(String preferredFileName) async {
    final sanitized = _sanitizeFileName(preferredFileName);
    final candidate = File(path.join(_imageDirectory.path, sanitized));
    if (!await candidate.exists()) return sanitized;

    final extension = path.extension(sanitized);
    final basename = path.basenameWithoutExtension(sanitized);
    return '${basename}_${DateTime.now().microsecondsSinceEpoch}$extension';
  }

  static String _sanitizeFileName(String preferredFileName) {
    final normalized = preferredFileName.replaceAll('\\', '/');
    final basename = path.basename(normalized).trim();
    final safeName = basename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return safeName.isEmpty
        ? '${DateTime.now().microsecondsSinceEpoch}.jpg'
        : safeName;
  }

  static Future<void> deleteAll() async {
    await initialize();
    if (await _imageDirectory.exists()) {
      await _imageDirectory.delete(recursive: true);
    }
  }
}
