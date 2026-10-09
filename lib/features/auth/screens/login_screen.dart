import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.auth});

  /// Mặc định dùng [AuthService.instance]; truyền vào khi test.
  final AuthService? auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AuthService _auth = widget.auth ?? AuthService.instance;
  late final _emailController = TextEditingController(text: _auth.email);
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Đăng nhập thành công → router tự chuyển về trang chủ.
      await _auth.signIn(_emailController.text, _passwordController.text);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!_looksLikeEmail(email)) {
      setState(() => _error = 'Nhập email trước rồi bấm "Quên mật khẩu?".');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _auth.sendPasswordReset(email);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Nếu $email có tài khoản, email hướng dẫn đặt lại mật khẩu '
            'đã được gửi (xem cả thư mục Spam).',
          ),
        ),
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListenableBuilder(
                listenable: _auth,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/dtc_product_wordmark_full.png',
                      height: 52,
                      semanticLabel: 'DTC Product',
                    ),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _auth.isVerifying && _auth.canRetryVerify
                            ? _buildVerifying(theme)
                            : _buildForm(theme, colorScheme),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifying(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text('Đang xác minh tài khoản...', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildForm(ThemeData theme, ColorScheme colorScheme) {
    final notice = _auth.notice;
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Đăng nhập', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (notice != null) ...[
              _MessageBanner(
                message: notice,
                color: colorScheme.tertiaryContainer,
                onColor: colorScheme.onTertiaryContainer,
                icon: Icons.info_outline_rounded,
                action: _auth.canRetryVerify
                    ? TextButton(
                        onPressed: () => _auth.verify(force: true),
                        child: const Text('Thử lại'),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              key: const Key('login_email'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) => _looksLikeEmail(value?.trim() ?? '')
                  ? null
                  : 'Nhập email hợp lệ',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('login_password'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Nhập mật khẩu' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _MessageBanner(
                message: _error!,
                color: colorScheme.errorContainer,
                onColor: colorScheme.onErrorContainer,
                icon: Icons.error_outline_rounded,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('login_submit'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Đăng nhập'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _submitting ? null : _resetPassword,
              child: const Text('Quên mật khẩu?'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    required this.message,
    required this.color,
    required this.onColor,
    required this.icon,
    this.action,
  });

  final String message;
  final Color color;
  final Color onColor;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: onColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: onColor)),
          ),
          ?action,
        ],
      ),
    );
  }
}
