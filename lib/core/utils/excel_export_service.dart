import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';

/// Service untuk generate file Excel (.xlsx) profesional
class ExcelExportService {
  final AppDatabase _db;

  ExcelExportService(this._db);

  /// Generate laporan Excel lengkap dengan 5 sheet
  Future<File> generateReport({
    required DateTime start,
    required DateTime end,
    required String periodLabel,
    required String storeName,
  }) async {
    final excel = Excel.createExcel();

    // Fetch data
    final summary = await _db.getSummaryProfit(start, end);
    final txns = await _db.getTransactionsByDate(start, end);
    final detailedItems = await _db.getDetailedTransactionItems(start, end);
    final topProducts = await _db.getTopProducts(start, end, limit: 20);
    final txnCount = await _db.getTransactionCount(start, end);

    // Create sheets
    _buildSummarySheet(excel, summary, txnCount, periodLabel, storeName, start, end);
    _buildTransactionSheet(excel, txns);
    _buildItemDetailSheet(excel, detailedItems);
    _buildTopProductsSheet(excel, topProducts);
    _buildDailySummarySheet(excel, start, end);

    // Remove default sheet
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Save file
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName = 'laporan_${periodLabel.toLowerCase().replaceAll(' ', '_')}_'
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.xlsx';
    final file = File('${dir.path}/$fileName');
    
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }

    return file;
  }

  /// Sheet 1: Ringkasan (Executive Summary)
  void _buildSummarySheet(Excel excel, Map<String, double> summary, int txnCount,
      String periodLabel, String storeName, DateTime start, DateTime end) {
    final sheet = excel['Ringkasan'];

    // Header
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('LAPORAN BENGKEL ${storeName.toUpperCase()}');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true, fontSize: 16,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));

    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
      'Periode: $periodLabel (${DateFormatter.formatShort(start)} — ${DateFormatter.formatShort(end)})');
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
      'Dicetak: ${DateFormatter.formatWithTime(DateTime.now())}');

    // Ringkasan Keuangan
    int row = 5;
    _headerCell(sheet, 'A$row', 'RINGKASAN KEUANGAN');
    _headerCell(sheet, 'B$row', '');
    row++;

    final totalSales = summary['totalSales'] ?? 0.0;
    final totalCost = summary['totalCost'] ?? 0.0;
    final grossProfit = summary['grossProfit'] ?? 0.0;
    final margin = summary['margin'] ?? 0.0;
    final serviceRev = summary['serviceRevenue'] ?? 0.0;
    final partsRev = summary['partsRevenue'] ?? 0.0;

    _dataRow(sheet, row++, 'Total Omzet (Pendapatan Kotor)', _formatRp(totalSales));
    _dataRow(sheet, row++, 'Total Modal (HPP)', _formatRp(totalCost));
    _dataRow(sheet, row++, 'Laba Kotor (Gross Profit)', _formatRp(grossProfit), bold: true);
    _dataRow(sheet, row++, 'Margin Laba Kotor', '${margin.toStringAsFixed(1)}%');
    row++;

    _headerCell(sheet, 'A$row', 'BREAKDOWN PENDAPATAN');
    _headerCell(sheet, 'B$row', '');
    row++;
    _dataRow(sheet, row++, 'Pendapatan Jasa', _formatRp(serviceRev));
    _dataRow(sheet, row++, 'Pendapatan Sparepart', _formatRp(partsRev));
    row++;

    _headerCell(sheet, 'A$row', 'STATISTIK');
    _headerCell(sheet, 'B$row', '');
    row++;
    _dataRow(sheet, row++, 'Total Transaksi', txnCount.toString());
    _dataRow(sheet, row++, 'Rata-rata per Transaksi',
        _formatRp(txnCount > 0 ? totalSales / txnCount : 0));

    // Column widths
    sheet.setColumnWidth(0, 35);
    sheet.setColumnWidth(1, 25);
  }

  /// Sheet 2: Detail Transaksi
  void _buildTransactionSheet(Excel excel, List<Transaction> txns) {
    final sheet = excel['Detail Transaksi'];

    final headers = ['No', 'Invoice', 'Tanggal', 'Pelanggan', 'Metode Bayar', 'Subtotal', 'Diskon', 'Total'];
    for (int i = 0; i < headers.length; i++) {
      _headerCell(sheet, '${_colLetter(i)}1', headers[i]);
    }

    for (int i = 0; i < txns.length; i++) {
      final t = txns[i];
      final r = i + 2;
      sheet.cell(CellIndex.indexByString('A$r')).value = IntCellValue(i + 1);
      sheet.cell(CellIndex.indexByString('B$r')).value = TextCellValue(t.invoiceNo);
      sheet.cell(CellIndex.indexByString('C$r')).value = TextCellValue(DateFormatter.formatWithTime(t.createdAt));
      sheet.cell(CellIndex.indexByString('D$r')).value = TextCellValue(t.customerName ?? '-');
      sheet.cell(CellIndex.indexByString('E$r')).value = TextCellValue(t.paymentMethod.toUpperCase());
      sheet.cell(CellIndex.indexByString('F$r')).value = DoubleCellValue(t.subtotal);
      sheet.cell(CellIndex.indexByString('G$r')).value = DoubleCellValue(t.discount);
      sheet.cell(CellIndex.indexByString('H$r')).value = DoubleCellValue(t.total);

      // Row banding
      if (i % 2 == 1) {
        for (int c = 0; c < headers.length; c++) {
          sheet.cell(CellIndex.indexByString('${_colLetter(c)}$r')).cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#F0F4F8'),
          );
        }
      }
    }

    // SUM row
    if (txns.isNotEmpty) {
      final sumRow = txns.length + 2;
      sheet.cell(CellIndex.indexByString('E$sumRow')).value = TextCellValue('TOTAL');
      sheet.cell(CellIndex.indexByString('E$sumRow')).cellStyle = CellStyle(bold: true);
      sheet.cell(CellIndex.indexByString('F$sumRow')).value = TextCellValue('=SUM(F2:F${txns.length + 1})');
      sheet.cell(CellIndex.indexByString('H$sumRow')).value = TextCellValue('=SUM(H2:H${txns.length + 1})');
    }

    // Column widths
    final widths = [5.0, 25.0, 22.0, 20.0, 15.0, 18.0, 15.0, 18.0];
    for (int i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }

  /// Sheet 3: Detail Item
  void _buildItemDetailSheet(Excel excel, List<Map<String, dynamic>> items) {
    final sheet = excel['Detail Item'];

    final headers = ['No', 'Invoice', 'Tipe', 'Nama Item', 'Mekanik/Pekerja', 'Qty', 'Harga Satuan', 'Modal Satuan', 'Subtotal', 'Total Modal', 'Profit Item'];
    for (int i = 0; i < headers.length; i++) {
      _headerCell(sheet, '${_colLetter(i)}1', headers[i]);
    }

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final r = i + 2;
      final qty = item['qty'] as int;
      final unitPrice = (item['unitPrice'] as num).toDouble();
      final costPrice = (item['costPrice'] as num).toDouble();
      final subtotal = (item['subtotal'] as num).toDouble();
      final totalCost = costPrice * qty;
      final profit = subtotal - totalCost;
      final tipe = item['itemType'] == 'service' ? 'Jasa' : 'Sparepart';
      final worker = item['workerName']?.toString() ?? '-';

      sheet.cell(CellIndex.indexByString('A$r')).value = IntCellValue(i + 1);
      sheet.cell(CellIndex.indexByString('B$r')).value = TextCellValue(item['invoiceNo'] ?? '-');
      sheet.cell(CellIndex.indexByString('C$r')).value = TextCellValue(tipe);
      sheet.cell(CellIndex.indexByString('D$r')).value = TextCellValue(item['itemName'] ?? '-');
      sheet.cell(CellIndex.indexByString('E$r')).value = TextCellValue(worker);
      sheet.cell(CellIndex.indexByString('F$r')).value = IntCellValue(qty);
      sheet.cell(CellIndex.indexByString('G$r')).value = DoubleCellValue(unitPrice);
      sheet.cell(CellIndex.indexByString('H$r')).value = DoubleCellValue(costPrice);
      sheet.cell(CellIndex.indexByString('I$r')).value = DoubleCellValue(subtotal);
      sheet.cell(CellIndex.indexByString('J$r')).value = DoubleCellValue(totalCost);
      sheet.cell(CellIndex.indexByString('K$r')).value = DoubleCellValue(profit);

      if (i % 2 == 1) {
        for (int c = 0; c < headers.length; c++) {
          sheet.cell(CellIndex.indexByString('${_colLetter(c)}$r')).cellStyle = CellStyle(
            backgroundColorHex: ExcelColor.fromHexString('#F0F4F8'),
          );
        }
      }
    }

    final widths = [5.0, 25.0, 12.0, 25.0, 20.0, 8.0, 15.0, 15.0, 15.0, 15.0, 15.0];
    for (int i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
  }

  /// Sheet 4: Produk Terlaris
  void _buildTopProductsSheet(Excel excel, List<Map<String, dynamic>> topProducts) {
    final sheet = excel['Produk Terlaris'];

    final headers = ['Rank', 'Nama', 'Qty Terjual', 'Total Omzet'];
    for (int i = 0; i < headers.length; i++) {
      _headerCell(sheet, '${_colLetter(i)}1', headers[i]);
    }

    for (int i = 0; i < topProducts.length; i++) {
      final p = topProducts[i];
      final r = i + 2;
      sheet.cell(CellIndex.indexByString('A$r')).value = IntCellValue(i + 1);
      sheet.cell(CellIndex.indexByString('B$r')).value = TextCellValue(p['name']?.toString() ?? '-');
      sheet.cell(CellIndex.indexByString('C$r')).value = IntCellValue(p['totalQty'] ?? 0);
      sheet.cell(CellIndex.indexByString('D$r')).value = DoubleCellValue((p['totalRevenue'] as num?)?.toDouble() ?? 0);
    }

    sheet.setColumnWidth(0, 8);
    sheet.setColumnWidth(1, 30);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 20);
  }

  /// Sheet 5: Grafik Harian
  void _buildDailySummarySheet(Excel excel, DateTime start, DateTime end) async {
    final sheet = excel['Grafik Harian'];

    final headers = ['Tanggal', 'Jumlah Transaksi', 'Omzet'];
    for (int i = 0; i < headers.length; i++) {
      _headerCell(sheet, '${_colLetter(i)}1', headers[i]);
    }

    final days = end.difference(start).inDays + 1;
    final dailyData = await _db.getDailySales(days);

    for (int i = 0; i < dailyData.length; i++) {
      final d = dailyData[i];
      final r = i + 2;
      sheet.cell(CellIndex.indexByString('A$r')).value = TextCellValue(d['date'] ?? '');
      sheet.cell(CellIndex.indexByString('B$r')).value = IntCellValue(d['count'] ?? 0);
      sheet.cell(CellIndex.indexByString('C$r')).value = DoubleCellValue((d['total'] as num?)?.toDouble() ?? 0);
    }

    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 18);
  }

  // ── Helpers ──

  void _headerCell(Sheet sheet, String cell, String text) {
    sheet.cell(CellIndex.indexByString(cell)).value = TextCellValue(text);
    sheet.cell(CellIndex.indexByString(cell)).cellStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A5F'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
  }

  void _dataRow(Sheet sheet, int row, String label, String value, {bool bold = false}) {
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(label);
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(value);
    if (bold) {
      sheet.cell(CellIndex.indexByString('A$row')).cellStyle = CellStyle(bold: true);
      sheet.cell(CellIndex.indexByString('B$row')).cellStyle = CellStyle(bold: true);
    }
  }

  String _formatRp(double amount) {
    return CurrencyFormatter.format(amount);
  }

  String _colLetter(int index) {
    return String.fromCharCode(65 + index); // A=0, B=1, ...
  }
}
