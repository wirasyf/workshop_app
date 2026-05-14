import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/connectivity_service.dart';

/// Shell screen dengan bottom navigation bar
class ShellScreen extends ConsumerWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Column(
        children: [
          // Banner offline
          isOnline.when(
            data: (online) => online
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    color: AppColors.warning,
                    child: const Text(
                      '⚡ Mode Offline — Data tersimpan lokal',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: _ownerBottomNav(context, location),
    );
  }

  /// Bottom nav untuk Owner: Beranda · POS · Bengkel · Stok · Lainnya
  Widget _ownerBottomNav(BuildContext context, String location) {
    int index = 0;
    if (location.startsWith('/pos')) index = 1;
    if (location.startsWith('/workshop')) index = 2;
    if (location.startsWith('/products')) index = 3;
    if (location.startsWith('/settings') || location.startsWith('/reports') || 
        location.startsWith('/history') || location.startsWith('/notifications') ||
        location.startsWith('/services')) index = 4;

    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) {
        switch (i) {
          case 0: context.go('/dashboard');
          case 1: context.go('/pos');
          case 2: context.go('/workshop');
          case 3: context.go('/products');
          case 4: context.go('/settings');
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Beranda'),
        NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale_rounded), label: 'POS'),
        NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build_rounded), label: 'Bengkel'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Stok'),
        NavigationDestination(icon: Icon(Icons.more_horiz_rounded), selectedIcon: Icon(Icons.more_horiz_rounded), label: 'Lainnya'),
      ],
    );
  }
}
