import 'dart:async';

import 'package:dtc_product/features/site_layout/data/site_layout_database.dart';
import 'package:dtc_product/features/site_layout/models/site_layout_models.dart';
import 'package:dtc_product/features/site_layout/providers/site_layout_provider.dart';
import 'package:dtc_product/features/site_layout/repositories/site_layout_repository.dart';
import 'package:dtc_product/features/site_layout/screens/site_layout_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _ControlledRepository extends SiteLayoutRepository {
  _ControlledRepository(SiteLayoutDatabase db) : super(database: db);
  bool fail = false;
  Completer<void>? gate;
  int calls = 0;
  @override
  Future<void> saveBundle(SiteLayoutBundle bundle) async {
    calls++;
    final wait = gate;
    gate = null;
    if (wait != null) await wait.future;
    if (fail) throw StateError('simulated storage failure');
    await super.saveBundle(bundle);
  }
}

class _TestProvider extends SiteLayoutProvider {
  _TestProvider(_ControlledRepository repository)
    : super(repository: repository);
  @override
  Future<void> initialize() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late _ControlledRepository repository;
  late _TestProvider provider;
  late SiteLayoutProject project;
  late SiteLayoutVariant second;
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final wrapper = SiteLayoutDatabase.forTesting(db);
    await wrapper.createSchemaForTesting(db);
    await db.execute('PRAGMA foreign_keys = ON');
    repository = _ControlledRepository(wrapper);
    project = await repository.createProject(
      name: 'Test layout',
      customer: '',
      location: '',
      surveyor: '',
      surveyDate: DateTime(2026, 10, 9),
      siteWidthMm: 12000,
      siteLengthMm: 10000,
    );
    second = await repository.createLayout(project.id);
    provider = _TestProvider(repository);
    await provider.loadProject(project.id);
  });
  tearDown(() async {
    provider.dispose();
    await db.close();
  });
  void edit() => provider.addObject(SiteObjectType.wall, 1000, 1000);

  test(
    'failed save blocks switching and retains edits and undo history',
    () async {
      final original = provider.bundle!.layout.id;
      edit();
      repository.fail = true;
      await provider.switchLayout(second.id);
      expect(provider.bundle!.layout.id, original);
      expect(provider.bundle!.objects, hasLength(1));
      expect(provider.canUndo, isTrue);
      expect(provider.isDirty, isTrue);
      expect(provider.error, contains('Không thể tự động lưu'));
      repository.fail = false;
      expect(await provider.saveNow(), isTrue);
      expect(provider.isDirty, isFalse);
      expect(
        (await repository.getBundle(project.id, original))!.objects,
        hasLength(1),
      );
      await provider.switchLayout(second.id);
      expect(provider.bundle!.layout.id, second.id);
    },
  );

  test(
    'failed save blocks new, duplicate and preferred layout actions',
    () async {
      edit();
      repository.fail = true;
      final original = provider.bundle!.layout.id;
      await provider.createLayout();
      await provider.createLayout(duplicateCurrent: true);
      await provider.setPreferredLayout();
      expect(await repository.getLayouts(project.id), hasLength(2));
      expect(provider.bundle!.layout.id, original);
      expect(provider.bundle!.objects, hasLength(1));
      expect(provider.isDirty, isTrue);
    },
  );

  test(
    'all concurrent save callers receive failure without replacing the bundle',
    () async {
      edit();
      repository.fail = true;
      final gate = repository.gate = Completer<void>();
      final first = provider.saveNow();
      final secondSave = provider.saveNow();
      gate.complete();
      expect(await Future.wait([first, secondSave]), [false, false]);
      expect(repository.calls, 1);
      expect(provider.isDirty, isTrue);
      expect(provider.bundle!.objects, hasLength(1));
    },
  );

  test(
    'edits during a slow save are persisted before save completes',
    () async {
      edit();
      final gate = repository.gate = Completer<void>();
      final saving = provider.saveNow();
      provider.addObject(SiteObjectType.column, 3000, 3000);
      gate.complete();
      expect(await saving, isTrue);
      expect(repository.calls, 2);
      expect(provider.isDirty, isFalse);
      expect(
        (await repository.getBundle(
          project.id,
          provider.bundle!.layout.id,
        ))!.objects,
        hasLength(2),
      );
    },
  );

  testWidgets('back stays in editor on failure, then succeeds after retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SiteLayoutProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        SiteLayoutEditorScreen(projectId: project.id),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    edit();
    repository.fail = true;
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SiteLayoutEditorScreen), findsOneWidget);
    expect(provider.isDirty, isTrue);
    repository.fail = false;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SiteLayoutEditorScreen), findsNothing);
    expect(provider.isDirty, isFalse);
    expect(tester.takeException(), isNull);
  });
}
