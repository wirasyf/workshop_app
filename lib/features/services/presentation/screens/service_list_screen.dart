import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../providers/service_provider.dart';

/// Layar daftar jasa bengkel
class ServiceListScreen extends ConsumerWidget {
  const ServiceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(filteredServicesProvider);
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Jasa'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) => ref.read(serviceSearchProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Cari jasa...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),

          // Category filter bar
          _ServiceCategoryFilterBar(),
          const SizedBox(height: 12),

          // Services list
          Expanded(
            child: servicesAsync.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LoadingWidget()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.build_circle_rounded,
                    title: 'Belum ada jasa',
                    subtitle: 'Tambahkan jasa bengkel pertama Anda',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ServiceCard(service: items[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/services/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Jasa'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _ServiceCard extends ConsumerWidget {
  final dynamic service;
  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isActive = service.isActive;

    return InkWell(
      onTap: () => context.go('/services/${service.id}/edit'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.border : AppColors.error.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getCategoryIcon(service.category),
                color: AppColors.info,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Nonaktif',
                            style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ServiceCategories.getLabel(service.category),
                          style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.timer_outlined, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        '${service.estimatedMinutes} menit',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              CurrencyFormatter.format(service.price),
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'servis_rutin': return Icons.oil_barrel_rounded;
      case 'perbaikan': return Icons.build_rounded;
      case 'tune_up': return Icons.speed_rounded;
      case 'body': return Icons.color_lens_rounded;
      default: return Icons.miscellaneous_services_rounded;
    }
  }
}

class _ServiceCategoryFilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(serviceSelectedCategoryProvider);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _CategoryChip(
            label: 'Semua',
            isSelected: selectedCategory == null,
            onTap: () => ref.read(serviceSelectedCategoryProvider.notifier).state = null,
          ),
          ...ServiceCategories.all.map((c) => _CategoryChip(
            label: c['label']!,
            isSelected: selectedCategory == c['value'],
            onTap: () => ref.read(serviceSelectedCategoryProvider.notifier).state = c['value'],
          )),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.infoLight,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.primary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 13,
        ),
        side: const BorderSide(color: Colors.transparent),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
