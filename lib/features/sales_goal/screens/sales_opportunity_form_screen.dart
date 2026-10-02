import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/sales_opportunity.dart';
import '../providers/sales_goal_provider.dart';
import '../utils/sales_goal_action.dart';
import '../utils/sales_goal_format.dart';

class SalesOpportunityFormScreen extends StatefulWidget {
  const SalesOpportunityFormScreen({super.key, this.opportunity});
  final SalesOpportunity? opportunity;

  @override
  State<SalesOpportunityFormScreen> createState() =>
      _SalesOpportunityFormScreenState();
}

class _SalesOpportunityFormScreenState
    extends State<SalesOpportunityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _customer;
  late final TextEditingController _product;
  late final TextEditingController _value;
  late final TextEditingController _probability;
  late final TextEditingController _notes;
  late DateTime _closeDate;
  late SalesOpportunityStatus _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.opportunity;
    _customer = TextEditingController(text: item?.customerOrProject ?? '');
    _product = TextEditingController(text: item?.productOrMachine ?? '');
    _value = TextEditingController(
      text: item == null ? '' : '${item.estimatedValue}',
    );
    _probability = TextEditingController(
      text: item == null ? '50' : '${item.probability}',
    );
    _notes = TextEditingController(text: item?.notes ?? '');
    _closeDate = item?.expectedCloseDate ?? DateTime.now();
    _status = item?.status ?? SalesOpportunityStatus.tracking;
  }

  @override
  void dispose() {
    _customer.dispose();
    _product.dispose();
    _value.dispose();
    _probability.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.opportunity == null ? 'Thêm cơ hội' : 'Sửa cơ hội'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            key: const Key('sales_opportunity_customer'),
            controller: _customer,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Khách hàng / dự án *',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập khách hàng hoặc dự án'
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _product,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Sản phẩm / máy'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _value,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Giá trị dự kiến *',
              suffixText: 'VND',
            ),
            validator: (value) {
              final amount = parseSalesMoney(value ?? '');
              return amount == null || amount <= 0
                  ? 'Giá trị phải lớn hơn 0'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _probability,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Xác suất thành công *',
              suffixText: '%',
            ),
            validator: (value) {
              final probability = int.tryParse(value ?? '');
              return probability == null || probability < 0 || probability > 100
                  ? 'Nhập xác suất từ 0 đến 100'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SalesOpportunityStatus>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Trạng thái'),
            items: SalesOpportunityStatus.values
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _status = value!),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Ngày dự kiến chốt'),
            subtitle: Text(formatSalesDate(_closeDate)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
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
            label: const Text('Lưu cơ hội'),
          ),
        ],
      ),
    ),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _closeDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _closeDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final old = widget.opportunity;
    final provider = context.read<SalesGoalProvider>();
    final ok = await runSalesGoalAction(
      context,
      () => provider.saveOpportunity(
        SalesOpportunity(
          id: old?.id,
          customerOrProject: _customer.text.trim(),
          productOrMachine: _product.text.trim(),
          estimatedValue: parseSalesMoney(_value.text)!,
          probability: int.parse(_probability.text),
          expectedCloseDate: _closeDate,
          notes: _notes.text.trim(),
          status: _status,
          createdAt: old?.createdAt ?? now,
          updatedAt: now,
        ),
      ),
    );
    if (!mounted) return;
    ok ? context.pop() : setState(() => _saving = false);
  }
}
