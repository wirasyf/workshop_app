import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spareart_app/main.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  final mode = settings.themeMode;
  return mode == 'dark' ? ThemeMode.dark : mode == 'system' ? ThemeMode.system : ThemeMode.light;
});

class SettingsService {
  static const String keyStoreName = 'store_name';
  static const String keyStoreAddress = 'store_address';
  static const String keyStorePhone = 'store_phone';
  static const String keyReceiptFooter = 'receipt_footer';
  static const String keyUserId = 'user_id';
  static const String keyThemeMode = 'theme_mode';
  static const String keyReadNotifications = 'read_notifications';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get storeName => _prefs.getString(keyStoreName) ?? 'SpareArt Motor';
  String get storeAddress => _prefs.getString(keyStoreAddress) ?? 'Alamat Toko Belum Diatur';
  String get storePhone => _prefs.getString(keyStorePhone) ?? '-';
  String get receiptFooter => _prefs.getString(keyReceiptFooter) ?? 'Terima Kasih Atas Kunjungan Anda';
  int? get userId => _prefs.getInt(keyUserId);
  String get themeMode => _prefs.getString(keyThemeMode) ?? 'light';

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

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(keyThemeMode, mode);
  }

  List<String> get readNotifications => _prefs.getStringList(keyReadNotifications) ?? [];

  Future<void> addReadNotification(String id) async {
    final current = readNotifications;
    if (!current.contains(id)) {
      current.add(id);
      await _prefs.setStringList(keyReadNotifications, current);
    }
  }

  Future<void> setReadNotifications(List<String> ids) async {
    await _prefs.setStringList(keyReadNotifications, ids);
  }
}
