import 'package:intl/intl.dart';

/// Format tanggal untuk locale Indonesia
class DateFormatter {
  DateFormatter._();

  /// 9 Mei 2026
  static String formatLong(DateTime date) =>
      DateFormat('d MMMM yyyy', 'id_ID').format(date);

  /// 09/05/2026
  static String formatShort(DateTime date) =>
      DateFormat('dd/MM/yyyy').format(date);

  /// 09 Mei 2026, 14:30
  static String formatWithTime(DateTime date) =>
      DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);

  /// 14:30
  static String formatTime(DateTime date) =>
      DateFormat('HH:mm').format(date);

  /// Hari ini, Kemarin, atau tanggal
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff < 7) return '$diff hari lalu';
    return formatShort(date);
  }

  /// Awal hari (00:00:00)
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Akhir hari (23:59:59)
  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  /// Awal minggu (Senin)
  static DateTime startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return startOfDay(date.subtract(Duration(days: weekday - 1)));
  }

  /// Awal bulan
  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);
}
