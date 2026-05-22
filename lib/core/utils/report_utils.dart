import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../enums/report_period.dart';

class ReportUtils {
  ReportUtils._();

  /// Process raw daily sales data for fl_chart
  static List<Map<String, dynamic>> getChartDisplayData(
    List<Map<String, dynamic>> rawData,
    ReportPeriod period,
    DateTime selectedDate,
  ) {
    if (period == ReportPeriod.daily) {
      return List.generate(7, (index) {
        final d = selectedDate.subtract(Duration(days: 6 - index));
        final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final label = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
        final hasData = rawData.any((e) => (e['date'] as String).startsWith(dateStr));
        final total = hasData ? rawData.firstWhere((e) => (e['date'] as String).startsWith(dateStr))['total'] : 0.0;
        return {'date': dateStr, 'label': label, 'total': total};
      });
    }

    if (period == ReportPeriod.weekly) {
      final int daysInMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
      final int numWeeks = (daysInMonth / 7).ceil();
      return List.generate(numWeeks, (index) {
        final startDay = index * 7 + 1;
        final endDay = (index + 1) * 7;
        final actualEndDay = endDay > daysInMonth ? daysInMonth : endDay;
        
        double total = 0.0;
        for (final row in rawData) {
          final dateStr = row['date'] as String; // YYYY-MM-DD
          if (dateStr.isEmpty) continue;
          final d = DateTime.tryParse(dateStr);
          if (d != null && d.year == selectedDate.year && d.month == selectedDate.month && d.day >= startDay && d.day <= actualEndDay) {
            total += (row['total'] as num).toDouble();
          }
        }
        return {'date': 'Week ${index + 1}', 'label': 'Mg ${index + 1}', 'total': total};
      });
    }

    if (period == ReportPeriod.monthly) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return List.generate(12, (index) {
        double total = 0.0;
        for (final row in rawData) {
          final dateStr = row['date'] as String;
          if (dateStr.isEmpty) continue;
          final d = DateTime.tryParse(dateStr);
          if (d != null && d.year == selectedDate.year && d.month == (index + 1)) {
            total += (row['total'] as num).toDouble();
          }
        }
        return {'date': months[index], 'label': months[index], 'total': total};
      });
    }

    if (period == ReportPeriod.yearly) {
      return List.generate(7, (index) {
        final year = selectedDate.year - 6 + index;
        double total = 0.0;
        for (final row in rawData) {
          final dateStr = row['date'] as String;
          if (dateStr.isEmpty) continue;
          final d = DateTime.tryParse(dateStr);
          if (d != null && d.year == year) {
            total += (row['total'] as num).toDouble();
          }
        }
        return {'date': year.toString(), 'label': year.toString(), 'total': total};
      });
    }

    return [];
  }

  /// Calculate max Y for chart with padding
  static double getChartMaxY(List<Map<String, dynamic>> displayData) {
    final maxSales = displayData.fold<double>(0, (prev, e) {
      final total = ((e['total'] as num?)?.toDouble() ?? 0) / 1000;
      return total > prev ? total : prev;
    });
    return maxSales > 0 ? maxSales * 1.2 : 1000.0;
  }

  /// Build Bar Chart Rod Data
  static BarChartRodData buildBarRod({
    required double value,
    required double maxY,
    required double width,
    required double radius,
    required Color backgroundBarColor,
  }) {
    return BarChartRodData(
      toY: value / 1000,
      gradient: const LinearGradient(
        colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ),
      width: width,
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      backDrawRodData: BackgroundBarChartRodData(
        show: true,
        toY: maxY,
        color: backgroundBarColor,
      ),
    );
  }
}
