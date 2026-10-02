import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/site_layout_models.dart';
import '../providers/site_layout_provider.dart';

class SiteProjectFormScreen extends StatefulWidget {
  const SiteProjectFormScreen({super.key});

  @override
  State<SiteProjectFormScreen> createState() => _SiteProjectFormScreenState();
}

class _SiteProjectFormScreenState extends State<SiteProjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _surveyor = TextEditingController();
  final _width = TextEditingController();
  final _length = TextEditingController();
  SiteDimensionUnit _unit = SiteDimensionUnit.meter;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_name, _location, _surveyor, _width, _length]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String value) => _unit.parseToMillimeters(value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo dự án khảo sát')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên dự án *'),
              validator: (value) => value?.trim().isEmpty == true
                  ? 'Vui lòng nhập tên dự án.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Địa điểm *'),
              validator: (value) => value?.trim().isEmpty == true
                  ? 'Vui lòng nhập địa điểm.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _surveyor,
              decoration: const InputDecoration(labelText: 'Người khảo sát *'),
              validator: (value) => value?.trim().isEmpty == true
                  ? 'Vui lòng nhập người khảo sát.'
                  : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kích thước mặt bằng lắp đặt',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SegmentedButton<SiteDimensionUnit>(
                  showSelectedIcon: false,
                  segments: SiteDimensionUnit.values
                      .map(
                        (unit) => ButtonSegment(
                          value: unit,
                          label: Text(unit.symbol),
                        ),
                      )
                      .toList(),
                  selected: {_unit},
                  onSelectionChanged: (selection) =>
                      _changeUnit(selection.first),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _dimensionField(_width, 'Chiều rộng *')),
                const SizedBox(width: 10),
                Expanded(child: _dimensionField(_length, 'Chiều dài *')),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: const Text('Tạo và mở mặt bằng'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dimensionField(TextEditingController controller, String label) {
    final required = label.contains('*');
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: _unit.symbol),
      validator: (value) {
        if (!required && value!.trim().isEmpty) return null;
        final number = _number(value ?? '');
        return number == null || number <= 0
            ? 'Kích thước không hợp lệ.'
            : null;
      },
    );
  }

  void _changeUnit(SiteDimensionUnit next) {
    if (next == _unit) return;
    for (final controller in [_width, _length]) {
      final millimeters = _unit.parseToMillimeters(controller.text);
      if (millimeters != null) controller.text = next.formatValue(millimeters);
    }
    setState(() => _unit = next);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final project = await context.read<SiteLayoutProvider>().createProject(
      name: _name.text,
      customer: '',
      location: _location.text,
      surveyor: _surveyor.text,
      surveyDate: DateTime.now(),
      siteWidthMm: _number(_width.text)!,
      siteLengthMm: _number(_length.text)!,
      dimensionUnit: _unit,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (project != null) context.go('/site-layout/project/${project.id}');
  }
}
