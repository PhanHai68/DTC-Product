import 'package:flutter/material.dart';

import '../../models/note.dart';

/// Widget chỉnh sửa checklist bên trong 1 ghi chú: thêm mục mới, đánh dấu
/// hoàn thành/bỏ đánh dấu, xoá mục. Không phải module quản lý công việc
/// riêng — chỉ là một phần nội dung của ghi chú.
class ChecklistEditor extends StatefulWidget {
  const ChecklistEditor({
    super.key,
    required this.items,
    required this.onChanged,
  });

  final List<ChecklistItem> items;
  final ValueChanged<List<ChecklistItem>> onChanged;

  @override
  State<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<ChecklistEditor> {
  final _newItemController = TextEditingController();

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  void _addItem() {
    final text = _newItemController.text.trim();
    if (text.isEmpty) return;
    final next = List<ChecklistItem>.from(widget.items)
      ..add(ChecklistItem(text: text, sortOrder: widget.items.length));
    widget.onChanged(next);
    _newItemController.clear();
  }

  void _toggleItem(int index) {
    final next = List<ChecklistItem>.from(widget.items);
    next[index] = next[index].copyWith(isCompleted: !next[index].isCompleted);
    widget.onChanged(next);
  }

  void _removeItem(int index) {
    final next = List<ChecklistItem>.from(widget.items)..removeAt(index);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Checkbox(
                  value: widget.items[i].isCompleted,
                  onChanged: (_) => _toggleItem(i),
                ),
                Expanded(
                  child: Text(
                    widget.items[i].text,
                    style: TextStyle(
                      decoration: widget.items[i].isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: widget.items[i].isCompleted
                          ? colorScheme.onSurfaceVariant
                          : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Xóa mục',
                  onPressed: () => _removeItem(i),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('checklist_new_item_field'),
                controller: _newItemController,
                decoration: const InputDecoration(
                  hintText: 'Thêm mục checklist...',
                  isDense: true,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addItem(),
              ),
            ),
            IconButton(
              key: const Key('checklist_add_button'),
              icon: const Icon(Icons.add_circle_rounded),
              tooltip: 'Thêm mục',
              color: colorScheme.primary,
              onPressed: _addItem,
            ),
          ],
        ),
      ],
    );
  }
}
