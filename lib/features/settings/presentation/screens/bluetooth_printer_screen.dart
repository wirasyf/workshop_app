import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/bluetooth_printer_service.dart';
import '../../../../shared/utils/app_toast.dart';

/// Layar koneksi printer bluetooth
class BluetoothPrinterScreen extends ConsumerStatefulWidget {
  const BluetoothPrinterScreen({super.key});

  @override
  ConsumerState<BluetoothPrinterScreen> createState() =>
      _BluetoothPrinterScreenState();
}

class _BluetoothPrinterScreenState
    extends ConsumerState<BluetoothPrinterScreen> {
  bool _isScanning = false;
  List<BluetoothInfo> _devices = [];

  @override
  void initState() {
    super.initState();
    _scanDevices();
  }

  Future<void> _scanDevices() async {
    setState(() => _isScanning = true);

    final btEnabled =
        await ref.read(printerStateProvider.notifier).isBluetoothEnabled();
    if (!btEnabled) {
      if (mounted) {
        AppToast.show(
          context,
          'Bluetooth tidak aktif. Aktifkan Bluetooth terlebih dahulu.',
          type: ToastType.error,
        );
      }
      setState(() => _isScanning = false);
      return;
    }

    try {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      if (mounted) {
        setState(() {
          _devices = devices;
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, 'Error scan: $e', type: ToastType.error);
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _connectPrinter(BluetoothInfo device) async {
    final notifier = ref.read(printerStateProvider.notifier);
    final result = await notifier.connect(device.macAdress, device.name);

    if (mounted) {
      if (result) {
        HapticFeedback.heavyImpact();
        AppToast.show(
          context,
          'Terhubung ke ${device.name}',
          type: ToastType.success,
        );
      } else {
        AppToast.show(
          context,
          'Gagal terhubung ke ${device.name}',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _testPrint() async {
    final isConnected =
        await ref.read(printerStateProvider.notifier).checkConnection();
    if (!isConnected) {
      if (mounted) {
        AppToast.show(
          context,
          'Printer tidak terhubung',
          type: ToastType.error,
        );
      }
      return;
    }

    final bytes = await ThermalPrintService.generateReceipt(
      storeName: 'D&D Markas Ban',
      storeAddress: 'Jl. Contoh No. 123',
      storePhone: '08123456789',
      invoiceNo: 'TEST-PRINT',
      date: DateTime.now(),
      items: [
        PrintReceiptItem(
          name: 'Oli Motor 1L',
          qty: 1,
          unitPrice: 45000,
          subtotal: 45000,
        ),
        PrintReceiptItem(
          name: 'Ganti Oli',
          qty: 1,
          unitPrice: 15000,
          subtotal: 15000,
          type: 'service',
        ),
      ],
      total: 60000,
      paid: 100000,
      change: 40000,
    );

    final result = await ThermalPrintService.printBytes(bytes);
    if (mounted) {
      AppToast.show(
        context,
        result ? 'Test print berhasil!' : 'Test print gagal',
        type: result ? ToastType.success : ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final printerState = ref.watch(printerStateProvider);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/settings');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Printer Bluetooth'),
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => context.go('/settings'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Scan ulang',
              onPressed: _isScanning ? null : _scanDevices,
            ),
          ],
        ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status koneksi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: printerState.isConnected
                    ? [
                        AppColors.success.withValues(alpha: 0.1),
                        AppColors.success.withValues(alpha: 0.05),
                      ]
                    : [
                        AppColors.border.withValues(alpha: 0.3),
                        AppColors.border.withValues(alpha: 0.1),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: printerState.isConnected
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: printerState.isConnected
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    printerState.isConnected
                        ? Icons.print_rounded
                        : Icons.print_disabled_rounded,
                    color: printerState.isConnected
                        ? AppColors.success
                        : AppColors.textHint,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printerState.isConnected
                            ? 'Terhubung'
                            : 'Tidak Terhubung',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: printerState.isConnected
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (printerState.connectedName != null)
                        Text(
                          printerState.connectedName!,
                          style: theme.textTheme.bodySmall,
                        ),
                      if (printerState.connectedMac != null)
                        Text(
                          printerState.connectedMac!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                ),
                if (printerState.isConnected) ...[
                  IconButton(
                    icon: const Icon(
                      Icons.print_rounded,
                      color: AppColors.info,
                    ),
                    tooltip: 'Test Print',
                    onPressed: _testPrint,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.link_off_rounded,
                      color: AppColors.error,
                    ),
                    tooltip: 'Putuskan',
                    onPressed: () async {
                      await ref
                          .read(printerStateProvider.notifier)
                          .forgetPrinter();
                      if (mounted) {
                        AppToast.show(
                          context,
                          'Printer diputuskan',
                          type: ToastType.info,
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.info,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pastikan printer sudah di-pair melalui pengaturan Bluetooth HP Anda terlebih dahulu.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.info,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Daftar device
          Text(
            'Perangkat Tersedia',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          if (_isScanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Mencari perangkat...'),
                  ],
                ),
              ),
            )
          else if (_devices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_disabled_rounded,
                      size: 48,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak ada perangkat ditemukan',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pair printer di Pengaturan Bluetooth HP',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._devices.map((device) {
              final isCurrentlyConnected =
                  printerState.isConnected &&
                  printerState.connectedMac == device.macAdress;
              final isConnecting = printerState.isLoading;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrentlyConnected
                        ? AppColors.success
                        : AppColors.border,
                    width: isCurrentlyConnected ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCurrentlyConnected
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCurrentlyConnected
                          ? Icons.bluetooth_connected_rounded
                          : Icons.bluetooth_rounded,
                      color: isCurrentlyConnected
                          ? AppColors.success
                          : AppColors.primary,
                    ),
                  ),
                  title: Text(
                    device.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    device.macAdress,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                  trailing: isCurrentlyConnected
                      ? const Chip(
                          label: Text(
                            'Terhubung',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                            ),
                          ),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(color: AppColors.success),
                          visualDensity: VisualDensity.compact,
                        )
                      : isConnecting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : ElevatedButton(
                              onPressed: () => _connectPrinter(device),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                minimumSize: Size.zero,
                              ),
                              child: const Text(
                                'Hubungkan',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                ),
              );
            }),
        ],
      ),
    ));
  }
}
