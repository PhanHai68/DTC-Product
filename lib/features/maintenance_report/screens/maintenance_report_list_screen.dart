import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/maintenance_report.dart';
import '../providers/maintenance_report_provider.dart';
import '../services/maintenance_report_share.dart';

/// Màn hình chính "Báo cáo bảo trì" — New Report / Recent Reports.
class MaintenanceReportListScreen extends StatefulWidget {
  const MaintenanceReportListScreen({super.key});

  @override
  State<MaintenanceReportListScreen> createState() =>
      _MaintenanceReportListScreenState();
}

class _MaintenanceReportListScreenState
    extends State<MaintenanceReportListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<MaintenanceReportProvider>().loadReports(),
    );
  }

  Future<void> _confirmDelete(MaintenanceReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa báo cáo bảo trì?'),
        content: Text(
          'Toàn bộ ảnh, dữ liệu và PDF của "${report.customerName.isEmpty ? report.machineName : report.customerName}" '
          'sẽ bị xóa vĩnh viễn, không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<MaintenanceReportProvider>().deleteReport(report.id);
  }

  Future<void> _generateAndShare(MaintenanceReport report) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await context
          .read<MaintenanceReportProvider>()
          .generatePdfBytes(report.id);
      if (!mounted) return;
      final fileName = maintenanceReportFileName(report);
      await shareMaintenanceReportPdf(
        bytes: bytes,
        fileName: fileName,
        report: report,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Chưa thể tạo/chia sẻ PDF: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo bảo trì')),
      body: Consumer<MaintenanceReportProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingList && provider.reports.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final palette = DtcPalette.of(context);
          if (provider.reports.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      size: 64,
                      color: palette.muted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có báo cáo bảo trì nào.\nBấm "Báo cáo mới" để bắt đầu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.muted, fontSize: 15),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: provider.loadReports,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: provider.reports.length,
              itemBuilder: (context, index) {
                final report = provider.reports[index];
                return _ReportCard(
                  report: report,
                  onTap: () => context.push('/maintenance_report/${report.id}'),
                  onDelete: () => _confirmDelete(report),
                  onGeneratePdf: () => _generateAndShare(report),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('maintenance_report_new_button'),
        onPressed: () => context.push('/maintenance_report/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Báo cáo mới'),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onTap,
    required this.onDelete,
    required this.onGeneratePdf,
  });

  final MaintenanceReport report;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onGeneratePdf;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final isCompleted = report.isCompleted;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.customerName.isEmpty
                          ? 'Chưa đặt tên khách hàng'
                          : report.customerName,
                      style: TextStyle(
                        color: palette.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(isCompleted: isCompleted),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (report.machineName.isNotEmpty) report.machineName,
                  if (report.machineModel.isNotEmpty) report.machineModel,
                ].join(' — '),
                style: TextStyle(color: palette.ink, fontSize: 13.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('dd/MM/yyyy').format(report.maintenanceDate)}'
                '${report.engineerName.isEmpty ? '' : ' · ${report.engineerName}'}',
                style: TextStyle(color: palette.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onGeneratePdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                    label: const Text('PDF & Chia sẻ'),
                  ),
                  IconButton(
                    tooltip: 'Xóa',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final color = isCompleted ? palette.cyan : const Color(0xFFEA580C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isCompleted ? 'Hoàn thành' : 'Nháp',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
