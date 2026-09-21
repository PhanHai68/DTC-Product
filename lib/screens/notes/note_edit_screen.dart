import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../providers/notes_provider.dart';
import '../../repositories/note_repository.dart';
import '../../services/note_notification_service.dart';
import '../../widgets/notes/checklist_editor.dart';
import '../../widgets/notes/note_share_sheet.dart';
import '../../widgets/notes/reminder_section.dart';

class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({super.key, this.noteId});

  /// null = tạo ghi chú mới. Có giá trị = sửa ghi chú đã có (kể cả khi mở
  /// từ notification, lúc đó ghi chú được tải trực tiếp từ database).
  final int? noteId;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  bool get _isEditing => widget.noteId != null;

  Note? _originalNote;
  bool _isLoadingNote = false;
  bool _isSubmitting = false;
  bool _hasChanges = false;
  String? _loadError;

  bool _isPinned = false;
  bool _reminderEnabled = false;
  DateTime? _reminderDateTime;
  ReminderLeadTime _leadTime = ReminderLeadTime.onTime;
  List<ChecklistItem> _checklistItems = const [];

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_markChanged);
    _contentController.addListener(_markChanged);
    if (_isEditing) {
      _loadNote();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges && mounted) setState(() => _hasChanges = true);
  }

  Future<void> _loadNote() async {
    setState(() => _isLoadingNote = true);
    Note? note;
    final provider = context.read<NotesProvider>();
    try {
      note = provider.notes.firstWhere((n) => n.id == widget.noteId);
    } catch (_) {
      note = null;
    }
    // Chưa có trong bộ nhớ (ví dụ mở từ notification khi app mới khởi
    // động) — đọc thẳng từ database.
    note ??= await NoteRepository().getNoteById(widget.noteId!);

    if (!mounted) return;
    if (note == null) {
      setState(() {
        _isLoadingNote = false;
        _loadError = 'Ghi chú không tồn tại hoặc đã bị xóa.';
      });
      return;
    }

    _originalNote = note;
    _titleController.text = note.title;
    _contentController.text = note.content;
    setState(() {
      _isPinned = note!.isPinned;
      _reminderEnabled = note.reminderEnabled;
      _reminderDateTime = note.reminderDateTime;
      _leadTime = note.reminderLeadTime;
      _checklistItems = List.of(note.checklistItems);
      _isLoadingNote = false;
      _hasChanges = false;
    });
  }

  Note _buildNoteFromForm() {
    final now = DateTime.now();
    return Note(
      id: _originalNote?.id,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      createdAt: _originalNote?.createdAt ?? now,
      updatedAt: now,
      isPinned: _isPinned,
      reminderEnabled: _reminderEnabled,
      reminderDateTime: _reminderEnabled ? _reminderDateTime : null,
      reminderBeforeMinutes: _leadTime.minutes,
      notificationId: _originalNote?.notificationId,
      checklistItems: _checklistItems,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề hoặc nội dung.')),
      );
      return;
    }

    if (_reminderEnabled) {
      final effectiveDate = _reminderDateTime ?? DateTime.now();
      final notifyAt = effectiveDate.subtract(
        Duration(minutes: _leadTime.minutes),
      );
      if (notifyAt.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Thời điểm nhắc đã ở quá khứ. Vui lòng chọn ngày giờ khác.',
            ),
          ),
        );
        return;
      }
      final granted = await NoteNotificationService.requestPermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa cấp quyền thông báo nên nhắc hẹn có thể không hiển thị.',
            ),
          ),
        );
      }
    }

    setState(() => _isSubmitting = true);
    final note = _buildNoteFromForm();
    final provider = context.read<NotesProvider>();
    try {
      if (note.id == null) {
        await provider.addNote(note);
      } else {
        await provider.updateNote(note);
      }
      if (mounted) {
        _hasChanges = false;
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu ghi chú. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete() async {
    final id = _originalNote?.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bạn có chắc muốn xóa ghi chú này không?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await context.read<NotesProvider>().deleteNote(id);
      if (mounted) {
        _hasChanges = false;
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xóa ghi chú. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bỏ thay đổi chưa lưu?'),
        content: const Text('Nội dung bạn vừa nhập sẽ không được lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tiếp tục chỉnh sửa'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingNote) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ghi chú')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ghi chú')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_loadError!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_hasChanges || _isSubmitting,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _hasChanges = false;
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Sửa ghi chú' : 'Ghi chú mới'),
          actions: [
            IconButton(
              tooltip: _isPinned ? 'Bỏ ghim' : 'Ghim ghi chú',
              icon: Icon(
                _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              ),
              onPressed: () {
                setState(() => _isPinned = !_isPinned);
                _markChanged();
              },
            ),
            if (_isEditing) ...[
              IconButton(
                tooltip: 'Chia sẻ / Xuất',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () =>
                    showNoteShareSheet(context, _buildNoteFromForm()),
              ),
              IconButton(
                tooltip: 'Xóa ghi chú',
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _isSubmitting ? null : _delete,
              ),
            ],
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('note_title_field'),
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề',
                    hintText: 'Ví dụ: Gọi lại khách hàng ABC',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 120,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('note_content_field'),
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung',
                    hintText: 'Nhập nội dung ghi chú...',
                    alignLabelWithHint: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 5,
                  maxLines: 12,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.checklist_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Checklist',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ChecklistEditor(
                          items: _checklistItems,
                          onChanged: (items) {
                            setState(() => _checklistItems = items);
                            _markChanged();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ReminderSection(
                      enabled: _reminderEnabled,
                      dateTime: _reminderDateTime,
                      leadTime: _leadTime,
                      onEnabledChanged: (value) {
                        setState(() {
                          _reminderEnabled = value;
                          if (value && _reminderDateTime == null) {
                            final now = DateTime.now();
                            _reminderDateTime = DateTime(
                              now.year,
                              now.month,
                              now.day,
                              now.hour,
                              now.minute,
                            ).add(const Duration(hours: 1));
                          }
                        });
                        _markChanged();
                      },
                      onDateTimeChanged: (value) {
                        setState(() => _reminderDateTime = value);
                        _markChanged();
                      },
                      onLeadTimeChanged: (value) {
                        setState(() => _leadTime = value);
                        _markChanged();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  key: const Key('note_save_button'),
                  onPressed: _isSubmitting ? null : _save,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isSubmitting ? 'Đang lưu...' : 'Lưu'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
