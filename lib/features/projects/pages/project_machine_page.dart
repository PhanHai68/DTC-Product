import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/project_machine.dart';
import '../providers/project_provider.dart';

class ProjectMachinePage extends StatefulWidget {
  const ProjectMachinePage({super.key, required this.projectId});
  final String projectId;

  @override
  State<ProjectMachinePage> createState() => _ProjectMachinePageState();
}

class _ProjectMachinePageState extends State<ProjectMachinePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ProjectProvider>();
      if (provider.currentProject?.id != widget.projectId) {
        provider.loadProjectDetail(widget.projectId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    final project = provider.currentProject;
    return Scaffold(
      appBar: AppBar(title: const Text('Máy trong dự án')),
      body: provider.isLoadingDetail
          ? const Center(child: CircularProgressIndicator())
          : project == null
          ? const Center(child: Text('Không tìm thấy dự án'))
          : project.machines.isEmpty
          ? const _MachineEmpty()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: project.machines.length,
              itemBuilder: (_, index) {
                final machine = project.machines[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(14),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      child: const Icon(Icons.precision_manufacturing_outlined),
                    ),
                    title: Text(
                      machine.machineName,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        '${machine.model} • S/N ${machine.serialNumber}\n${machine.installationPosition.isEmpty ? machine.status : machine.installationPosition}',
                      ),
                    ),
                    isThreeLine: true,
                    onTap: () => _showHistory(machine),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) => value == 'edit'
                          ? _showForm(machine)
                          : _delete(machine),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                        PopupMenuItem(value: 'delete', child: Text('Xóa')),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: project == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add),
              label: const Text('Thêm máy'),
            ),
    );
  }

  Future<void> _showForm([ProjectMachine? existing]) async {
    final result = await showModalBottomSheet<ProjectMachine>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _MachineForm(projectId: widget.projectId, existing: existing),
    );
    if (result == null || !mounted) return;
    final ok = await context.read<ProjectProvider>().saveMachine(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Đã lưu thông tin máy.' : 'Không thể lưu máy.'),
      ),
    );
  }

  Future<void> _delete(ProjectMachine machine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa máy?'),
        content: Text('Máy “${machine.machineName}” sẽ bị xóa khỏi dự án.'),
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
    if (confirmed == true && mounted) {
      await context.read<ProjectProvider>().deleteMachine(machine);
    }
  }

  void _showHistory(ProjectMachine machine) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        maxChildSize: .92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              machine.machineName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 5),
            Text('Model: ${machine.model}\nSerial: ${machine.serialNumber}'),
            const SizedBox(height: 18),
            const _HistorySection(
              icon: Icons.info_outline,
              title: 'Thông tin máy',
            ),
            const _HistorySection(
              icon: Icons.handyman_outlined,
              title: 'Lịch sử lắp đặt',
            ),
            const _HistorySection(
              icon: Icons.photo_library_outlined,
              title: 'Hình ảnh',
            ),
            const _HistorySection(
              icon: Icons.science_outlined,
              title: 'Chạy thử',
            ),
            const _HistorySection(icon: Icons.build_outlined, title: 'Bảo trì'),
            const _HistorySection(
              icon: Icons.warning_amber_outlined,
              title: 'Sự cố',
            ),
            const _HistorySection(
              icon: Icons.description_outlined,
              title: 'Tài liệu',
            ),
            const _HistorySection(
              icon: Icons.timeline_outlined,
              title: 'Timeline',
            ),
          ],
        ),
      ),
    );
  }
}

class _MachineForm extends StatefulWidget {
  const _MachineForm({required this.projectId, this.existing});
  final String projectId;
  final ProjectMachine? existing;

  @override
  State<_MachineForm> createState() => _MachineFormState();
}

class _MachineFormState extends State<_MachineForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _model;
  late final TextEditingController _serial;
  late final TextEditingController _quantity;
  late final TextEditingController _position;
  late final TextEditingController _notes;
  late final TextEditingController _asset;
  late final TextEditingController _qr;
  late String _status;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _name = TextEditingController(text: item?.machineName ?? '');
    _model = TextEditingController(text: item?.model ?? '');
    _serial = TextEditingController(text: item?.serialNumber ?? '');
    _quantity = TextEditingController(text: '${item?.quantity ?? 1}');
    _position = TextEditingController(text: item?.installationPosition ?? '');
    _notes = TextEditingController(text: item?.notes ?? '');
    _asset = TextEditingController(text: item?.assetCode ?? '');
    _qr = TextEditingController(text: item?.qrCode ?? '');
    _status = item?.status ?? 'Chuẩn bị';
  }

  @override
  void dispose() {
    for (final item in [
      _name,
      _model,
      _serial,
      _quantity,
      _position,
      _notes,
      _asset,
      _qr,
    ]) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      12,
      16,
      MediaQuery.viewInsetsOf(context).bottom + 16,
    ),
    child: Form(
      key: _key,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Thêm máy' : 'Chỉnh sửa máy',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _input(_name, 'Tên máy', true),
            _input(_model, 'Model', true),
            _input(_serial, 'Serial Number', true),
            _input(_quantity, 'Số lượng', true, number: true),
            _input(_position, 'Vị trí lắp đặt', false),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Trạng thái'),
              items:
                  const [
                        'Chuẩn bị',
                        'Đã giao',
                        'Đang lắp đặt',
                        'Chạy thử',
                        'Đã bàn giao',
                        'Bảo trì',
                      ]
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
              onChanged: (value) => _status = value ?? _status,
            ),
            const SizedBox(height: 12),
            _input(_asset, 'Asset Code', false),
            _input(_qr, 'QR Code (chuẩn bị tương lai)', false),
            _input(_notes, 'Ghi chú', false, maxLines: 3),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Lưu máy'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _input(
    TextEditingController controller,
    String label,
    bool required, {
    bool number = false,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: number ? TextInputType.number : null,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập $label'
                : null
          : null,
    ),
  );

  void _save() {
    if (!_key.currentState!.validate()) return;
    final now = DateTime.now();
    Navigator.pop(
      context,
      ProjectMachine(
        id: widget.existing?.id ?? 'machine_${now.microsecondsSinceEpoch}',
        projectId: widget.projectId,
        productId: widget.existing?.productId,
        machineName: _name.text.trim(),
        model: _model.text.trim(),
        serialNumber: _serial.text.trim(),
        quantity: int.tryParse(_quantity.text) ?? 1,
        installationPosition: _position.text.trim(),
        status: _status,
        notes: _notes.text.trim(),
        assetCode: _asset.text.trim(),
        qrCode: _qr.text.trim(),
        syncStatus: SyncStatus.pending,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }
}

class _MachineEmpty extends StatelessWidget {
  const _MachineEmpty();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.precision_manufacturing_outlined,
            size: 60,
            color: Colors.blueGrey,
          ),
          SizedBox(height: 12),
          Text('Chưa có máy trong dự án'),
        ],
      ),
    ),
  );
}

/// Mục thông tin trong "Lịch sử máy" — hiện chỉ là nhãn tĩnh (chưa có màn
/// chi tiết riêng cho từng mục), nên KHÔNG hiện mũi tên ">" để tránh người
/// dùng hiểu lầm là bấm vào được.
class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: Theme.of(context).colorScheme.outline),
    title: Text(
      title,
      style: TextStyle(color: Theme.of(context).colorScheme.outline),
    ),
    enabled: false,
  );
}
