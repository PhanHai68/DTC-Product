import 'package:dtc_product/models/note.dart';
import 'package:dtc_product/repositories/note_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late NoteRepository repository;
  final now = DateTime(2026, 10, 9);
  Note note(String title, List<ChecklistItem> items) => Note(
    title: title,
    content: 'Nội dung',
    createdAt: now,
    updatedAt: now,
    checklistItems: items,
  );

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await db.execute('''CREATE TABLE notes(
      id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT,
      createdAt TEXT, updatedAt TEXT, isPinned INTEGER,
      reminderEnabled INTEGER, reminderDateTime TEXT,
      reminderBeforeMinutes INTEGER, notificationId INTEGER)''');
    await db.execute('''CREATE TABLE checklist_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT, noteId INTEGER NOT NULL,
      text TEXT, isCompleted INTEGER, sortOrder INTEGER)''');
    repository = NoteRepository.forTesting(db);
  });
  tearDown(() async => db.close());

  Future<void> rejectChecklist() => db.execute('''CREATE TRIGGER fail_item
    BEFORE INSERT ON checklist_items WHEN NEW.text = 'fail'
    BEGIN SELECT RAISE(ABORT, 'simulated storage failure'); END''');

  test('insert rolls back the header and earlier checklist rows', () async {
    await rejectChecklist();
    await expectLater(
      repository.insertNote(
        note('New', const [
          ChecklistItem(text: 'first'),
          ChecklistItem(text: 'fail'),
        ]),
      ),
      throwsA(isA<DatabaseException>()),
    );
    expect(await repository.getAllNotes(), isEmpty);
    expect(await db.query('checklist_items'), isEmpty);
  });

  test(
    'failed update preserves header and the full previous checklist',
    () async {
      final saved = await repository.insertNote(
        note('Original', const [
          ChecklistItem(text: 'old one'),
          ChecklistItem(text: 'old two', isCompleted: true),
        ]),
      );
      final before = await db.query('checklist_items');
      await rejectChecklist();
      await expectLater(
        repository.updateNote(
          saved.copyWith(
            title: 'Changed',
            checklistItems: const [
              ChecklistItem(text: 'first'),
              ChecklistItem(text: 'fail'),
            ],
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repository.getNoteById(saved.id!))!.title, 'Original');
      expect(await db.query('checklist_items'), before);
    },
  );

  test('failed delete preserves both note and checklist', () async {
    final saved = await repository.insertNote(
      note('Original', const [ChecklistItem(text: 'old')]),
    );
    await db.execute('''CREATE TRIGGER fail_delete BEFORE DELETE ON notes
      BEGIN SELECT RAISE(ABORT, 'simulated delete failure'); END''');
    await expectLater(
      repository.deleteNote(saved.id!),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      (await repository.getNoteById(saved.id!))!.checklistItems.single.text,
      'old',
    );
  });

  test('successful update and delete commit all related rows', () async {
    final saved = await repository.insertNote(
      note('Original', const [ChecklistItem(text: 'old')]),
    );
    final updated = await repository.updateNote(
      saved.copyWith(
        title: 'Changed',
        checklistItems: const [ChecklistItem(text: 'new')],
      ),
    );
    expect(updated.title, 'Changed');
    expect(updated.checklistItems.single.text, 'new');
    await repository.deleteNote(saved.id!);
    expect(await repository.getAllNotes(), isEmpty);
    expect(await db.query('checklist_items'), isEmpty);
  });
}
