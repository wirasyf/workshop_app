import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider untuk memantau status koneksi internet
final connectivityProvider = StreamProvider<bool>((ref) {
  return ConnectivityService.onConnectivityChanged;
});

/// Provider satu kali cek koneksi
final isOnlineProvider = FutureProvider<bool>((ref) {
  return ConnectivityService.isOnline();
});

/// Service pemantau koneksi internet
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  /// Stream perubahan koneksi (true = online, false = offline)
  static Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((results) {
      return results.any((r) => r != ConnectivityResult.none);
    });
  }

  /// Cek apakah saat ini online
  static Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
