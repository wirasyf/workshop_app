import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/connectivity_service.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Shell screen dengan bottom navigation bar
class ShellScreen extends ConsumerWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final user = ref.watch(authStateProvider).value;

    final showNavbar = location == '/dashboard' || location == '/pos' || location == '/reports' || location == '/settings';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        // Jika berada di halaman sekunder (bukan root navbar), arahkan kembali ke halaman induknya menggunakan context.go agar ShellScreen selalu rebuild dan navbar muncul dengan benar
        if (!showNavbar) {
          final from = GoRouterState.of(context).uri.queryParameters['from'];
          if (location.startsWith('/settings/')) {
            context.go('/settings');
          } else if (location.startsWith('/products/')) {
            context.go(from == 'dashboard' ? '/products?from=dashboard' : '/products');
          } else if (location == '/products') {
            context.go(from == 'dashboard' ? '/dashboard' : '/settings');
          } else if (location.startsWith('/services/')) {
            context.go(from == 'dashboard' ? '/services?from=dashboard' : '/services');
          } else if (location == '/services') {
            context.go(from == 'dashboard' ? '/dashboard' : '/settings');
          } else if (location.startsWith('/workshop/')) {
            context.go('/workshop');
          } else if (location == '/workshop') {
            context.go('/dashboard');
          } else if (location.startsWith('/pos/')) {
            context.go('/pos');
          } else if (location.startsWith('/notifications') ||
              location.startsWith('/service-approval')) {
            context.go(from == 'dashboard' ? '/dashboard' : '/settings');
          } else if (location.startsWith('/history') ||
              location.startsWith('/staff')) {
            context.go(from == 'dashboard' ? '/dashboard' : '/settings');
          } else {
            context.go('/dashboard');
          }
          return;
        }

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Keluar Aplikasi'),
            content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Keluar'),
              ),
            ],
          ),
        );

        if (shouldExit == true) {
          exit(0);
        }
      },
      child: Scaffold(
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
        bottomNavigationBar: showNavbar ? _buildBottomNav(context, location, user?.role) : null,
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, String location, String? role) {
    final isCashier = role == 'cashier';

    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Beranda'),
      const NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale_rounded), label: 'POS'),
      if (!isCashier)
        const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Laporan'),
      const NavigationDestination(icon: Icon(Icons.more_horiz_rounded), selectedIcon: Icon(Icons.more_horiz_rounded), label: 'Lainnya'),
    ];

    int index = 0;
    if (location.startsWith('/pos')) {
      index = 1;
    } else if (location.startsWith('/reports')) {
      index = isCashier ? 0 : 2;
    } else if (location.startsWith('/settings') || location.startsWith('/products') || 
               location.startsWith('/history') || location.startsWith('/notifications') ||
               location.startsWith('/services') || location.startsWith('/staff')) {
      index = isCashier ? 2 : 3;
    }

    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) {
        if (isCashier) {
          switch (i) {
            case 0: context.go('/dashboard');
            case 1: context.go('/pos');
            case 2: context.go('/settings');
          }
        } else {
          switch (i) {
            case 0: context.go('/dashboard');
            case 1: context.go('/pos');
            case 2: context.go('/reports');
            case 3: context.go('/settings');
          }
        }
      },
      destinations: destinations,
    );
  }
}
