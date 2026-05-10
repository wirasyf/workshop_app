import 'package:intl/intl.dart';

/// Format angka ke format Rupiah Indonesia
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _formatterDecimal = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 2,
  );

  static final _compactFormatter = NumberFormat.compactCurrency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Format ke Rupiah tanpa desimal: Rp 150.000
  static String format(num value) => _formatter.format(value);

  /// Format ke Rupiah dengan desimal: Rp 150.000,50
  static String formatDecimal(num value) => _formatterDecimal.format(value);

  /// Format compact: Rp 1,5jt
  static String formatCompact(num value) => _compactFormatter.format(value);

  /// Parse string Rupiah ke double
  static double parse(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Format angka biasa dengan pemisah ribuan: 150.000
  static String formatNumber(num value) {
    return NumberFormat('#,###', 'id_ID').format(value);
  }
}
