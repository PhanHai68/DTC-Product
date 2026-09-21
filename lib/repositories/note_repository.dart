// Repository cho chức năng "Ghi chú & Nhắc hẹn".
// Lưu trữ hoàn toàn offline trên SQLite (dùng chung user_data.db với
// module Bảo trì) — không cần tài khoản hay đồng bộ cloud.

import '../core/database/local_database.dart';
import '../models/note.dart';

class NoteRepository {
  NoteRepository({LocalDatabase? database})
    : _db = database ?? LocalDatabase.instance;

  final LocalDatabase _db;

  static const _notesTable = 'notes';
  static const _checklistTable = 'checklist_items';

  Future<List<Note>> getAllNotes() async {
    final db = await _db.database;
    final noteRows = await db.query(
      _notesTable,
      orderBy: 'isPinned DESC, updatedAt DESC',
    );
    if (noteRows.isEmpty) return const [];

    final checklistRows = await db.query(
      _checklistTable,
      orderBy: 'sortOrder ASC, id ASC',
    );
    final checklistByNote = <int, List<ChecklistItem>>{};
    for (final row in checklistRows) {
      final item = ChecklistItem.fromMap(row);
      final noteId = item.noteId;
      if (noteId == null) continue;
      checklistByNote.putIfAbsent(noteId, () => []).add(item);
    }

    return noteRows.map((row) {
      final id = row['id'] as int?;
      return Note.fromMap(row, checklistItems: checklistByNote[id] ?? const []);
    }).toList();
  }

  Future<Note?> getNoteById(int id) async {
    final db = await _db.database;
    final rows = await db.query(_notesTable, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final checklistRows = await db.query(
      _checklistTable,
      where: 'noteId = ?',
      whereArgs: [id],
      orderBy: 'sortOrder ASC, id ASC',
    );
    return Note.fromMap(
      rows.first,
      checklistItems: checklistRows.map(ChecklistItem.fromMap).toList(),
    );
  }

  /// Tạo ghi chú mới, lưu checklist đi kèm nếu có. Trả về ghi chú đã có id.
  Future<Note> insertNote(Note note) async {
    final db = await _db.database;
    final id = await db.insert(_notesTable, note.toMap()..remove('id'));
    for (final item in note.checklistItems) {
      await db.insert(
        _checklistTable,
        item.copyWith(id: null, noteId: id).toMap()..remove('id'),
      );
    }
    return (await getNoteById(id))!;
  }

  /// Cập nhật ghi chú + đồng bộ lại toàn bộ checklist (xoá cũ, ghi lại mới)
  /// vì checklist trong 1 ghi chú thường ít mục, cách này đơn giản và an toàn
  /// hơn so với diff từng dòng.
  Future<Note> updateNote(Note note) async {
    if (note.id == null) {
      throw ArgumentError('Không thể cập nhật ghi chú chưa có id.');
    }
    final db = await _db.database;
    await db.update(
      _notesTable,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    await db.delete(
      _checklistTable,
      where: 'noteId = ?',
      whereArgs: [note.id],
    );
    for (final item in note.checklistItems) {
      await db.insert(
        _checklistTable,
        item.copyWith(id: null, noteId: note.id).toMap()..remove('id'),
      );
    }
    return (await getNoteById(note.id!))!;
  }

  Future<void> deleteNote(int id) async {
    final db = await _db.database;
    await db.delete(_checklistTable, where: 'noteId = ?', whereArgs: [id]);
    await db.delete(_notesTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setPinned(int id, bool isPinned) async {
    final db = await _db.database;
    await db.update(
      _notesTable,
      {'isPinned': isPinned ? 1 : 0, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
