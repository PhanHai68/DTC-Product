import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AcompTroubleshootingMenuScreen extends StatelessWidget {
  const AcompTroubleshootingMenuScreen({super.key});

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Icon(icon, size: 36, color: Colors.blue),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hướng dẫn xử lý sự cố')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildMenuItem(
            context,
            title: 'Các lỗi thường gặp',
            icon: Icons.warning_amber_rounded,
            onTap: () {
              context.push('/acomp_common_errors');
            },
          ),
          _buildMenuItem(
            context,
            title: 'Tham số cài đặt bộ điều khiển DS8011',
            icon: Icons.tune_rounded,
            onTap: () {
              context.push('/acomp_ds8011_settings');
            },
          ),
          _buildMenuItem(
            context,
            title: 'Tài liệu vận hành',
            icon: Icons.menu_book_rounded,
            onTap: () {
              context.push('/acomp_operation_manual');
            },
          ),
        ],
      ),
    );
  }
}
