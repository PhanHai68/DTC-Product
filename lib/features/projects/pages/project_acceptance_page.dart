import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/project_acceptance.dart';
import '../models/project_machine.dart';
import '../providers/project_provider.dart';

class ProjectAcceptancePage extends StatefulWidget {
  const ProjectAcceptancePage({super.key, required this.projectId});
  final String projectId;

  @override
  State<ProjectAcceptancePage> createState() => _ProjectAcceptancePageState();
}

class _ProjectAcceptancePageState extends State<ProjectAcceptancePage> {
  bool _initialized = false;
  bool _installation = false;
  bool _testing = false;
  bool _training = false;
  AcceptanceStatus _status = AcceptanceStatus.pending;
  DateTime? _date;
  ProjectMachine? _machine;
  final _customerRepresentative = TextEditingController();
  final _dtcRepresentative = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ProjectProvider>();
      if (provider.currentProject?.id != widget.projectId) {
        await provider.loadProjectDetail(widget.projectId);
      }
      if (mounted) _initialize(provider);
    });
  }

  void _initialize(ProjectProvider provider) {
    if (_initialized) return;
    final value = provider.acceptance;
    _installation = value?.installationCompleted ?? false;
    _testing = value?.testingCompleted ?? false;
    _training = value?.trainingCompleted ?? false;
    _status = value?.status ?? AcceptanceStatus.pending;
    _date = value?.acceptanceDate;
    _customerRepresentative.text = value?.customerRepresentative ?? '';
    _dtcRepresentative.text =
        value?.dtcRepresentative ??
        provider.currentProject?.technicalEngineer ??
        '';
    final machines =
        provider.currentProject?.machines ?? const <ProjectMachine>[];
    final selected = machines.where((item) => item.id == value?.machineId);
    _machine = selected.isEmpty ? null : selected.first;
    _notes.text = value?.notes ?? '';
    _initialized = true;
    setState(() {});
  }

  @override
  void dispose() {
    _customerRepresentative.dispose();
    _dtcRepresentative.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final project = provider.currentProject;
    return Scaffold(
      appBar: AppBar(title: const Text('Nghiệm thu')),
      body: provider.isLoadingDetail || project == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          project.projectName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(project.customerName),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<ProjectMachine?>(
                          initialValue: _machine,
                          decoration: const InputDecoration(labelText: 'Máy'),
                          items: [
                            const DropdownMenuItem<ProjectMachine?>(
                              value: null,
                              child: Text('Toàn dự án'),
                            ),
                            ...project.machines.map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(
                                  '${item.machineName} • ${item.model} • ${item.serialNumber}',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _machine = value),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _installation,
                          title: const Text('Đã hoàn thành lắp đặt'),
                          onChanged: (value) =>
                              setState(() => _installation = value ?? false),
                        ),
                        CheckboxListTile(
                          value: _testing,
                          title: const Text('Đã hoàn thành chạy thử'),
                          onChanged: (value) =>
                              setState(() => _testing = value ?? false),
                        ),
                        CheckboxListTile(
                          value: _training,
                          title: const Text('Đã hoàn thành đào tạo'),
                          onChanged: (value) =>
                              setState(() => _training = value ?? false),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField<AcceptanceStatus>(
                          initialValue: _status,
                          decoration: const InputDecoration(
                            labelText: 'Trạng thái nghiệm thu',
                          ),
                          items: AcceptanceStatus.values
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _status = value ?? _status),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                          ),
                          leading: const Icon(Icons.event_available_outlined),
                          title: const Text('Ngày nghiệm thu'),
                          subtitle: Text(
                            _date == null
                                ? 'Chưa chọn'
                                : '${_date!.day}/${_date!.month}/${_date!.year}',
                          ),
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customerRepresentative,
                          decoration: const InputDecoration(
                            labelText: 'Đại diện khách hàng',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _dtcRepresentative,
                          decoration: const InputDecoration(
                            labelText: 'Đại diện DTC / kỹ sư',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notes,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú / điều kiện nghiệm thu',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.draw_outlined),
                          title: Text('Chữ ký khách hàng và DTC'),
                          subtitle: Text(
                            'Cấu trúc dữ liệu đã sẵn sàng để bổ sung chữ ký số trong phiên bản sau.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: project == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: provider.isSaving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Lưu nghiệm thu'),
                ),
              ),
            ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted) setState(() => _date = value);
  }

  Future<void> _save() async {
    final provider = context.read<ProjectProvider>();
    final project = provider.currentProject!;
    final existing = provider.acceptance;
    final now = DateTime.now();
    final value = ProjectAcceptance(
      id: existing?.id ?? 'acceptance_${now.microsecondsSinceEpoch}',
      projectId: widget.projectId,
      machineId: _machine?.id,
      installationCompleted: _installation,
      testingCompleted: _testing,
      trainingCompleted: _training,
      acceptanceDate: _date,
      customerRepresentative: _customerRepresentative.text.trim(),
      dtcRepresentative: _dtcRepresentative.text.trim(),
      notes: _notes.text.trim(),
      status: _status,
      customerSignature: existing?.customerSignature ?? '',
      dtcSignature: existing?.dtcSignature ?? '',
      customerName: project.customerName,
      dtcEngineer: _dtcRepresentative.text.trim(),
      acceptedAt: _status == AcceptanceStatus.accepted
          ? now
          : existing?.acceptedAt,
      syncStatus: SyncStatus.pending,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final ok = await provider.saveAcceptance(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Đã lưu thông tin nghiệm thu.' : 'Không thể lưu nghiệm thu.',
          ),
        ),
      );
    }
  }
}
