/// Kumpulan validator untuk form input
class Validators {
  Validators._();

  static String? required(String? value, [String field = 'Field']) {
    if (value == null || value.trim().isEmpty) {
      return '$field wajib diisi';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email wajib diisi';
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Format email tidak valid';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';
    if (value.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  static String? numeric(String? value, [String field = 'Field']) {
    if (value == null || value.trim().isEmpty) return '$field wajib diisi';
    if (double.tryParse(value.replaceAll('.', '').replaceAll(',', '.')) == null) {
      return '$field harus berupa angka';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // opsional
    final regex = RegExp(r'^(\+62|62|0)[0-9]{8,13}$');
    if (!regex.hasMatch(value.replaceAll(RegExp(r'[\s-]'), ''))) {
      return 'Format nomor telepon tidak valid';
    }
    return null;
  }

  static String? minLength(String? value, int min, [String field = 'Field']) {
    if (value == null || value.trim().length < min) {
      return '$field minimal $min karakter';
    }
    return null;
  }

  static String? positiveNumber(String? value, [String field = 'Angka']) {
    final numError = numeric(value, field);
    if (numError != null) return numError;
    final num = double.parse(value!.replaceAll('.', '').replaceAll(',', '.'));
    if (num <= 0) return '$field harus lebih dari 0';
    return null;
  }
}
