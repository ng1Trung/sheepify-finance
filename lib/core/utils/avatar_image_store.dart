import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class AvatarImageStore {
  static const String _directoryName = 'avatar_images';
  static Directory? _documentsDirectory;
  static Directory? _imageDirectory;
  static Future<void>? _initializeFuture;

  static Future<void> initialize() async {
    if (_imageDirectory != null) return;
    final existingFuture = _initializeFuture;
    if (existingFuture != null) return existingFuture;

    _initializeFuture = _initialize().catchError((Object error) {
      _initializeFuture = null;
      throw error;
    });
    return _initializeFuture!;
  }

  static Future<void> _initialize() async {
    _documentsDirectory = await getApplicationDocumentsDirectory();
    _imageDirectory = Directory(
      path.join(_documentsDirectory!.path, _directoryName),
    );
    if (!await _imageDirectory!.exists()) {
      await _imageDirectory!.create(recursive: true);
    }
  }

  static Future<String> saveFromSourcePath(String sourcePath) async {
    await initialize();
    final source = File(sourcePath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final target = File(path.join(_imageDirectory!.path, fileName));
    await source.copy(target.path);
    return path.join(_directoryName, fileName);
  }

  static File? resolve(String? storedRef) {
    if (storedRef == null || storedRef.isEmpty) return null;
    final documentsDirectory = _documentsDirectory;
    if (documentsDirectory == null) {
      initialize();
      return null;
    }

    if (path.isAbsolute(storedRef)) {
      return File(storedRef);
    }

    return File(path.join(documentsDirectory.path, storedRef));
  }

  static Future<void> deleteStoredRef(String? storedRef) async {
    if (storedRef == null || storedRef.isEmpty || path.isAbsolute(storedRef)) {
      return;
    }

    await initialize();
    final file = resolve(storedRef);
    if (file == null || !path.isWithin(_imageDirectory!.path, file.path)) {
      return;
    }

    if (await file.exists()) {
      await file.delete();
    }
  }
}
