import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ReportUtils {
  ReportUtils._();

  /// Process raw daily sales data for fl_chart
  static List<Map<String, dynamic>> getChartDisplayData(
    List<Map<String, dynamic>> rawData,
    int days,
  ) {
    final now = DateTime.now();
    return List.generate(days, (index) {
      final d = now.subtract(Duration(days: days - 1 - index));
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final hasData = rawData.any(
        (e) => (e['date'] as String).startsWith(dateStr),
      );
      final total = hasData
          ? rawData.firstWhere(
              (e) => (e['date'] as String).startsWith(dateStr),
            )['total']
          : 0.0;
      return {'date': dateStr, 'total': total};
    });
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
