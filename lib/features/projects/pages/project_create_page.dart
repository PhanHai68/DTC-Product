import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/project_provider.dart';

class ProjectCreatePage extends StatefulWidget {
  const ProjectCreatePage({super.key});

  @override
  State<ProjectCreatePage> createState() => _ProjectCreatePageState();
}

class _ProjectCreatePageState extends State<ProjectCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _projectName = TextEditingController();
  final _machineModel = TextEditingController();
  final _location = TextEditingController();
  final _engineer = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _projectName,
      _machineModel,
      _location,
      _engineer,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo dự án')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            _Section(
              title: 'Thông tin dự án',
              children: [
                _field(_projectName, 'Tên nhà máy', required: true),
                _field(_machineModel, 'Model máy', required: true),
                _field(_location, 'Địa điểm', required: true),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Phụ trách',
              children: [_field(_engineer, 'Kỹ sư phụ trách', required: true)],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: provider.isSaving ? null : _submit,
            icon: provider.isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Tạo dự án'),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextCapitalization capitalization = TextCapitalization.sentences,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      textCapitalization: capitalization,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: maxLines > 1,
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập $label'
                : null
          : null,
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final id = await context.read<ProjectProvider>().createProject(
      projectName: _projectName.text,
      machineModel: _machineModel.text,
      location: _location.text,
      technicalEngineer: _engineer.text,
    );
    if (!mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<ProjectProvider>().error ?? 'Không thể tạo dự án.',
          ),
        ),
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}
