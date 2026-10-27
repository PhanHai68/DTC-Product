import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'acomp_line_filter_tab.dart';

class AcompTechCategoryScreen extends StatelessWidget {
  const AcompTechCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Các tab để dễ phân loại: máy nén khí, máy sấy khí, lọc đường ống.
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thông số kỹ thuật'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Máy nén khí'),
              Tab(text: 'Máy sấy khí'),
              Tab(text: 'Lọc đường ống'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _compressors(context),
            ListView(
              key: const Key('dryer_category_list'),
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildCategoryCard(
                  context,
                  title: 'Máy sấy khí tác nhân lạnh',
                  subtitle: 'Model: ACD',
                  badgeText: 'SẤY\nLẠNH',
                  onTap: () => context.push('/acomp_refrigerated_dryer'),
                ),
              ],
            ),
            const AcompLineFilterTab(),
          ],
        ),
      ),
    );
  }

  Widget _compressors(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildCategoryCard(
          context,
          title: 'Máy nén khí trục vít biến tần',
          subtitle: 'Model: ACP-PV',
          badgeText: 'PM\nVFD',
          onTap: () {
            context.push('/acomp_tech_detail?type=PV', extra: 'PV');
          },
        ),
        _buildCategoryCard(
          context,
          title: 'Máy nén khí trục vít tốc độ cố định',
          subtitle: 'Model: ACP-F',
          badgeText: 'FIXED\nSPEED',
          onTap: () {
            context.push('/acomp_tech_detail?type=F', extra: 'F');
          },
        ),
        _buildCategoryCard(
          context,
          title: 'Máy nén khí trục vít 4 trong 1',
          subtitle: 'Model: ACA-F, ACA-PV',
          badgeText: '4 IN 1',
          onTap: () {
            context.push('/acomp_tech_detail?type=4IN1', extra: '4IN1');
          },
        ),
        _buildCategoryCard(
          context,
          title: 'Máy nén khí không dầu',
          subtitle: 'Model: AFR-F, AFR-PV',
          badgeText: 'OIL-\nFREE',
          onTap: () => context.push('/acomp_oil_free'),
        ),
        // Chưa có dữ liệu: nội dung sẽ bổ sung sau.
        _buildCategoryCard(
          context,
          title: 'Máy nén khí trục vít 2 cấp',
          subtitle: 'Đang cập nhật',
          badgeText: '2-\nSTAGE',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const _UpcomingCategoryScreen(
                title: 'Máy nén khí trục vít 2 cấp',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badgeText,
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
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              badgeText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.teal,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
          ),
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

/// Dòng máy chưa có dữ liệu thông số.
class _UpcomingCategoryScreen extends StatelessWidget {
  const _UpcomingCategoryScreen({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty_rounded,
                size: 56,
                color: Colors.teal.shade300,
              ),
              const SizedBox(height: 12),
              const Text(
                'Thông số kỹ thuật của dòng máy này đang được cập nhật.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
