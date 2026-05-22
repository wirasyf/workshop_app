import 'package:flutter/material.dart';
import '../enums/report_period.dart';

class DatePickerUtils {
  DatePickerUtils._();

  static Future<DateTime?> pickDate(BuildContext context, ReportPeriod period, DateTime current) async {
    if (period == ReportPeriod.daily) {
      return await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
    } else {
      return await _showMonthYearPicker(context, period, current);
    }
  }

  static Future<DateTime?> _showMonthYearPicker(BuildContext context, ReportPeriod period, DateTime current) async {
    int tempMonth = current.month;
    int tempYear = current.year;

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(period == ReportPeriod.weekly ? 'Pilih Bulan & Tahun' : 'Pilih Tahun'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (period == ReportPeriod.weekly) ...[
                DropdownButtonFormField<int>(
                  value: tempMonth,
                  decoration: const InputDecoration(labelText: 'Bulan'),
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i]))),
                  onChanged: (v) { if (v != null) setState(() => tempMonth = v); },
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<int>(
                value: tempYear,
                decoration: const InputDecoration(labelText: 'Tahun'),
                items: List.generate(15, (i) {
                  final y = DateTime.now().year - 7 + i;
                  return DropdownMenuItem(value: y, child: Text('$y'));
                }),
                onChanged: (v) { if (v != null) setState(() => tempYear = v); },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, DateTime(tempYear, tempMonth, 1)),
              child: const Text('Pilih'),
            ),
          ],
        ),
      ),
    );
  }

  static String formatSelectedDate(ReportPeriod period, DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    switch (period) {
      case ReportPeriod.daily:
        return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
      case ReportPeriod.weekly:
        return '${months[date.month - 1]} ${date.year}';
      case ReportPeriod.monthly:
      case ReportPeriod.yearly:
        return '${date.year}';
    }
  }
}
