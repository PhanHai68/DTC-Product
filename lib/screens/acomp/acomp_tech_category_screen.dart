import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AcompTechCategoryScreen extends StatelessWidget {
  const AcompTechCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục Máy nén khí')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildCategoryCard(
            context,
            title: 'Máy nén khí trục vít biến tần',
            subtitle: 'Model: ACP-PV',
            icon: Icons.speed,
            onTap: () {
              context.push('/acomp_tech_detail', extra: 'PV');
            },
          ),
          _buildCategoryCard(
            context,
            title: 'Máy nén khí trục vít tốc độ cố định',
            subtitle: 'Model: ACP-F',
            icon: Icons.settings,
            onTap: () {
              context.push('/acomp_tech_detail', extra: 'F');
            },
          ),
          _buildCategoryCard(
            context,
            title: 'Máy nén khí trục vít 4 trong 1',
            subtitle: 'Đang cập nhật dữ liệu',
            icon: Icons.layers,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Dữ liệu đang được cập nhật, vui lòng thử lại sau.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12.0,
          horizontal: 16.0,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.teal, size: 32),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 20),
        onTap: onTap,
      ),
    );
  }
}
