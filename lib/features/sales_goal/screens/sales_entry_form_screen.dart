import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/sales_entry.dart';
import '../providers/sales_goal_provider.dart';
import '../utils/sales_goal_action.dart';
import '../utils/sales_goal_format.dart';

class SalesEntryFormScreen extends StatefulWidget {
  const SalesEntryFormScreen({super.key, this.entry});
  final SalesEntry? entry;

  @override
  State<SalesEntryFormScreen> createState() => _SalesEntryFormScreenState();
}

class _SalesEntryFormScreenState extends State<SalesEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  late final TextEditingController _amount;
  late final TextEditingController _customer;
  late final TextEditingController _product;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _date = entry?.saleDate ?? DateTime.now();
    _amount = TextEditingController(
      text: entry == null ? '' : '${entry.amount}',
    );
    _customer = TextEditingController(text: entry?.customerOrProject ?? '');
    _product = TextEditingController(text: entry?.productOrMachine ?? '');
    _notes = TextEditingController(text: entry?.notes ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _customer.dispose();
    _product.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.entry == null ? 'Ghi doanh số' : 'Sửa doanh số'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Ngày ghi nhận'),
            subtitle: Text(formatSalesDate(_date)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('sales_entry_amount'),
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Doanh số *',
              suffixText: 'VND',
            ),
            validator: (value) {
              final amount = parseSalesMoney(value ?? '');
              return amount == null || amount <= 0
                  ? 'Doanh số phải lớn hơn 0'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customer,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Khách hàng / dự án'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _product,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Sản phẩm / máy'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            maxLength: 500,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu doanh số'),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final old = widget.entry;
    final provider = context.read<SalesGoalProvider>();
    final ok = await runSalesGoalAction(
      context,
      () => provider.saveEntry(
        SalesEntry(
          id: old?.id,
          saleDate: _date,
          amount: parseSalesMoney(_amount.text)!,
          customerOrProject: _customer.text.trim(),
          productOrMachine: _product.text.trim(),
          notes: _notes.text.trim(),
          createdAt: old?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
    if (!mounted) return;
    ok ? context.pop() : setState(() => _saving = false);
  }
}
