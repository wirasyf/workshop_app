import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Service untuk mengelola penyimpanan file gambar secara lokal
class FileStorageService {
  FileStorageService._();

  /// Menyimpan gambar ke direktori aplikasi secara permanen
  static Future<String> saveProductImage(File sourceFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'product_images'));
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final extension = p.extension(sourceFile.path);
      final fileName = '${const Uuid().v4()}$extension';
      final targetPath = p.join(imagesDir.path, fileName);
      
      final savedFile = await sourceFile.copy(targetPath);
      return savedFile.path;
    } catch (e) {
      rethrow;
    }
  }

  /// Menghapus gambar jika produk dihapus
  static Future<void> deleteImage(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
