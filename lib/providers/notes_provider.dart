import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../services/note_notification_service.dart';

enum NoteFilter { all, reminder, pinned }

class NotesProvider extends ChangeNotifier {
  NotesProvider({NoteRepository? repository})
    : _repository = repository ?? NoteRepository();

  final NoteRepository _repository;

  List<Note> _notes = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  NoteFilter _filter = NoteFilter.all;

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  NoteFilter get filter => _filter;

  List<Note> get filteredNotes {
    Iterable<Note> result = _notes;

    switch (_filter) {
      case NoteFilter.reminder:
        result = result.where((n) => n.reminderEnabled);
        break;
      case NoteFilter.pinned:
        result = result.where((n) => n.isPinned);
        break;
      case NoteFilter.all:
        break;
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where(
        (n) =>
            n.title.toLowerCase().contains(query) ||
            n.content.toLowerCase().contains(query),
      );
    }

    final list = result.toList();
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setFilter(NoteFilter value) {
    _filter = value;
    notifyListeners();
  }

  Future<void> loadNotes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _notes = await _repository.getAllNotes();
      await _resyncPendingReminders();
    } catch (e) {
      _errorMessage = 'Không thể đọc dữ liệu ghi chú trên thiết bị.';
      debugPrint('Error loading notes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Đăng ký lại các nhắc hẹn còn hiệu lực mỗi khi app khởi động — đây là lớp
  /// bảo hiểm bổ sung cho việc khôi phục sau khi khởi động lại máy, phòng khi
  /// receiver gốc của hệ điều hành không chạy trên một số dòng máy Android.
  Future<void> _resyncPendingReminders() async {
    for (final note in _notes) {
      final notifyAt = note.notifyAt;
      if (note.id == null || !note.reminderEnabled || notifyAt == null) {
        continue;
      }
      if (notifyAt.isAfter(DateTime.now())) {
        await NoteNotificationService.schedule(
          noteId: note.id!,
          notifyAt: notifyAt,
          title: note.title.isEmpty ? 'Ghi chú không có tiêu đề' : note.title,
          body: note.content,
        );
      }
    }
  }

  Future<Note> addNote(Note note) async {
    final saved = await _repository.insertNote(note);
    await _applyReminderSideEffects(saved);
    await _refresh();
    return saved;
  }

  Future<Note> updateNote(Note note) async {
    final saved = await _repository.updateNote(note);
    await _applyReminderSideEffects(saved);
    await _refresh();
    return saved;
  }

  Future<void> deleteNote(int id) async {
    await NoteNotificationService.cancel(id);
    await _repository.deleteNote(id);
    await _refresh();
  }

  Future<void> togglePinned(Note note) async {
    if (note.id == null) return;
    await _repository.setPinned(note.id!, !note.isPinned);
    await _refresh();
  }

  Future<void> _applyReminderSideEffects(Note note) async {
    if (note.id == null) return;
    final notifyAt = note.notifyAt;
    if (note.reminderEnabled && notifyAt != null) {
      await NoteNotificationService.schedule(
        noteId: note.id!,
        notifyAt: notifyAt,
        title: note.title.isEmpty ? 'Ghi chú không có tiêu đề' : note.title,
        body: note.content,
      );
    } else {
      await NoteNotificationService.cancel(note.id!);
    }
  }

  Future<void> _refresh() async {
    _errorMessage = null;
    _notes = await _repository.getAllNotes();
    notifyListeners();
  }
}
