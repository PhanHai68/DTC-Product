import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Mở hộp thoại đổi mật khẩu; trả về `true` nếu đổi thành công.
Future<bool?> showChangePasswordDialog(
  BuildContext context, {
  AuthService? auth,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ChangePasswordDialog(auth: auth),
);

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key, this.auth});

  /// Mặc định dùng [AuthService.instance]; truyền vào khi test.
  final AuthService? auth;

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  static const _minLength = 6;

  late final AuthService _auth = widget.auth ?? AuthService.instance;
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _auth.changePassword(_currentController.text, _newController.text);
      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    suffixIcon: IconButton(
      tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      icon: Icon(
        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      onPressed: () => setState(() => _obscure = !_obscure),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Đổi mật khẩu'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _auth.email ?? '',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('current_password_field'),
                controller: _currentController,
                obscureText: _obscure,
                enabled: !_submitting,
                autofillHints: const [AutofillHints.password],
                decoration: _decoration('Mật khẩu hiện tại'),
                validator: (value) => (value ?? '').isEmpty
                    ? 'Nhập mật khẩu hiện tại'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('new_password_field'),
                controller: _newController,
                obscureText: _obscure,
                enabled: !_submitting,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _decoration('Mật khẩu mới'),
                validator: (value) {
                  final text = value ?? '';
                  if (text.length < _minLength) {
                    return 'Mật khẩu mới cần ít nhất $_minLength ký tự';
                  }
                  if (text == _currentController.text) {
                    return 'Mật khẩu mới phải khác mật khẩu hiện tại';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('confirm_password_field'),
                controller: _confirmController,
                obscureText: _obscure,
                enabled: !_submitting,
                decoration: _decoration('Nhập lại mật khẩu mới'),
                onFieldSubmitted: (_) => _submit(),
                validator: (value) => value != _newController.text
                    ? 'Mật khẩu nhập lại không khớp'
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Sau khi đổi, các thiết bị khác đang đăng nhập tài khoản này '
                'sẽ phải đăng nhập lại bằng mật khẩu mới.',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Đổi mật khẩu'),
        ),
      ],
    );
  }
}
