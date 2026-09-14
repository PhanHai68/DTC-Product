import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/maintenance_record.dart';
import '../../providers/maintenance_provider.dart';

class MaintenanceListScreen extends StatelessWidget {
  const MaintenanceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Lịch Bảo trì'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              hintText: 'Tìm kiếm theo tên hoặc model...',
              leading: const Icon(Icons.search),
              onChanged: (value) {
                context.read<MaintenanceProvider>().setSearchQuery(value);
              },
            ),
          ),
        ),
      ),
      body: Consumer<MaintenanceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final records = provider.filteredRecords;

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.engineering_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.searchQuery.isEmpty 
                      ? 'Chưa có dữ liệu bảo trì.\nBấm nút + để thêm máy mới.'
                      : 'Không tìm thấy kết quả nào.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          // Phân loại records
          final sortedRecords = List<MaintenanceRecord>.from(records);
          sortedRecords.sort((a, b) => a.status.compareTo(b.status));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedRecords.length,
            itemBuilder: (context, index) {
              final record = sortedRecords[index];
              return _MaintenanceCard(record: record);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/maintenance_form'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final MaintenanceRecord record;

  const _MaintenanceCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Status colors
    final statusColor = switch (record.status) {
      0 => Colors.red.shade700,
      1 => Colors.orange.shade700,
      _ => Colors.green.shade700,
    };
    
    final statusText = switch (record.status) {
      0 => 'Quá hạn bảo trì',
      1 => 'Sắp đến hạn',
      _ => 'Hoạt động tốt',
    };

    final statusIcon = switch (record.status) {
      0 => Icons.warning_rounded,
      1 => Icons.error_outline_rounded,
      _ => Icons.check_circle_outline_rounded,
    };

    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/maintenance_form', extra: record),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: statusColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      record.serviceType,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.customerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.settings_input_component_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Model: ${record.machineModel}',
                        style: TextStyle(
                          fontSize: 15,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ngày lắp đặt',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              dateFormat.format(record.installDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hạn tiếp theo',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              dateFormat.format(record.nextMaintenanceDate),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: record.status == 0 ? Colors.red : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (record.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Ghi chú: ${record.notes}',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (record.status <= 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: () {
                    context.read<MaintenanceProvider>().completeMaintenance(record);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã cập nhật chu kỳ bảo trì mới!')),
                    );
                  },
                  icon: const Icon(Icons.build_circle_outlined),
                  label: const Text('Xác nhận Đã bảo trì'),
                  style: FilledButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
