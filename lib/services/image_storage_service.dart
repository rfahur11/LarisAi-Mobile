import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageStorageService {
  ImageStorageService._();
  static final ImageStorageService instance = ImageStorageService._();

  String? _cachedDirPath;

  /// Returns the base directory for storing product images
  Future<String> getImageDirectoryPath() async {
    if (_cachedDirPath != null) {
      final cachedDir = Directory(_cachedDirPath!);
      if (await cachedDir.exists()) {
        return _cachedDirPath!;
      }
    }

    String basePath;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      try {
        final supportDir = await getApplicationSupportDirectory();
        basePath = supportDir.path;
      } catch (_) {
        basePath = Directory.current.path;
      }
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      basePath = docDir.path;
    }

    final imagesDir = Directory(p.join(basePath, 'product_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    _cachedDirPath = imagesDir.path;
    return imagesDir.path;
  }

  /// Resolves the absolute File for a stored image filename or path
  Future<File?> getLocalImageFile(String imagePath) async {
    if (imagePath.trim().isEmpty) return null;

    try {
      // If already an absolute path
      final directFile = File(imagePath);
      if (await directFile.exists()) {
        return directFile;
      }

      // Check within product_images directory
      final baseDir = await getImageDirectoryPath();
      final targetFile = File(p.join(baseDir, p.basename(imagePath)));
      if (await targetFile.exists()) {
        return targetFile;
      }
    } catch (e) {
      debugPrint('[ImageStorageService] Error resolving image: $e');
    }

    return null;
  }

  /// Opens file picker to select an image, copies it to app storage, and returns the relative filename
  Future<String?> pickAndSaveProductImage(String productId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final pickedFile = result.files.single;
      final originalPath = pickedFile.path;
      final bytes = pickedFile.bytes;

      String ext = 'jpg';
      if (pickedFile.extension != null && pickedFile.extension!.isNotEmpty) {
        ext = pickedFile.extension!.toLowerCase();
      } else if (originalPath != null) {
        ext = p.extension(originalPath).replaceAll('.', '').toLowerCase();
        if (ext.isEmpty) ext = 'jpg';
      }

      final sanitizedId = productId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'prod_${sanitizedId.isNotEmpty ? sanitizedId : "new"}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final dirPath = await getImageDirectoryPath();
      final destinationFile = File(p.join(dirPath, fileName));

      if (originalPath != null) {
        final sourceFile = File(originalPath);
        if (await sourceFile.exists()) {
          await sourceFile.copy(destinationFile.path);
          return fileName;
        }
      }

      if (bytes != null) {
        await destinationFile.writeAsBytes(bytes);
        return fileName;
      }

      return null;
    } catch (e) {
      debugPrint('[ImageStorageService] Error picking/saving image: $e');
      return null;
    }
  }

  /// Deletes a product image file from disk
  Future<void> deleteProductImage(String imagePath) async {
    if (imagePath.trim().isEmpty) return;
    try {
      final file = await getLocalImageFile(imagePath);
      if (file != null && await file.exists()) {
        await file.delete();
        debugPrint('[ImageStorageService] Deleted image: ${file.path}');
      }
    } catch (e) {
      debugPrint('[ImageStorageService] Error deleting image: $e');
    }
  }

  /// Saves raw image bytes (e.g. from LAN host sync or network upload)
  Future<String?> saveImageBytes(List<int> bytes, String fileName) async {
    try {
      final dirPath = await getImageDirectoryPath();
      final safeName = p.basename(fileName);
      final destFile = File(p.join(dirPath, safeName));
      await destFile.writeAsBytes(bytes);
      return safeName;
    } catch (e) {
      debugPrint('[ImageStorageService] Error saving image bytes: $e');
      return null;
    }
  }
}
