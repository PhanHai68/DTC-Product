import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/maintenance_report.dart';
import '../providers/maintenance_report_provider.dart';

/// Tạo Maintenance Report mới, hoặc sửa thông tin Customer/Machine/
/// Maintenance của 1 report có sẵn khi truyền [report]. Chỉ giữ các trường
/// thật sự cần khi lập báo cáo tại hiện trường; hỗ trợ nhiều kỹ sư cùng thực
/// hiện 1 lần bảo trì.
class MaintenanceReportFormScreen extends StatefulWidget {
  const MaintenanceReportFormScreen({super.key, this.report});

  final MaintenanceReport? report;

  @override
  State<MaintenanceReportFormScreen> createState() =>
      _MaintenanceReportFormScreenState();
}

class _MaintenanceReportFormScreenState
    extends State<MaintenanceReportFormScreen> {
  final _customerNameController = TextEditingController();
  final _factorySiteController = TextEditingController();
  final _machineModelController = TextEditingController();
  final _machineTagNameController = TextEditingController();
  final _machineRunningHoursController = TextEditingController();
  final _engineerControllers = <TextEditingController>[];
  DateTime _maintenanceDate = DateTime.now();
  bool _saving = false;

  bool get _isEditing => widget.report != null;

  @override
  void initState() {
    super.initState();
    final report = widget.report;
    if (report != null) {
      _customerNameController.text = report.customerName;
      _factorySiteController.text = report.factorySite;
      _machineModelController.text = report.machineModel;
      _machineTagNameController.text = report.machineTagName;
      _machineRunningHoursController.text = report.machineRunningHours;
      _maintenanceDate = report.maintenanceDate;
      for (final name in report.engineerNames) {
        _engineerControllers.add(TextEditingController(text: name));
      }
    }
    if (_engineerControllers.isEmpty) {
      _engineerControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _factorySiteController.dispose();
    _machineModelController.dispose();
    _machineTagNameController.dispose();
    _machineRunningHoursController.dispose();
    for (final controller in _engineerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addEngineerField() {
    setState(() => _engineerControllers.add(TextEditingController()));
  }

  void _removeEngineerField(int index) {
    setState(() => _engineerControllers.removeAt(index).dispose());
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _maintenanceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày bảo trì',
    );
    if (value == null || !mounted) return;
    setState(() => _maintenanceDate = value);
  }

  Future<void> _save() async {
    if (_customerNameController.text.trim().isEmpty &&
        _machineModelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập ít nhất Tên khách hàng hoặc Model.'),
        ),
      );
      return;
    }
    final engineerNames = _engineerControllers
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    setState(() => _saving = true);
    try {
      final provider = context.read<MaintenanceReportProvider>();
      final existing = widget.report;
      if (existing != null) {
        await provider.updateReport(
          existing.copyWith(
            customerName: _customerNameController.text.trim(),
            factorySite: _factorySiteController.text.trim(),
            machineModel: _machineModelController.text.trim(),
            machineTagName: _machineTagNameController.text.trim(),
            machineRunningHours: _machineRunningHoursController.text.trim(),
            maintenanceDate: _maintenanceDate,
            engineerNames: engineerNames,
          ),
        );
        if (!mounted) return;
        context.pop();
        return;
      }
      final report = await provider.createReport(
        customerName: _customerNameController.text.trim(),
        factorySite: _factorySiteController.text.trim(),
        machineModel: _machineModelController.text.trim(),
        machineTagName: _machineTagNameController.text.trim(),
        machineRunningHours: _machineRunningHoursController.text.trim(),
        maintenanceDate: _maintenanceDate,
        engineerNames: engineerNames,
      );
      if (!mounted) return;
      context.pushReplacement('/maintenance_report/${report.id}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chưa thể lưu báo cáo: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Sửa thông tin báo cáo' : 'Báo cáo bảo trì mới',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _FormSection(
            title: 'THÔNG TIN KHÁCH HÀNG',
            children: [
              TextField(
                controller: _customerNameController,
                decoration: const InputDecoration(labelText: 'Tên khách hàng'),
              ),
              TextField(
                controller: _factorySiteController,
                decoration: const InputDecoration(labelText: 'Địa điểm'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: 'THÔNG TIN MÁY',
            children: [
              TextField(
                controller: _machineModelController,
                decoration: const InputDecoration(labelText: 'Model'),
              ),
              TextField(
                controller: _machineTagNameController,
                decoration: const InputDecoration(labelText: 'Tagname'),
              ),
              TextField(
                controller: _machineRunningHoursController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số giờ vận hành'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: 'THÔNG TIN BẢO TRÌ',
            children: [
              for (var i = 0; i < _engineerControllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _engineerControllers[i],
                          decoration: InputDecoration(
                            labelText: i == 0
                                ? 'Tên kỹ sư'
                                : 'Tên kỹ sư ${i + 1}',
                          ),
                        ),
                      ),
                      if (_engineerControllers.length > 1)
                        IconButton(
                          onPressed: () => _removeEngineerField(i),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addEngineerField,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Thêm kỹ sư'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Ngày bảo trì'),
                subtitle: Text(_formatDate(_maintenanceDate)),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: const Text('Đổi ngày'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('maintenance_report_save_button'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Lưu thay đổi' : 'Tạo báo cáo'),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
