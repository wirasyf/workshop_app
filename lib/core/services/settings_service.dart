import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String keyStoreName = 'store_name';
  static const String keyStoreAddress = 'store_address';
  static const String keyStorePhone = 'store_phone';
  static const String keyReceiptFooter = 'receipt_footer';
  static const String keyUserId = 'user_id';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get storeName => _prefs.getString(keyStoreName) ?? 'SpareArt Motor';
  String get storeAddress => _prefs.getString(keyStoreAddress) ?? 'Alamat Toko Belum Diatur';
  String get storePhone => _prefs.getString(keyStorePhone) ?? '-';
  String get receiptFooter => _prefs.getString(keyReceiptFooter) ?? 'Terima Kasih Atas Kunjungan Anda';
  int? get userId => _prefs.getInt(keyUserId);

  Future<void> setStoreInfo(String name, String address, String phone) async {
    await _prefs.setString(keyStoreName, name);
    await _prefs.setString(keyStoreAddress, address);
    await _prefs.setString(keyStorePhone, phone);
  }

  Future<void> setReceiptFooter(String footer) async {
    await _prefs.setString(keyReceiptFooter, footer);
  }

  Future<void> setUserId(int? id) async {
    if (id == null) {
      await _prefs.remove(keyUserId);
    } else {
      await _prefs.setInt(keyUserId, id);
    }
  }
}
