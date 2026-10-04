import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/fault_bank_provider.dart';

/// Form tên kỹ sư. Dùng cho lần đầu mở module và trong Cài đặt. Mã kỹ sư
/// (gắn vào mã bản ghi để gộp dữ liệu) được app tự sinh, không cần nhập.
class FaultProfileForm extends StatefulWidget {
  const FaultProfileForm({
    super.key,
    required this.onSaved,
    this.submitLabel = 'Lưu hồ sơ',
  });

  final VoidCallback onSaved;
  final String submitLabel;

  @override
  State<FaultProfileForm> createState() => _FaultProfileFormState();
}

class _FaultProfileFormState extends State<FaultProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<FaultBankProvider>().profile;
    _name = TextEditingController(text: profile?.engineerName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<FaultBankProvider>().saveProfile(
        engineerName: _name.text,
      );
      if (mounted) widget.onSaved();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không lưu được: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('fault_profile_name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _saving ? null : _save(),
            decoration: const InputDecoration(
              labelText: 'Tên kỹ sư *',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Nhập tên kỹ sư' : null,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('fault_profile_save'),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
