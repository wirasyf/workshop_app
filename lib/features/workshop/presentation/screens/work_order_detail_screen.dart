import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/bluetooth_printer_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../main.dart';
import '../../../../shared/utils/app_toast.dart';
import '../../../pos/presentation/providers/cart_provider.dart';
import '../providers/workshop_provider.dart';
import '../../../../core/models/work_order_model.dart';
import '../../../products/data/product_repository.dart';
import '../../../services/data/service_repository.dart';

class WorkOrderDetailScreen extends ConsumerStatefulWidget {
  final String workOrderId;
  const WorkOrderDetailScreen({super.key, required this.workOrderId});

  @override
  ConsumerState<WorkOrderDetailScreen> createState() => _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends ConsumerState<WorkOrderDetailScreen> {
  final List<_WoServiceItem> _serviceItems = [];
  final List<_WoPartItem> _partItems = [];
  final _diagnosisCtrl = TextEditingController();

  @override
  void dispose() {
    _diagnosisCtrl.dispose();
    super.dispose();
  }

  double get _totalService => _serviceItems.fold(0.0, (s, i) => s + i.price * i.qty);
  double get _totalParts => _partItems.fold(0.0, (s, i) => s + i.price * i.qty);
  double get _grandTotal => _totalService + _totalParts;

  Future<void> _updateStatus(String newStatus) async {
    await FirebaseFirestore.instance.collection('work_orders').doc(widget.workOrderId).update({
      'status': newStatus,
      'diagnosis': _diagnosisCtrl.text.trim().isEmpty ? null : _diagnosisCtrl.text.trim(),
      'totalService': _totalService,
      'totalParts': _totalParts,
      'grandTotal': _grandTotal,
      'completedAt': newStatus == 'completed' ? FieldValue.serverTimestamp() : null,
    });

    ref.invalidate(workOrderDetailProvider(widget.workOrderId));
    ref.invalidate(activeWorkOrdersProvider);
    ref.invalidate(workOrdersProvider);

    if (mounted) {
      AppToast.show(context, 'Status diubah: ${WorkOrderStatus.getLabel(newStatus)}', type: ToastType.success);
      HapticFeedback.mediumImpact();
    }
  }

  void _processPayment() {
    final cartNotifier = ref.read(cartProvider.notifier);
    cartNotifier.clear();

    for (final s in _serviceItems) {
      cartNotifier.addItem(CartItem(
        productId: s.serviceId,
        name: s.name,
        unitPrice: s.price,
        unit: 'jasa',
        type: CartItemType.service,
        qty: s.qty,
      ));
    }

    for (final p in _partItems) {
      cartNotifier.addItem(CartItem(
        productId: p.productId,
        name: p.name,
        unitPrice: p.price,
        unit: p.unit,
        type: CartItemType.product,
        qty: p.qty,
      ));
    }

    context.go('/pos/cart');
  }

  Future<void> _printWorkOrder(WorkOrderModel wo) async {
    final printerState = ref.read(printerStateProvider);
    final settings = ref.read(settingsServiceProvider);

    if (!printerState.isConnected) {
      AppToast.show(context, 'Hubungkan printer terlebih dahulu di Lainnya → Printer Bluetooth', type: ToastType.warning);
      return;
    }

    final isStillConnected = await ref.read(printerStateProvider.notifier).checkConnection();
    if (!isStillConnected) {
      if (mounted) AppToast.show(context, 'Koneksi printer terputus. Coba hubungkan ulang.', type: ToastType.error);
      return;
    }

    try {
      final printItems = <PrintReceiptItem>[];

      for (final s in _serviceItems) {
        printItems.add(PrintReceiptItem(name: s.name, qty: s.qty, unitPrice: s.price, subtotal: s.price * s.qty, type: 'service'));
      }

      for (final p in _partItems) {
        printItems.add(PrintReceiptItem(name: p.name, qty: p.qty, unitPrice: p.price, subtotal: p.price * p.qty, type: 'product'));
      }

      final bytes = await ThermalPrintService.generateReceipt(
        storeName: settings.storeName, storeAddress: settings.storeAddress, storePhone: settings.storePhone,
        invoiceNo: wo.orderNo, date: wo.createdAt, items: printItems, total: _grandTotal, paid: 0, change: 0,
        footer: 'STRUK WORK ORDER\nStatus: ${WorkOrderStatus.getLabel(wo.status)}',
      );

      final result = await ThermalPrintService.printBytes(bytes);
      HapticFeedback.mediumImpact();

      if (mounted) {
        AppToast.show(context, result ? 'Struk berhasil dicetak!' : 'Gagal mencetak struk', type: result ? ToastType.success : ToastType.error);
      }
    } catch (e) {
      if (mounted) AppToast.show(context, 'Error: $e', type: ToastType.error);
    }
  }

  void _addServiceItem() async {
    final servicesAsync = await ref.read(serviceRepositoryProvider).getServices().first;
    if (!mounted) return;

    final selected = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9,
        builder: (ctx, scroll) => Container(
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const Padding(padding: EdgeInsets.all(16), child: Text('Pilih Jasa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: servicesAsync.length,
                  itemBuilder: (_, i) {
                    final s = servicesAsync[i];
                    return ListTile(
                      leading: Icon(Icons.build_rounded, color: AppColors.info),
                      title: Text(s.name),
                      subtitle: Text(CurrencyFormatter.format(s.price)),
                      onTap: () => Navigator.pop(ctx, s),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        final existing = _serviceItems.indexWhere((i) => i.serviceId == selected.id);
        if (existing >= 0) {
          _serviceItems[existing].qty++;
        } else {
          _serviceItems.add(_WoServiceItem(serviceId: selected.id, name: selected.name, price: selected.price));
        }
      });
    }
  }

  void _addPartItem() async {
    final productsAsync = await ref.read(productRepositoryProvider).getProducts().first;
    if (!mounted) return;

    final selected = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9,
        builder: (ctx, scroll) => Container(
          decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const Padding(padding: EdgeInsets.all(16), child: Text('Pilih Sparepart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: productsAsync.length,
                  itemBuilder: (_, i) {
                    final p = productsAsync[i];
                    return ListTile(
                      leading: Icon(Icons.settings_rounded, color: AppColors.primary),
                      title: Text(p.name),
                      subtitle: Text('${CurrencyFormatter.format(p.sellPrice)} • Stok: ${p.stockQty}'),
                      enabled: p.stockQty > 0,
                      onTap: p.stockQty > 0 ? () => Navigator.pop(ctx, p) : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        final existing = _partItems.indexWhere((i) => i.productId == selected.id);
        if (existing >= 0) {
          _partItems[existing].qty++;
        } else {
          _partItems.add(_WoPartItem(productId: selected.id, name: selected.name, price: selected.sellPrice, unit: selected.unit));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final woAsync = ref.watch(workOrderDetailProvider(widget.workOrderId));
    final theme = Theme.of(context);

    return woAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (wo) {
        if (wo == null) return const Scaffold(body: Center(child: Text('Work Order tidak ditemukan')));

        if (_diagnosisCtrl.text.isEmpty && wo.diagnosis != null) {
          _diagnosisCtrl.text = wo.diagnosis!;
        }

        final vehicleAsync = ref.watch(vehicleDetailProvider(wo.vehicleId));
        final statusColor = _getStatusColor(wo.status);
        final canEdit = wo.status == 'waiting' || wo.status == 'in_progress';

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            context.go('/workshop');
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(wo.orderNo),
              leading: IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => context.go('/workshop')),
            actions: [
              IconButton(icon: const Icon(Icons.print_rounded), onPressed: () => _printWorkOrder(wo), tooltip: 'Cetak Slip'),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(WorkOrderStatus.getLabel(wo.status), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              vehicleAsync.when(
                loading: () => const SizedBox(),
                error: (_, _) => const SizedBox(),
                data: (v) {
                  if (v == null) return const SizedBox();
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Pelanggan', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(v.customerName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      if (v.phoneNumber != null) Text(v.phoneNumber!, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Row(children: [
                        _infoChip(Icons.directions_car, v.plateNumber),
                        if (v.vehicleBrand != null) _infoChip(Icons.two_wheeler, '${v.vehicleBrand} ${v.vehicleType ?? ''}'.trim()),
                        if (v.vehicleYear != null) _infoChip(Icons.calendar_today, '${v.vehicleYear}'),
                      ]),
                    ]),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (wo.complaint != null && wo.complaint!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withValues(alpha: 0.2))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.report_problem_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(child: Text(wo.complaint!, style: theme.textTheme.bodySmall)),
                  ]),
                ),
                const SizedBox(height: 12),
              ],
              if (canEdit || (wo.diagnosis != null && wo.diagnosis!.isNotEmpty))
                TextFormField(
                  controller: _diagnosisCtrl, maxLines: 2, enabled: canEdit,
                  decoration: const InputDecoration(labelText: 'Diagnosa Mekanik', prefixIcon: Icon(Icons.medical_services_rounded)),
                ),
              const SizedBox(height: 20),
              _sectionHeader('Jasa', Icons.build_rounded, canEdit ? _addServiceItem : null),
              if (_serviceItems.isEmpty) _emptyPlaceholder('Belum ada jasa ditambahkan')
              else ..._serviceItems.asMap().entries.map((e) => _itemTile(
                  e.value.name, e.value.price, e.value.qty, 'jasa',
                  canEdit ? () => setState(() => _serviceItems.removeAt(e.key)) : null,
                  canEdit ? (q) => setState(() => _serviceItems[e.key].qty = q) : null,
                )),
              const SizedBox(height: 16),
              _sectionHeader('Sparepart', Icons.settings_rounded, canEdit ? _addPartItem : null),
              if (_partItems.isEmpty) _emptyPlaceholder('Belum ada sparepart ditambahkan')
              else ..._partItems.asMap().entries.map((e) => _itemTile(
                  e.value.name, e.value.price, e.value.qty, e.value.unit,
                  canEdit ? () => setState(() => _partItems.removeAt(e.key)) : null,
                  canEdit ? (q) => setState(() => _partItems[e.key].qty = q) : null,
                )),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(children: [
                  _summaryRow('Total Jasa', CurrencyFormatter.format(_totalService)),
                  _summaryRow('Total Sparepart', CurrencyFormatter.format(_totalParts)),
                  const Divider(),
                  _summaryRow('Grand Total', CurrencyFormatter.format(_grandTotal), bold: true),
                ]),
              ),
              const SizedBox(height: 20),
              if (wo.status == 'waiting')
                SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
                  onPressed: () => _updateStatus('in_progress'), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Mulai Pengerjaan'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
                )),
              if (wo.status == 'in_progress')
                SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
                  onPressed: () => _updateStatus('completed'), icon: const Icon(Icons.check_rounded), label: const Text('Selesai Dikerjakan'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                )),
              if (wo.status == 'completed')
                SizedBox(width: double.infinity, height: 48, child: ElevatedButton.icon(
                  onPressed: _grandTotal > 0 ? _processPayment : null, icon: const Icon(Icons.payment_rounded), label: const Text('Proses Pembayaran'),
                )),
              if (canEdit) ...[
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, height: 48, child: OutlinedButton.icon(
                  onPressed: () => _updateStatus('cancelled'), icon: const Icon(Icons.cancel_rounded, color: AppColors.error), label: const Text('Batalkan', style: TextStyle(color: AppColors.error)), style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                )),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ));
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon, VoidCallback? onAdd) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Icon(icon, size: 18, color: AppColors.primary), const SizedBox(width: 6), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
        if (onAdd != null) IconButton(icon: const Icon(Icons.add_circle_rounded, color: AppColors.primary), onPressed: onAdd),
      ]);
  }

  Widget _emptyPlaceholder(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_rounded, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _itemTile(String name, double price, int qty, String unit, VoidCallback? onRemove, void Function(int)? onQtyChanged) {
    return Container(
      margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text('${CurrencyFormatter.format(price)} × $qty', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        Text(CurrencyFormatter.format(price * qty), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        if (onRemove != null) ...[const SizedBox(width: 8), GestureDetector(onTap: onRemove, child: const Icon(Icons.remove_circle_rounded, size: 18, color: AppColors.error))],
      ]),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: bold ? 16 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: bold ? AppColors.primary : null)),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Padding(padding: const EdgeInsets.only(right: 8), child: Chip(avatar: Icon(icon, size: 14), label: Text(label, style: const TextStyle(fontSize: 11)), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact, padding: EdgeInsets.zero));
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting': return AppColors.warning;
      case 'in_progress': return AppColors.info;
      case 'completed': return AppColors.success;
      case 'paid': return AppColors.primary;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }
}

class _WoServiceItem {
  final String serviceId;
  final String name;
  final double price;
  int qty = 1;
  _WoServiceItem({required this.serviceId, required this.name, required this.price});
}

class _WoPartItem {
  final String productId;
  final String name;
  final double price;
  final String unit;
  int qty = 1;
  _WoPartItem({required this.productId, required this.name, required this.price, required this.unit});
}
