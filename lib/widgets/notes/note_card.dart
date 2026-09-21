import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';

enum NoteCardAction { edit, togglePin, share, exportPdf, exportImage, delete }

/// Card hiển thị 1 ghi chú trong danh sách — theo đúng các trường tối thiểu
/// yêu cầu: tiêu đề, trích nội dung, ngày cập nhật, icon chuông/ghim, và
/// ngày giờ nhắc nếu có.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onAction,
  });

  final Note note;
  final VoidCallback onTap;
  final ValueChanged<NoteCardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final reminderFormat = DateFormat('dd/MM/yyyy · HH:mm');
    final hasReminder = note.reminderEnabled && note.reminderDateTime != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('note_card_${note.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.isPinned) ...[
                    Icon(
                      Icons.push_pin_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      note.title.trim().isEmpty
                          ? '(Không có tiêu đề)'
                          : note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (hasReminder) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.notifications_active_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ],
                  PopupMenuButton<NoteCardAction>(
                    tooltip: 'Thao tác',
                    onSelected: onAction,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: NoteCardAction.edit,
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Chỉnh sửa'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: NoteCardAction.togglePin,
                        child: ListTile(
                          leading: Icon(
                            note.isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin_rounded,
                          ),
                          title: Text(note.isPinned ? 'Bỏ ghim' : 'Ghim'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: NoteCardAction.share,
                        child: ListTile(
                          leading: Icon(Icons.share_outlined),
                          title: Text('Chia sẻ'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: NoteCardAction.exportPdf,
                        child: ListTile(
                          leading: Icon(Icons.picture_as_pdf_outlined),
                          title: Text('Xuất PDF'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: NoteCardAction.exportImage,
                        child: ListTile(
                          leading: Icon(Icons.image_outlined),
                          title: Text('Xuất hình ảnh'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: NoteCardAction.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('Xóa', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (note.content.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Text(
                    note.content.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Cập nhật ${dateFormat.format(note.updatedAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (hasReminder) ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.notifications_active_rounded,
                        size: 13,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          reminderFormat.format(note.reminderDateTime!),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          '  ·  Không có nhắc hẹn',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
