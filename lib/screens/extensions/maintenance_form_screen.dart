import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/maintenance_record.dart';
import '../../providers/maintenance_provider.dart';

class MaintenanceFormScreen extends StatefulWidget {
  final MaintenanceRecord? record;

  const MaintenanceFormScreen({super.key, this.record});

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _customerController;
  late final TextEditingController _modelController;
  late final TextEditingController _cycleController;
  late final TextEditingController _notesController;

  late DateTime _installDate;
  late DateTime _nextDate;
  late String _serviceType;
  bool _isSubmitting = false;

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final List<String> _serviceTypes = ['Bảo hành', 'Sửa chữa dịch vụ'];

  @override
  void initState() {
    super.initState();
    final rec = widget.record;
    _customerController = TextEditingController(text: rec?.customerName ?? '');
    _modelController = TextEditingController(text: rec?.machineModel ?? '');
    _cycleController = TextEditingController(
      text: rec != null ? rec.maintenanceCycleMonths.toString() : '3',
    );
    _notesController = TextEditingController(text: rec?.notes ?? '');
    _serviceType = rec?.serviceType ?? 'Bảo hành';

    _installDate = rec?.installDate ?? DateTime.now();
    _nextDate =
        rec?.nextMaintenanceDate ??
        addCalendarMonths(_installDate, int.parse(_cycleController.text));
  }

  @override
  void dispose() {
    _customerController.dispose();
    _modelController.dispose();
    _cycleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recalcNextDate() {
    final cycle = int.tryParse(_cycleController.text);
    if (cycle == null || cycle <= 0) return;
    setState(() {
      _nextDate = addCalendarMonths(_installDate, cycle);
    });
  }

  Future<void> _pickDate(bool isInstallDate) async {
    final initialDate = isInstallDate ? _installDate : _nextDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isInstallDate) {
          _installDate = picked;
          _recalcNextDate();
        } else {
          _nextDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final record = MaintenanceRecord(
      id: widget.record?.id,
      customerName: _customerController.text.trim(),
      machineModel: _modelController.text.trim(),
      installDate: _installDate,
      maintenanceCycleMonths: int.tryParse(_cycleController.text) ?? 3,
      nextMaintenanceDate: _nextDate,
      serviceType: _serviceType,
      notes: _notesController.text.trim(),
    );

    final provider = context.read<MaintenanceProvider>();
    try {
      if (record.id == null) {
        await provider.addRecord(record);
      } else {
        await provider.updateRecord(record);
      }
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu dữ liệu. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete() async {
    if (widget.record?.id != null) {
      setState(() => _isSubmitting = true);
      try {
        await context.read<MaintenanceProvider>().deleteRecord(
          widget.record!.id!,
        );
        if (mounted) context.pop();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể xóa dữ liệu. Vui lòng thử lại.'),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa thông tin máy' : 'Thêm máy mới'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _isSubmitting
                  ? null
                  : () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Xóa máy này?'),
                          content: const Text(
                            'Hành động này không thể hoàn tác.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Hủy'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await _delete();
                              },
                              child: const Text(
                                'Xóa',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _customerController,
                decoration: const InputDecoration(
                  labelText: 'Tên Khách Hàng / Nhà Máy',
                  prefixIcon: Icon(Icons.business_rounded),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Bắt buộc nhập' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model Máy',
                  prefixIcon: Icon(Icons.settings_input_component_rounded),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Bắt buộc nhập' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _serviceType,
                decoration: const InputDecoration(
                  labelText: 'Loại công việc',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: _serviceTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _serviceType = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ngày lắp đặt',
                          prefixIcon: Icon(Icons.calendar_today_rounded),
                        ),
                        child: Text(_dateFormat.format(_installDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cycleController,
                      decoration: const InputDecoration(
                        labelText: 'Chu kỳ (Tháng)',
                        suffixText: 'tháng',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _recalcNextDate(),
                      validator: (val) {
                        final cycle = int.tryParse(val ?? '');
                        if (cycle == null || cycle <= 0) {
                          return 'Nhập số tháng lớn hơn 0';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _pickDate(false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày bảo trì dự kiến tiếp theo',
                    prefixIcon: Icon(Icons.event_available_rounded),
                  ),
                  child: Text(
                    _dateFormat.format(_nextDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú thêm',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _save,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSubmitting ? 'Đang lưu...' : 'Lưu thông tin',
                  style: const TextStyle(fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
