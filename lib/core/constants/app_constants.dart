/// Konstanta global aplikasi SpareArt
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'SpareArt Motor';
  static const String appVersion = '1.0.0';
  static const String storeName = 'SpareArt Motor';

  // Supabase
  static const String supabaseUrl = 'https://fnygvetwksousfdjbwwh.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZueWd2ZXR3a3NvdXNmZGpid3doIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzMjEwNzQsImV4cCI6MjA5Mzg5NzA3NH0.tRA396K3XBGbtR8OrjCBoL_QUP7q-H4riitehvGptXw';

  // Database
  static const String dbName = 'spareart_db';

  // Roles
  static const String roleOwner = 'owner';
  static const String roleKasir = 'kasir';

  // Stock thresholds
  static const int stockCriticalThreshold = 0;

  // Currency
  static const String currencySymbol = 'Rp';
  static const String currencyLocale = 'id_ID';

  // Pagination
  static const int defaultPageSize = 20;

  // Receipt
  static const int receiptWidth = 32;
}
