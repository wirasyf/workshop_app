import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Badge status stok: Normal (hijau), Menipis (kuning), Habis (merah)
class StockBadge extends StatelessWidget {
  final int qty;
  final int minQty;
  const StockBadge({super.key, required this.qty, required this.minQty});

  @override
  Widget build(BuildContext context) {
    final (label, color, bgColor) = _getStatus();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  (String, Color, Color) _getStatus() {
    if (qty == 0) return ('Habis', AppColors.error, AppColors.errorLight);
    if (qty <= minQty) return ('Menipis', AppColors.warning, AppColors.warningLight);
    return ('Normal', AppColors.success, AppColors.successLight);
  }
}
