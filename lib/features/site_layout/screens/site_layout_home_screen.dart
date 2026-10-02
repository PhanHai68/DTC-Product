import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/site_layout_provider.dart';

class SiteLayoutHomeScreen extends StatefulWidget {
  const SiteLayoutHomeScreen({super.key});

  @override
  State<SiteLayoutHomeScreen> createState() => _SiteLayoutHomeScreenState();
}

class _SiteLayoutHomeScreenState extends State<SiteLayoutHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SiteLayoutProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SiteLayoutProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Bố trí mặt bằng')),
      body: RefreshIndicator(
        onRefresh: provider.initialize,
        child: provider.isLoading && provider.projects.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.projects.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.architecture_rounded, size: 72),
                  SizedBox(height: 18),
                  Text(
                    'Chưa có dự án khảo sát',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tạo dự án để bắt đầu vẽ mặt bằng và bố trí thiết bị theo kích thước thực tế.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                itemCount: provider.projects.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final project = provider.projects[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () =>
                          context.push('/site-layout/project/${project.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(child: Icon(Icons.map_outlined)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    project.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [project.customer, project.location]
                                        .where((item) => item.isNotEmpty)
                                        .join(' · '),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${project.dimensionUnit.formatValue(project.siteWidthMm)} × ${project.dimensionUnit.formatValue(project.siteLengthMm)} ${project.dimensionUnit.symbol} · Cập nhật ${DateFormat('dd/MM/yyyy HH:mm').format(project.updatedAt)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _confirmDelete(
                                    context,
                                    project.id,
                                    project.name,
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('Xóa dự án'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/site-layout/project/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tạo dự án'),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String projectId,
    String name,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa dự án?'),
        content: Text('Dự án “$name” và toàn bộ phương án sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      await context.read<SiteLayoutProvider>().deleteProject(projectId);
    }
  }
}
