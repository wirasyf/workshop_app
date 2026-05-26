import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dnd_markasban_app/main.dart';

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
  static const String keyUserName = 'user_name';
  static const String keyUserRole = 'user_role';
  static const String keyThemeMode = 'theme_mode';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get storeName => _prefs.getString(keyStoreName) ?? 'D&D Markas Ban';
  String get storeAddress => _prefs.getString(keyStoreAddress) ?? 'Alamat Toko Belum Diatur';
  String get storePhone => _prefs.getString(keyStorePhone) ?? '-';
  String get receiptFooter => _prefs.getString(keyReceiptFooter) ?? 'Terima Kasih Atas Kunjungan Anda';
  String? get userId => _prefs.getString(keyUserId);
  String? get userName => _prefs.getString(keyUserName);
  String? get userRole => _prefs.getString(keyUserRole);
  String get themeMode => _prefs.getString(keyThemeMode) ?? 'light';

  Future<void> setStoreInfo(String name, String address, String phone) async {
    await _prefs.setString(keyStoreName, name);
    await _prefs.setString(keyStoreAddress, address);
    await _prefs.setString(keyStorePhone, phone);
  }

  Future<void> setReceiptFooter(String footer) async {
    await _prefs.setString(keyReceiptFooter, footer);
  }

  Future<void> setUserId(String? id) async {
    if (id == null) {
      await _prefs.remove(keyUserId);
    } else {
      await _prefs.setString(keyUserId, id);
    }
  }

  Future<void> setUserName(String? name) async {
    if (name == null) {
      await _prefs.remove(keyUserName);
    } else {
      await _prefs.setString(keyUserName, name);
    }
  }

  Future<void> setUserRole(String? role) async {
    if (role == null) {
      await _prefs.remove(keyUserRole);
    } else {
      await _prefs.setString(keyUserRole, role);
    }
  }

  Future<void> clearUserSession() async {
    await _prefs.remove(keyUserId);
    await _prefs.remove(keyUserName);
    await _prefs.remove(keyUserRole);
  }

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(keyThemeMode, mode);
  }

}
