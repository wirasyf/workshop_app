import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dnd_markasban_app/main.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  final mode = settings.themeMode;
  return mode == 'dark'
      ? ThemeMode.dark
      : mode == 'system'
      ? ThemeMode.system
      : ThemeMode.light;
});

class SettingsService extends ChangeNotifier {
  static const String keyStoreName = 'store_name';
  static const String keyStoreAddress = 'store_address';
  static const String keyStorePhone = 'store_phone';
  static const String keyReceiptFooter = 'receipt_footer';
  static const String keyUserId = 'user_id';
  static const String keyUserName = 'user_name';
  static const String keyUserRole = 'user_role';
  static const String keyThemeMode = 'theme_mode';

  SharedPreferences? _prefs;

  bool get isInitialized => _prefs != null;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('✅ SettingsService initialized');
  }

  SharedPreferences get _safePrefs {
    assert(
      _prefs != null,
      'SettingsService.init() belum dipanggil.',
    );
    return _prefs!;
  }

  String get storeName => _prefs?.getString(keyStoreName) ?? 'D&D Markas Ban';
  String get storeAddress =>
      _prefs?.getString(keyStoreAddress) ?? 'Alamat Toko Belum Diatur';
  String get storePhone => _prefs?.getString(keyStorePhone) ?? '-';
  String get receiptFooter =>
      _prefs?.getString(keyReceiptFooter) ??
      'Terima Kasih Atas Kunjungan Anda';
  String? get userId => _prefs?.getString(keyUserId);
  String? get userName => _prefs?.getString(keyUserName);
  String? get userRole => _prefs?.getString(keyUserRole);
  String get themeMode => _prefs?.getString(keyThemeMode) ?? 'light';

  Future<void> setStoreInfo(
    String name,
    String address,
    String phone,
  ) async {
    await _safePrefs.setString(keyStoreName, name);
    await _safePrefs.setString(keyStoreAddress, address);
    await _safePrefs.setString(keyStorePhone, phone);
    notifyListeners();
  }

  Future<void> setReceiptFooter(String footer) async {
    await _safePrefs.setString(keyReceiptFooter, footer);
    notifyListeners();
  }

  Future<void> setUserId(String? id, {bool notify = true}) async {
    if (id == null) {
      await _safePrefs.remove(keyUserId);
    } else {
      await _safePrefs.setString(keyUserId, id);
    }
    if (notify) notifyListeners();
  }

  Future<void> setUserName(String? name, {bool notify = true}) async {
    if (name == null) {
      await _safePrefs.remove(keyUserName);
    } else {
      await _safePrefs.setString(keyUserName, name);
    }
    if (notify) notifyListeners();
  }

  Future<void> setUserRole(String? role, {bool notify = true}) async {
    if (role == null) {
      await _safePrefs.remove(keyUserRole);
    } else {
      await _safePrefs.setString(keyUserRole, role);
    }
    if (notify) notifyListeners();
  }

  /// Menyimpan info sesi user secara persisten ke SharedPreferences.
  /// Session ini digunakan untuk restore login setelah app ditutup.
  Future<void> saveUserSession({
    required String userId,
    required String userName,
    required String userRole,
    // sessionId dihapus — tidak lagi dipakai untuk single-session enforcement
  }) async {
    await setUserId(userId, notify: false);
    await setUserName(userName, notify: false);
    await setUserRole(userRole, notify: false);
    notifyListeners();
    debugPrint(
      '💾 Session tersimpan: userId=$userId, role=$userRole',
    );
  }

  Future<void> clearUserSession() async {
    await _safePrefs.remove(keyUserId);
    await _safePrefs.remove(keyUserName);
    await _safePrefs.remove(keyUserRole);
    notifyListeners();
    debugPrint('🗑️ Session dihapus dari SharedPreferences');
  }

  Future<void> setThemeMode(String mode) async {
    await _safePrefs.setString(keyThemeMode, mode);
    notifyListeners();
  }
}
