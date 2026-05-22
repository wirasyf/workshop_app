import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Service untuk hashing dan verifikasi password
/// Format hash: "salt:sha256digest"
/// Backward-compatible dengan plain text password (legacy)
class PasswordService {
  PasswordService._();

  /// Hash password dengan salt random
  /// Returns format: "base64salt:sha256hex"
  static String hashPassword(String password, {String? salt}) {
    final s = salt ?? _generateSalt();
    final bytes = utf8.encode('$s:$password');
    final digest = sha256.convert(bytes);
    return '$s:${digest.toString()}';
  }

  /// Verifikasi password terhadap hash
  /// Mendukung backward-compatible: jika hash bukan format "salt:digest",
  /// maka dianggap plain text (legacy) dan dibandingkan langsung.
  static bool verifyPassword(String password, String storedHash) {
    if (!_isHashedFormat(storedHash)) {
      // Legacy plain text — direct comparison
      return password == storedHash;
    }
    final salt = storedHash.split(':').first;
    final rehash = hashPassword(password, salt: salt);
    return rehash == storedHash;
  }

  /// Cek apakah password sudah dalam format hashed (salt:digest)
  /// Format valid: base64salt (22+ chars) : sha256hex (64 chars)
  static bool isHashed(String passwordHash) {
    return _isHashedFormat(passwordHash);
  }

  static bool _isHashedFormat(String value) {
    if (!value.contains(':')) return false;
    final parts = value.split(':');
    if (parts.length != 2) return false;
    // SHA-256 digest selalu 64 karakter hex
    return parts[1].length == 64 && _isHex(parts[1]);
  }

  static bool _isHex(String value) {
    return RegExp(r'^[0-9a-f]+$').hasMatch(value);
  }

  /// Generate salt acak 16 bytes, encoded sebagai base64url
  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
