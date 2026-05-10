import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../shared/widgets/metric_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';


/// Dashboard Kasir
class CashierDashboardScreen extends ConsumerWidget {
  const CashierDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final start = DateFormatter.startOfDay(now);
    final end = DateFormatter.endOfDay(now);

    return Scaffold(
      appBar: AppBar(
        title: Text('Halo, ${user?.name ?? "Kasir"} 👋'),
      ),
      body: FutureBuilder(
        future: Future.wait([
          db.getTransactionsByCashier(user?.id ?? 1, start, end),
          db.getTotalSales(start, end),
        ]),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final txns = snap.data![0] as List<Transaction>;
          final totalSales = (snap.data![1] as num?)?.toDouble() ?? 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(DateFormatter.formatLong(now), style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: MetricCard(
                  label: 'Transaksi Shift', value: '${txns.length}',
                  icon: Icons.receipt_outlined, iconColor: AppColors.info,
                )),
                const SizedBox(width: 12),
                Expanded(child: MetricCard(
                  label: 'Total Penjualan', value: CurrencyFormatter.formatCompact(totalSales),
                  icon: Icons.monetization_on_outlined, iconColor: AppColors.success,
                )),
              ]),
              const SizedBox(height: 24),

              // Tombol besar POS
              GestureDetector(
                onTap: () => context.go('/pos'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: const Column(children: [
                    Icon(Icons.point_of_sale, size: 48, color: Colors.white),
                    SizedBox(height: 8),
                    Text('Buka Kasir (POS)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),

              // Transaksi terakhir
              Text('Transaksi Terakhir', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (txns.isEmpty)
                const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Belum ada transaksi hari ini')))
              else
                ...txns.take(5).map((t) => ListTile(
                  leading: const Icon(Icons.receipt, color: AppColors.success),
                  title: Text(t.invoiceNo, style: theme.textTheme.titleSmall),
                  subtitle: Text(DateFormatter.formatTime(t.createdAt)),
                  trailing: Text(CurrencyFormatter.format(t.total), style: theme.textTheme.titleSmall?.copyWith(color: AppColors.primary)),
                  dense: true,
                )),
            ],
          );
        },
      ),
    );
  }
}
