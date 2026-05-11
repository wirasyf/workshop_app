import 'app_database.dart';

/// Seed data untuk testing & demo
class SeedData {
  /// Hapus semua data di database
  static Future<void> clearAll(AppDatabase db) async {
    await db.clearAllData();
  }
}
