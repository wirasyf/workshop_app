import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product_model.dart';
import '../utils/currency_formatter.dart';

class ExcelExportService {
  static Future<void> exportProducts({
    required List<ProductModel> products,
    required bool isAdmin,
  }) async {
    var excel = Excel.createExcel();

    if (excel.tables.keys.isNotEmpty && excel.tables.keys.first != 'Stok Barang') {
      excel.rename(excel.tables.keys.first, 'Stok Barang');
    }
    
    var sheet = excel['Stok Barang'];
    excel.setDefaultSheet('Stok Barang');

    // Headers
    if (isAdmin) {
      sheet.appendRow([
        TextCellValue('Nama Barang'),
        TextCellValue('Stok Tersisa'),
        TextCellValue('Total Inventaris'),
      ]);
    } else {
      sheet.appendRow([
        TextCellValue('Nama Barang'),
        TextCellValue('Stok Tersisa'),
      ]);
    }

    // Apply header style
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1976D2'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
    );
    final colCount = isAdmin ? 3 : 2;
    for (int i = 0; i < colCount; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.cellStyle = headerStyle;
    }

    // Data rows
    double grandTotal = 0;
    for (var product in products) {
      if (isAdmin) {
        double totalInventaris = product.sellPrice * product.stockQty;
        grandTotal += totalInventaris;
        sheet.appendRow([
          TextCellValue(product.name),
          IntCellValue(product.stockQty),
          TextCellValue(CurrencyFormatter.formatNumber(totalInventaris)),
        ]);
      } else {
        sheet.appendRow([
          TextCellValue(product.name),
          IntCellValue(product.stockQty),
        ]);
      }
    }

    // Grand total for Admin
    if (isAdmin) {
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('GRAND TOTAL'),
        TextCellValue(CurrencyFormatter.formatNumber(grandTotal)),
      ]);
    }

    // Save and Share
    final fileBytes = excel.save();
    if (fileBytes != null) {
      final directory = await getTemporaryDirectory();
      final now = DateTime.now();
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'Stok_Barang_$timestamp.xlsx';
      final filePath = '${directory.path}/$fileName';
      
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
        
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Laporan Stok Barang',
      );
    }
  }
}
