import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dnd_markasban_app/main.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/settings_service.dart';

/// Layar pengaturan
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final isOnline = ref.watch(connectivityProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profil
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.08), AppColors.primaryLight.withValues(alpha: 0.05)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary,
                backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                    ? (user.avatarUrl!.startsWith('data:image')
                        ? MemoryImage(base64Decode(user.avatarUrl!.split(',').last))
                        : user.avatarUrl!.startsWith('http')
                            ? CachedNetworkImageProvider(user.avatarUrl!)
                            : FileImage(File(user.avatarUrl!))) as ImageProvider?
                    : null,
                child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                    ? Text(user?.name.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700))
                    : null,
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?.name ?? '-', style: theme.textTheme.titleMedium),
                Text(user?.email ?? '-', style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                const SizedBox(height: 4),
                Text('Akun Terverifikasi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
              ]),
              const Spacer(),
              if (user?.role != 'cashier')
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                  onPressed: () => context.go('/settings/edit-profile'),
                ),
            ]),
          ),
          const SizedBox(height: 20),

          // Status koneksi
          _settingsTile(Icons.wifi_rounded, 'Status Koneksi',
            subtitle: isOnline.when(data: (v) => v ? 'Online' : 'Offline', loading: () => '...', error: (_, __) => 'Error'),
            trailing: isOnline.when(
              data: (v) => Icon(Icons.circle, size: 12, color: v ? AppColors.success : AppColors.error),
              loading: () => const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1)),
              error: (_, __) => const Icon(Icons.error_rounded, size: 12, color: AppColors.error),
            ),
          ),
          
          Consumer(builder: (context, ref, _) {
            final themeMode = ref.watch(themeModeProvider);
            final isDark = themeMode == ThemeMode.dark;
            return _settingsTile(
              Icons.dark_mode_rounded,
              'Mode Gelap',
              subtitle: 'Gunakan tema visual gelap',
              trailing: Switch(
                value: isDark,
                onChanged: (value) {
                  final newMode = value ? 'dark' : 'light';
                  ref.read(settingsServiceProvider).setThemeMode(newMode);
                  ref.read(themeModeProvider.notifier).state = value ? ThemeMode.dark : ThemeMode.light;
                },
                activeColor: AppColors.primary,
              ),
            );
          }),
          
          const Divider(height: 32),
          if (user?.role != 'cashier') ...[
            _settingsTile(Icons.lock_reset_rounded, 'Ubah Kata Sandi', subtitle: 'Perbarui kata sandi akun Anda', onTap: () => context.go('/settings/change-password')),
            const Divider(height: 32),
          ],
          if (user?.role == 'owner')
            _settingsTile(Icons.store_rounded, 'Profil & Struk Toko', subtitle: 'Identitas toko & footer struk', onTap: () => context.go('/settings/store-profile')),
          _settingsTile(Icons.print_rounded, 'Printer Bluetooth', subtitle: 'Hubungkan printer thermal', onTap: () => context.go('/settings/bluetooth-printer')),
          const Divider(height: 32),

          // Menu yang dipindah dari bottom nav
          _settingsTile(Icons.history_rounded, 'Riwayat Transaksi', subtitle: 'Semua transaksi selesai', onTap: () => context.go('/history')),
          if (user?.role != 'cashier')
            _settingsTile(Icons.inventory_2_rounded, 'Manajemen Stok & Produk', subtitle: 'Katalog sparepart & stok', onTap: () => context.go('/products')),
          if (user?.role != 'cashier')
            _settingsTile(Icons.build_rounded, 'Manajemen Jasa', subtitle: 'Katalog jasa bengkel', onTap: () => context.go('/services')),
          if (user?.role == 'owner')
            _settingsTile(Icons.people_alt_rounded, 'Kelola Karyawan', subtitle: 'Manajemen akun kasir', onTap: () => context.go('/staff')),
          const Divider(height: 32),

          // Logout
          SizedBox(
            width: double.infinity, height: 48,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Keluar Akun'),
                    content: const Text('Apakah Anda yakin ingin keluar?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Ya, Keluar', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref.read(authStateProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                }
              },
              icon: const Icon(Icons.logout_rounded, color: AppColors.error),
              label: const Text('Keluar', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, {String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
      contentPadding: EdgeInsets.zero,
      dense: true,
      onTap: onTap,
    );
  }
}
