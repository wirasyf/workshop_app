import 'package:flutter_test/flutter_test.dart';
import 'package:dnd_markasban_app/core/services/password_service.dart';

void main() {
  group('PasswordService', () {
    test('hashPassword harus menghasilkan hash format salt:digest', () {
      final password = 'mySecretPassword123';
      final hash = PasswordService.hashPassword(password);

      expect(hash, contains(':'));
      final parts = hash.split(':');
      expect(parts.length, 2);
      expect(parts[0].length, greaterThanOrEqualTo(22)); // base64url 16 bytes
      expect(parts[1].length, 64); // sha256 hex
    });

    test(
      'hashPassword dengan salt spesifik harus menghasilkan output deterministik',
      () {
        final password = 'password123';
        final salt = 'testSalt123';

        final hash1 = PasswordService.hashPassword(password, salt: salt);
        final hash2 = PasswordService.hashPassword(password, salt: salt);

        expect(hash1, equals(hash2));
      },
    );

    test(
      'verifyPassword harus mengembalikan true untuk password yang benar',
      () {
        final password = 'mySecretPassword123';
        final hash = PasswordService.hashPassword(password);

        final isValid = PasswordService.verifyPassword(password, hash);
        expect(isValid, isTrue);
      },
    );

    test(
      'verifyPassword harus mengembalikan false untuk password yang salah',
      () {
        final password = 'mySecretPassword123';
        final hash = PasswordService.hashPassword(password);

        final isValid = PasswordService.verifyPassword('wrongPassword', hash);
        expect(isValid, isFalse);
      },
    );

    test(
      'verifyPassword harus mendukung backward-compatibility dengan plain text',
      () {
        final plainTextPassword = 'legacyPassword123';

        // Karena format tidak ada ":" dan tidak 64 karakter (bukan hash valid),
        // maka sistem akan membandingkan langsung sebagai plain text.
        final isValid = PasswordService.verifyPassword(
          'legacyPassword123',
          plainTextPassword,
        );
        final isInvalid = PasswordService.verifyPassword(
          'wrongPassword',
          plainTextPassword,
        );

        expect(isValid, isTrue);
        expect(isInvalid, isFalse);
      },
    );

    test('isHashed harus mendeteksi format hash dengan benar', () {
      final hashed = PasswordService.hashPassword('test');
      expect(PasswordService.isHashed(hashed), isTrue);

      final plain = 'password123';
      expect(PasswordService.isHashed(plain), isFalse);

      final invalidFormat1 = 'saltWithoutDigest';
      expect(PasswordService.isHashed(invalidFormat1), isFalse);

      final invalidFormat2 = 'salt:not64chars';
      expect(PasswordService.isHashed(invalidFormat2), isFalse);

      // 64 karakter tapi bukan hex
      final invalidFormat3 =
          'salt:zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz';
      expect(PasswordService.isHashed(invalidFormat3), isFalse);
    });
  });
}
