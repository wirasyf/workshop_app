import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';

class ReceiptWidget extends StatelessWidget {
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final String invoiceNo;
  final String? cashierName;
  final DateTime date;
  final List<ReceiptItem> items;
  final double total;
  final double paid;
  final double change;
  final String footer;
  final bool showSuccessIcon;

  const ReceiptWidget({
    super.key,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.invoiceNo,
    this.cashierName,
    required this.date,
    required this.items,
    required this.total,
    required this.paid,
    required this.change,
    required this.footer,
    this.showSuccessIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final serviceItems = items.where((i) => i.type == 'service').toList();
    final productItems = items.where((i) => i.type != 'service').toList();
    final hasBothTypes = serviceItems.isNotEmpty && productItems.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSuccessIcon) ...[
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 120,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'TRANSAKSI BERHASIL',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.success,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 60),
          ],
          Text(
            storeName.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2, color: Colors.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            storeAddress,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          Text(
            'Telp: $storePhone',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const _DashedDivider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('No: $invoiceNo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black)),
              Text(DateFormatter.formatWithTime(date), style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
          if (cashierName != null && cashierName!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Dibuat oleh: $cashierName', style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ),
          ],
          const SizedBox(height: 8),
          const _DashedDivider(),
          const SizedBox(height: 16),

          // Jasa section
          if (serviceItems.isNotEmpty) ...[
            if (hasBothTypes)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('— JASA —', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 1)),
              ),
            ...serviceItems.map(_buildItemRow),
            if (hasBothTypes) ...[
              const SizedBox(height: 8),
              const _DashedDivider(),
              const SizedBox(height: 8),
            ],
          ],

          // Sparepart section
          if (productItems.isNotEmpty) ...[
            if (hasBothTypes)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('— SPAREPART —', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 1)),
              ),
            ...productItems.map(_buildItemRow),
          ],

          const SizedBox(height: 16),
          const _DashedDivider(),
          const SizedBox(height: 16),
          _row('TOTAL', CurrencyFormatter.format(total), isBold: true, fontSize: 16),
          const SizedBox(height: 8),
          _row('BAYAR', CurrencyFormatter.format(paid)),
          const SizedBox(height: 4),
          _row('KEMBALI', CurrencyFormatter.format(change)),
          const SizedBox(height: 24),
          const _DashedDivider(),
          const SizedBox(height: 16),
          Text(
            footer.isEmpty ? '--- TERIMA KASIH ---' : footer,
            style: const TextStyle(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Barang yang sudah dibeli tidak dapat ditukar/dikembalikan',
            style: TextStyle(fontSize: 9, color: Colors.black38),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(ReceiptItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black))),
              if (item.workerName != null && item.workerName!.isNotEmpty && !item.name.contains('(${item.workerName})'))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                  child: Text(item.workerName!, style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.qty} x ${CurrencyFormatter.format(item.unitPrice)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (!item.isApproved && item.type == 'service')
                    const Text(
                      '(Menunggu Persetujuan)',
                      style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              Text(
                CurrencyFormatter.format(item.subtotal),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false, double fontSize = 13}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? Colors.black : Colors.black87)),
        Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? AppColors.primary : Colors.black)),
      ],
    ),
  );
}

class ReceiptItem {
  final String name;
  final int qty;
  final double unitPrice;
  final double subtotal;
  final String type; // 'product' atau 'service'
  final bool isApproved;
  final String? workerName;

  ReceiptItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.subtotal,
    this.type = 'product',
    this.isApproved = true,
    this.workerName,
  });
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black26),
              ),
            );
          }),
        );
      },
    );
  }
}
