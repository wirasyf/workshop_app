import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

/// Service untuk mengelola penyimpanan file gambar ke Firebase Storage
class FileStorageService {
  FileStorageService._();

  /// Mengonversi gambar ke Base64 untuk disimpan langsung di Firestore
  static Future<String> saveProductImage(File sourceFile) async {
    try {
      if (!await sourceFile.exists()) {
        throw Exception('File lokal tidak ditemukan: ${sourceFile.path}');
      }
      final bytes = await sourceFile.readAsBytes();
      final base64String = base64Encode(bytes);
      // Deteksi format (opsional, kita asumsikan jpeg dari image_picker)
      final extension = p.extension(sourceFile.path).toLowerCase();
      final mimeType = extension == '.png' ? 'image/png' : 'image/jpeg';
      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      print('FileStorageService: Exception konversi base64: $e');
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
    } else if (!urlOrPath.startsWith('data:image')) {
      // Fallback untuk menghapus file lokal (sisa data lama)
      final file = File(urlOrPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    // Jika base64, tidak ada yang perlu dihapus secara fisik
  }
}
