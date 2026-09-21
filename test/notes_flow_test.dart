import 'package:dtc_product/models/note.dart';
import 'package:dtc_product/providers/notes_provider.dart';
import 'package:dtc_product/repositories/note_repository.dart';
import 'package:dtc_product/screens/notes/note_edit_screen.dart';
import 'package:dtc_product/screens/notes/notes_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Repository giả lưu trong bộ nhớ, tránh phụ thuộc SQLite thật khi test —
/// NotesProvider chỉ thao tác qua NoteRepository nên có thể thay thế an toàn.
class _FakeNoteRepository extends NoteRepository {
  final List<Note> _store = [];
  int _nextId = 1;

  @override
  Future<List<Note>> getAllNotes() async {
    final list = List<Note>.from(_store);
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  @override
  Future<Note?> getNoteById(int id) async {
    try {
      return _store.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Note> insertNote(Note note) async {
    final saved = note.copyWith(id: _nextId++);
    _store.add(saved);
    return saved;
  }

  @override
  Future<Note> updateNote(Note note) async {
    final index = _store.indexWhere((n) => n.id == note.id);
    if (index == -1) throw StateError('Không tìm thấy ghi chú.');
    _store[index] = note;
    return note;
  }

  @override
  Future<void> deleteNote(int id) async {
    _store.removeWhere((n) => n.id == id);
  }

  @override
  Future<void> setPinned(int id, bool isPinned) async {
    final index = _store.indexWhere((n) => n.id == id);
    if (index == -1) return;
    _store[index] = _store[index].copyWith(isPinned: isPinned);
  }
}

Widget _buildApp(NotesProvider provider) {
  final router = GoRouter(
    initialLocation: '/notes',
    routes: [
      GoRoute(
        path: '/notes',
        builder: (context, state) => const NotesListScreen(),
      ),
      GoRoute(
        path: '/notes/edit',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return NoteEditScreen(noteId: extra?['noteId'] as int?);
        },
      ),
    ],
  );

  return ChangeNotifierProvider<NotesProvider>.value(
    value: provider,
    child: MaterialApp.router(
      theme: ThemeData(useMaterial3: true),
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('Tạo ghi chú nhanh không cần nhắc hẹn (Luồng 1)', (
    tester,
  ) async {
    final provider = NotesProvider(repository: _FakeNoteRepository());
    await provider.loadNotes();

    await tester.pumpWidget(_buildApp(provider));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có ghi chú nào.\nBấm nút + để tạo ghi chú đầu tiên.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notes_add_button')));
    await tester.pumpAndSettle();

    expect(find.text('Ghi chú mới'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('note_title_field')),
      'Gọi lại khách hàng ABC',
    );
    await tester.enterText(
      find.byKey(const Key('note_content_field')),
      'Hỏi phản hồi về báo giá máy nén khí 100 HP.',
    );

    // Mặc định "Nhắc tôi" phải là OFF.
    final reminderSwitchFinder = find.byKey(const Key('reminder_switch'));
    final reminderSwitch = tester.widget<SwitchListTile>(reminderSwitchFinder);
    expect(reminderSwitch.value, isFalse);
    expect(find.byKey(const Key('reminder_date_field')), findsNothing);

    await tester.tap(find.byKey(const Key('note_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Ghi chú & Nhắc hẹn'), findsOneWidget);
    expect(find.text('Gọi lại khách hàng ABC'), findsOneWidget);
    expect(
      find.text('Hỏi phản hồi về báo giá máy nén khí 100 HP.'),
      findsOneWidget,
    );
    expect(find.textContaining('Không có nhắc hẹn'), findsWidgets);
    expect(provider.notes, hasLength(1));
    expect(provider.notes.single.reminderEnabled, isFalse);
  });

  testWidgets('Bật "Nhắc tôi" hiện thêm ngày/giờ/nhắc trước (Luồng 2)', (
    tester,
  ) async {
    final provider = NotesProvider(repository: _FakeNoteRepository());
    await provider.loadNotes();
    await tester.pumpWidget(_buildApp(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('notes_add_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('note_title_field')),
      'Nhắc khảo sát công trình',
    );

    await tester.tap(find.byKey(const Key('reminder_switch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reminder_date_field')), findsOneWidget);
    expect(find.byKey(const Key('reminder_time_field')), findsOneWidget);
    expect(find.byKey(const Key('reminder_lead_time_field')), findsOneWidget);
    expect(find.text('Đúng giờ'), findsOneWidget);
  });

  testWidgets('Tìm kiếm lọc ngay theo tiêu đề/nội dung', (tester) async {
    final repository = _FakeNoteRepository();
    final now = DateTime.now();
    await repository.insertNote(
      Note(
        title: 'Gọi lại khách hàng ABC',
        content: 'Máy nén khí 100 HP',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.insertNote(
      Note(
        title: 'Thông số máy DF53S',
        content: 'Lưu thông số máy để tra cứu.',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final provider = NotesProvider(repository: repository);
    await provider.loadNotes();

    await tester.pumpWidget(_buildApp(provider));
    await tester.pumpAndSettle();

    expect(find.text('Gọi lại khách hàng ABC'), findsOneWidget);
    expect(find.text('Thông số máy DF53S'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('notes_search_field')),
      'DF53S',
    );
    await tester.pumpAndSettle();

    expect(find.text('Gọi lại khách hàng ABC'), findsNothing);
    expect(find.text('Thông số máy DF53S'), findsOneWidget);
  });

  testWidgets('Ghim ghi chú đưa lên đầu danh sách khi lọc "Đã ghim"', (
    tester,
  ) async {
    final repository = _FakeNoteRepository();
    final now = DateTime.now();
    final note = await repository.insertNote(
      Note(
        title: 'Ghi chú cần ghim',
        content: '',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final provider = NotesProvider(repository: repository);
    await provider.loadNotes();
    await tester.pumpWidget(_buildApp(provider));
    await tester.pumpAndSettle();

    await provider.togglePinned(note);
    await tester.pumpAndSettle();

    expect(provider.notes.single.isPinned, isTrue);

    await tester.tap(find.text('Đã ghim'));
    await tester.pumpAndSettle();

    expect(find.text('Ghi chú cần ghim'), findsOneWidget);
  });
}
