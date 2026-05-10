import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/utils/app_toast.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganti Password')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_oldPassCtrl, 'Password Lama', isPassword: true),
          const SizedBox(height: 12),
          _field(_newPassCtrl, 'Password Baru', isPassword: true),
          _field(_confirmPassCtrl, 'Konfirmasi Password Baru', isPassword: true),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: () {
                // Mock logic for password change
                AppToast.show(context, 'Password berhasil diubah (Demo Mode)', type: ToastType.success);
                context.go('/settings');
              },
              child: const Text('Simpan Password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        obscureText: isPassword,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
