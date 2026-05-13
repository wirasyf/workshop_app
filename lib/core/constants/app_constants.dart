import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Konstanta global aplikasi SpareArt
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'SpareArt Motor';
  static const String appVersion = '1.0.0';
  static const String storeName = 'SpareArt Motor';

  // Supabase
  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');
  static String get supabaseAnonKey =>
      dotenv.get('SUPABASE_ANON_KEY', fallback: '');

  // Database
  static const String dbName = 'spareart_db';


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
