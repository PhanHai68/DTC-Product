import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/daily_goal.dart';
import '../../providers/daily_goals_provider.dart';

/// Thêm mới hoặc sửa 1 mục tiêu — truyền [goal] để vào chế độ sửa.
class DailyGoalFormScreen extends StatefulWidget {
  const DailyGoalFormScreen({super.key, this.goal});

  final DailyGoal? goal;

  @override
  State<DailyGoalFormScreen> createState() => _DailyGoalFormScreenState();
}

class _DailyGoalFormScreenState extends State<DailyGoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late GoalPriority _priority;
  late DateTime _goalDate;
  bool _saving = false;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _descriptionController = TextEditingController(
      text: goal?.description ?? '',
    );
    _priority = goal?.priority ?? GoalPriority.medium;
    _goalDate = DailyGoal.normalizeDate(goal?.goalDate ?? DateTime.now());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _goalDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày thực hiện',
    );
    if (value == null || !mounted) return;
    setState(() => _goalDate = DailyGoal.normalizeDate(value));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final provider = context.read<DailyGoalsProvider>();
    try {
      if (_isEditing) {
        await provider.editGoal(
          widget.goal!.copyWith(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            priority: _priority,
            goalDate: _goalDate,
          ),
        );
      } else {
        await provider.addGoal(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _priority,
          goalDate: _goalDate,
        );
      }
      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa mục tiêu?'),
        content: const Text('Mục tiêu này sẽ bị xóa khỏi lịch sử.'),
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
    await context.read<DailyGoalsProvider>().deleteGoal(widget.goal!.id!);
    if (!mounted) return;
    context.pop();
  }

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa mục tiêu' : 'Thêm mục tiêu'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Xóa mục tiêu',
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextFormField(
              key: const Key('daily_goal_title_field'),
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tên mục tiêu',
                hintText: 'VD: Gửi báo giá cho khách hàng',
              ),
              maxLength: 120,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Vui lòng nhập tên mục tiêu'
                  : null,
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (không bắt buộc)',
              ),
              maxLines: 3,
              maxLength: 300,
            ),
            const SizedBox(height: 8),
            Text(
              'Mức độ ưu tiên',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<GoalPriority>(
              segments: GoalPriority.values
                  .map(
                    (priority) => ButtonSegment(
                      value: priority,
                      label: Text(priority.label),
                    ),
                  )
                  .toList(),
              selected: {_priority},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _priority = selection.first),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Ngày thực hiện'),
              subtitle: Text(_formatDate(_goalDate)),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Đổi ngày'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isEditing ? 'Lưu thay đổi' : 'Thêm mục tiêu'),
            ),
          ],
        ),
      ),
    );
  }
}
