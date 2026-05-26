import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Service untuk mengelola penyimpanan file gambar ke Firebase Storage
class FileStorageService {
  FileStorageService._();

  /// Menyimpan gambar ke Firebase Storage secara permanen
  static Future<String> saveProductImage(File sourceFile) async {
    try {
      final extension = p.extension(sourceFile.path);
      final fileName = '${const Uuid().v4()}$extension';
      
      final storageRef = FirebaseStorage.instance.ref().child('product_images').child(fileName);
      await storageRef.putFile(sourceFile);
      
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// Menghapus gambar jika produk dihapus
  static Future<void> deleteImage(String urlOrPath) async {
    if (urlOrPath.startsWith('http')) {
      try {
        final storageRef = FirebaseStorage.instance.refFromURL(urlOrPath);
        await storageRef.delete();
      } catch (e) {
        // Abaikan error jika gambar tidak ditemukan di Storage
      }
    } else {
      // Fallback untuk menghapus file lokal (sisa data lama)
      final file = File(urlOrPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
