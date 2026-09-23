import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/maintenance_report.dart';
import '../providers/maintenance_report_provider.dart';

/// Tạo Maintenance Report mới, hoặc sửa thông tin Customer/Machine/
/// Maintenance của 1 report có sẵn khi truyền [report]. Không bắt buộc nhập
/// tất cả trường (chỉ Tên khách hàng hoặc Tên máy cần có tối thiểu 1 để dễ
/// nhận diện report trong danh sách).
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
  final _contactPersonController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _machineNameController = TextEditingController();
  final _machineTypeController = TextEditingController();
  final _machineModelController = TextEditingController();
  final _machineSerialController = TextEditingController();
  final _machineRunningHoursController = TextEditingController();
  final _machineLocationController = TextEditingController();
  final _engineerNameController = TextEditingController();
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
      _contactPersonController.text = report.contactPerson;
      _contactPhoneController.text = report.contactPhone;
      _machineNameController.text = report.machineName;
      _machineTypeController.text = report.machineType;
      _machineModelController.text = report.machineModel;
      _machineSerialController.text = report.machineSerial;
      _machineRunningHoursController.text = report.machineRunningHours;
      _machineLocationController.text = report.machineLocation;
      _engineerNameController.text = report.engineerName;
      _maintenanceDate = report.maintenanceDate;
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _factorySiteController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    _machineNameController.dispose();
    _machineTypeController.dispose();
    _machineModelController.dispose();
    _machineSerialController.dispose();
    _machineRunningHoursController.dispose();
    _machineLocationController.dispose();
    _engineerNameController.dispose();
    super.dispose();
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
        _machineNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập ít nhất Tên khách hàng hoặc Tên máy.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final provider = context.read<MaintenanceReportProvider>();
      final existing = widget.report;
      if (existing != null) {
        await provider.updateReport(
          existing.copyWith(
            customerName: _customerNameController.text.trim(),
            factorySite: _factorySiteController.text.trim(),
            contactPerson: _contactPersonController.text.trim(),
            contactPhone: _contactPhoneController.text.trim(),
            machineName: _machineNameController.text.trim(),
            machineType: _machineTypeController.text.trim(),
            machineModel: _machineModelController.text.trim(),
            machineSerial: _machineSerialController.text.trim(),
            machineRunningHours: _machineRunningHoursController.text.trim(),
            machineLocation: _machineLocationController.text.trim(),
            maintenanceDate: _maintenanceDate,
            engineerName: _engineerNameController.text.trim(),
          ),
        );
        if (!mounted) return;
        context.pop();
        return;
      }
      final report = await provider.createReport(
        customerName: _customerNameController.text.trim(),
        factorySite: _factorySiteController.text.trim(),
        contactPerson: _contactPersonController.text.trim(),
        contactPhone: _contactPhoneController.text.trim(),
        machineName: _machineNameController.text.trim(),
        machineType: _machineTypeController.text.trim(),
        machineModel: _machineModelController.text.trim(),
        machineSerial: _machineSerialController.text.trim(),
        machineRunningHours: _machineRunningHoursController.text.trim(),
        machineLocation: _machineLocationController.text.trim(),
        maintenanceDate: _maintenanceDate,
        engineerName: _engineerNameController.text.trim(),
      );
      if (!mounted) return;
      context.pushReplacement('/maintenance_report/${report.id}');
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
          _isEditing ? 'Edit Report Info' : 'New Maintenance Report',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _FormSection(
            title: 'CUSTOMER INFORMATION',
            children: [
              TextField(
                controller: _customerNameController,
                decoration: const InputDecoration(labelText: 'Customer Name'),
              ),
              TextField(
                controller: _factorySiteController,
                decoration: const InputDecoration(
                  labelText: 'Factory / Site Name',
                ),
              ),
              TextField(
                controller: _contactPersonController,
                decoration: const InputDecoration(labelText: 'Contact Person'),
              ),
              TextField(
                controller: _contactPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: 'MACHINE INFORMATION',
            children: [
              TextField(
                controller: _machineNameController,
                decoration: const InputDecoration(labelText: 'Machine Name'),
              ),
              TextField(
                controller: _machineTypeController,
                decoration: const InputDecoration(labelText: 'Machine Type'),
              ),
              TextField(
                controller: _machineModelController,
                decoration: const InputDecoration(labelText: 'Model'),
              ),
              TextField(
                controller: _machineSerialController,
                decoration: const InputDecoration(labelText: 'Serial Number'),
              ),
              TextField(
                controller: _machineRunningHoursController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Running Hours'),
              ),
              TextField(
                controller: _machineLocationController,
                decoration: const InputDecoration(
                  labelText: 'Machine Location',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: 'MAINTENANCE INFORMATION',
            children: [
              TextField(
                controller: _engineerNameController,
                decoration: const InputDecoration(labelText: 'Engineer Name'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Maintenance Date'),
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
                : Text(_isEditing ? 'Save Changes' : 'Create Report'),
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
