import 'package:flutter/material.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';

class ReceiptPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> storeInfo;
  final List<dynamic> items;
  final double total;
  final double paid;
  final double change;
  final String invoiceNo;

  const ReceiptPreviewDialog({
    super.key,
    required this.storeInfo,
    required this.items,
    required this.total,
    required this.paid,
    required this.change,
    required this.invoiceNo,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      child: Container(
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(storeInfo['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(storeInfo['address'], style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
              Text('Telp: ${storeInfo['phone']}', style: const TextStyle(fontSize: 10)),
              const Divider(thickness: 1, color: Colors.black26),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(invoiceNo, style: const TextStyle(fontSize: 10)),
                Text(DateFormatter.formatTime(DateTime.now()), style: const TextStyle(fontSize: 10)),
              ]),
              const Divider(thickness: 1, color: Colors.black26),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontSize: 11)),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${item.qty} x ${CurrencyFormatter.formatCompact(item.unitPrice)}', style: const TextStyle(fontSize: 11)),
                      Text(CurrencyFormatter.formatCompact(item.subtotal), style: const TextStyle(fontSize: 11)),
                    ]),
                  ],
                ),
              )),
              const Divider(thickness: 1, color: Colors.black26),
              _row('TOTAL', CurrencyFormatter.format(total), isBold: true),
              _row('BAYAR', CurrencyFormatter.format(paid)),
              _row('KEMBALI', CurrencyFormatter.format(change)),
              const SizedBox(height: 20),
              const Text('--- TERIMA KASIH ---', style: TextStyle(fontSize: 10)),
              Text(storeInfo['footer'], style: const TextStyle(fontSize: 10)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
      Text(value, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
    ]),
  );
}
