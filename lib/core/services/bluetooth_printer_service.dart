import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State koneksi printer
class PrinterState {
  final bool isConnected;
  final String? connectedName;
  final String? connectedMac;
  final bool isLoading;

  const PrinterState({
    this.isConnected = false,
    this.connectedName,
    this.connectedMac,
    this.isLoading = false,
  });

  PrinterState copyWith({
    bool? isConnected,
    String? connectedName,
    String? connectedMac,
    bool? isLoading,
  }) => PrinterState(
    isConnected: isConnected ?? this.isConnected,
    connectedName: connectedName ?? this.connectedName,
    connectedMac: connectedMac ?? this.connectedMac,
    isLoading: isLoading ?? this.isLoading,
  );
}

/// Provider state printer
final printerStateProvider =
    StateNotifierProvider<PrinterNotifier, PrinterState>(
      (ref) => PrinterNotifier(),
    );

/// Provider daftar device bluetooth paired
final pairedDevicesProvider = FutureProvider<List<BluetoothInfo>>((ref) async {
  return await PrintBluetoothThermal.pairedBluetooths;
});

class PrinterNotifier extends StateNotifier<PrinterState> {
  PrinterNotifier() : super(const PrinterState()) {
    _loadSavedPrinter();
  }

  /// Load printer yang sebelumnya disimpan
  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString('printer_mac');
    final name = prefs.getString('printer_name');
    if (mac != null && name != null) {
      state = state.copyWith(connectedMac: mac, connectedName: name);
      // Auto-connect
      await connect(mac, name);
    }
  }

  /// Cek apakah bluetooth aktif
  Future<bool> isBluetoothEnabled() async {
    return await PrintBluetoothThermal.bluetoothEnabled;
  }

  /// Connect ke printer
  Future<bool> connect(String mac, String name) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await PrintBluetoothThermal.connect(
        macPrinterAddress: mac,
      );
      if (result) {
        state = state.copyWith(
          isConnected: true,
          connectedMac: mac,
          connectedName: name,
          isLoading: false,
        );
        // Simpan untuk auto-connect
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('printer_mac', mac);
        await prefs.setString('printer_name', name);
        return true;
      }
    } catch (e) {
      debugPrint('Bluetooth connect error: $e');
    }
    state = state.copyWith(isConnected: false, isLoading: false);
    return false;
  }

  /// Disconnect dari printer
  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
    state = state.copyWith(isConnected: false);
  }

  /// Hapus printer tersimpan
  Future<void> forgetPrinter() async {
    await disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('printer_mac');
    await prefs.remove('printer_name');
    state = const PrinterState();
  }

  /// Cek status koneksi real-time
  Future<bool> checkConnection() async {
    final status = await PrintBluetoothThermal.connectionStatus;
    state = state.copyWith(isConnected: status);
    return status;
  }
}

/// Service untuk generate & cetak struk thermal
class ThermalPrintService {
  /// Generate bytes struk dari data transaksi
  static Future<List<int>> generateReceipt({
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String invoiceNo,
    required DateTime date,
    required List<PrintReceiptItem> items,
    required double total,
    required double paid,
    required double change,
    String? cashierName,
    String footer = '',
    int paperWidth = 58,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = paperWidth == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final gen = Generator(paperSize, profile);
    List<int> bytes = [];

    bytes += gen.reset();

    // Header toko
    bytes += gen.text(
      storeName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size1,
      ),
    );
    bytes += gen.text(
      storeAddress,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += gen.text(
      'Telp: $storePhone',
      styles: const PosStyles(align: PosAlign.center),
      linesAfter: 1,
    );

    // Garis pemisah
    bytes += gen.hr(ch: '=');

    // Invoice & tanggal
    bytes += gen.row([
      PosColumn(text: invoiceNo, width: 7, styles: const PosStyles(bold: true)),
      PosColumn(
        text: _formatDate(date),
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    if (cashierName != null && cashierName.isNotEmpty) {
      bytes += gen.text(
        'Dibuat oleh: $cashierName',
        styles: const PosStyles(align: PosAlign.left),
      );
    }

    bytes += gen.hr();

    // Items: pisahkan jasa dan sparepart
    final serviceItems = items.where((i) => i.type == 'service').toList();
    final productItems = items.where((i) => i.type != 'service').toList();
    final hasBoth = serviceItems.isNotEmpty && productItems.isNotEmpty;

    if (serviceItems.isNotEmpty) {
      if (hasBoth) {
        bytes += gen.text(
          '-- JASA --',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }
      for (final item in serviceItems) {
        bytes += _printItem(gen, item);
      }
    }

    if (productItems.isNotEmpty) {
      if (hasBoth) {
        bytes += gen.text(
          '-- SPAREPART --',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }
      for (final item in productItems) {
        bytes += _printItem(gen, item);
      }
    }

    bytes += gen.hr();

    // Total
    bytes += gen.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: _formatRp(total),
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      ),
    ]);

    bytes += gen.row([
      PosColumn(text: 'BAYAR', width: 6),
      PosColumn(
        text: _formatRp(paid),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += gen.row([
      PosColumn(text: 'KEMBALI', width: 6),
      PosColumn(
        text: _formatRp(change),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += gen.hr(ch: '=');

    // Footer
    bytes += gen.text(
      footer.isEmpty ? '--- TERIMA KASIH ---' : footer,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += gen.text(
      'Barang yang sudah dibeli',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += gen.text(
      'tidak dapat ditukar/dikembalikan',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += gen.feed(3);
    // bytes += gen.cut(); // Uncomment jika printer support auto-cut

    return bytes;
  }

  static List<int> _printItem(Generator gen, PrintReceiptItem item) {
    List<int> bytes = [];
    final nameStr =
        (item.workerName != null &&
            item.workerName!.isNotEmpty &&
            !item.name.contains('(${item.workerName})'))
        ? '${item.name} [Mek: ${item.workerName}]'
        : item.name;
    bytes += gen.text(nameStr);
    bytes += gen.row([
      PosColumn(text: '${item.qty} x ${_formatRp(item.unitPrice)}', width: 7),
      PosColumn(
        text: _formatRp(item.subtotal),
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    return bytes;
  }

  /// Cetak bytes ke printer yang terkoneksi
  static Future<bool> printBytes(List<int> bytes) async {
    final isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) return false;

    final result = await PrintBluetoothThermal.writeBytes(
      Uint8List.fromList(bytes),
    );
    return result;
  }

  static String _formatRp(double amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $formatted';
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Model item untuk cetak struk
class PrintReceiptItem {
  final String name;
  final int qty;
  final double unitPrice;
  final double subtotal;
  final String type;
  final String? workerName;

  PrintReceiptItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.subtotal,
    this.type = 'product',
    this.workerName,
  });
}
