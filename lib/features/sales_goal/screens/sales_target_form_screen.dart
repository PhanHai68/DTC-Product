import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/sales_goal_provider.dart';
import '../utils/sales_goal_action.dart';
import '../utils/sales_goal_format.dart';

class SalesTargetFormScreen extends StatefulWidget {
  const SalesTargetFormScreen({super.key});

  @override
  State<SalesTargetFormScreen> createState() => _SalesTargetFormScreenState();
}

class _SalesTargetFormScreenState extends State<SalesTargetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _monthController;
  late final TextEditingController _quarterController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final summary = context.read<SalesGoalProvider>().summary;
    _monthController = TextEditingController(
      text: summary?.monthlyTarget == 0
          ? ''
          : '${summary?.monthlyTarget ?? ''}',
    );
    _quarterController = TextEditingController(
      text: summary?.quarterlyTarget == 0
          ? ''
          : '${summary?.quarterlyTarget ?? ''}',
    );
  }

  @override
  void dispose() {
    _monthController.dispose();
    _quarterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final quarter = ((now.month - 1) ~/ 3) + 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết lập mục tiêu')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('sales_month_target'),
              controller: _monthController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Mục tiêu tháng ${now.month}/${now.year}',
                suffixText: 'VND',
              ),
              validator: _validateAmount,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('sales_quarter_target'),
              controller: _quarterController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Mục tiêu quý $quarter/${now.year}',
                suffixText: 'VND',
              ),
              validator: _validateAmount,
            ),
            const SizedBox(height: 10),
            const Text(
              'Mục tiêu của từng kỳ được lưu riêng. Khi sang tháng hoặc quý mới, dữ liệu lịch sử không bị xóa.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Lưu mục tiêu'),
            ),
            if (_hasTargets) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Xóa mục tiêu kỳ này'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasTargets {
    final summary = context.read<SalesGoalProvider>().summary;
    return (summary?.monthlyTarget ?? 0) > 0 ||
        (summary?.quarterlyTarget ?? 0) > 0;
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa mục tiêu?'),
        content: const Text(
          'Xóa mục tiêu của tháng và quý hiện tại. Doanh số đã ghi nhận vẫn được giữ nguyên.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final provider = context.read<SalesGoalProvider>();
    final ok = await runSalesGoalAction(
      context,
      provider.deleteCurrentTargets,
      errorMessage: 'Không thể xóa mục tiêu. Vui lòng thử lại.',
    );
    if (!mounted) return;
    ok ? context.pop() : setState(() => _saving = false);
  }

  String? _validateAmount(String? value) {
    final amount = parseSalesMoney(value ?? '');
    if (amount == null) return 'Vui lòng nhập số tiền';
    if (amount < 0) return 'Số tiền không được âm';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<SalesGoalProvider>();
    final ok = await runSalesGoalAction(
      context,
      () => provider.saveTargets(
        monthlyTarget: parseSalesMoney(_monthController.text)!,
        quarterlyTarget: parseSalesMoney(_quarterController.text)!,
      ),
    );
    if (!mounted) return;
    ok ? context.pop() : setState(() => _saving = false);
  }
}
