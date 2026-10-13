import 'dart:io';
import 'dart:ui' as ui;
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

  /// Scales down image bytes to max dimension (default 800px) and converts to PNG
  /// to save disk space, prevent memory OOM on mobile, and speed up backup/sync.
  Future<Uint8List> compressImageBytes(Uint8List rawBytes, {int maxDimension = 800}) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(rawBytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final origWidth = descriptor.width;
      final origHeight = descriptor.height;
      descriptor.dispose();
      buffer.dispose();

      // If already small in dimensions and under 250 KB, return as is
      if (origWidth <= maxDimension && origHeight <= maxDimension && rawBytes.lengthInBytes <= 250 * 1024) {
        return rawBytes;
      }

      int? targetW;
      int? targetH;
      if (origWidth >= origHeight) {
        targetW = maxDimension;
      } else {
        targetH = maxDimension;
      }

      final codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      codec.dispose();
      image.dispose();

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('[ImageStorageService] Image compression fallback: $e');
    }
    return rawBytes;
  }

  /// Opens file picker to select an image, compresses it, and saves to app storage
  Future<String?> pickAndSaveProductImage(String productId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final pickedFile = result.files.single;
      Uint8List? rawBytes = pickedFile.bytes;

      if ((rawBytes == null || rawBytes.isEmpty) && pickedFile.path != null) {
        final sourceFile = File(pickedFile.path!);
        if (await sourceFile.exists()) {
          rawBytes = await sourceFile.readAsBytes();
        }
      }

      if (rawBytes == null || rawBytes.isEmpty) {
        return null;
      }

      // Automatically compress to max 800px
      final processedBytes = await compressImageBytes(rawBytes, maxDimension: 800);

      final sanitizedId = productId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = 'prod_${sanitizedId.isNotEmpty ? sanitizedId : "new"}_${DateTime.now().millisecondsSinceEpoch}.png';
      final dirPath = await getImageDirectoryPath();
      final destinationFile = File(p.join(dirPath, fileName));

      await destinationFile.writeAsBytes(processedBytes);
      return fileName;
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

      Uint8List toWrite = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      if (toWrite.lengthInBytes > 400 * 1024) {
        toWrite = await compressImageBytes(toWrite, maxDimension: 800);
      }

      await destFile.writeAsBytes(toWrite);
      return safeName;
    } catch (e) {
      debugPrint('[ImageStorageService] Error saving image bytes: $e');
      return null;
    }
  }
}
