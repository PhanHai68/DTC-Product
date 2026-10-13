import 'dart:async';

import 'package:dtc_product/models/sample_record.dart';
import 'package:dtc_product/repositories/sample_record_repository.dart';
import 'package:dtc_product/screens/sample_record/sample_record_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository implements SampleRecordRepository {
  final saved = <SampleRecordData>[];
  Completer<void>? gate;
  Completer<SampleRecordData?>? loadGate;
  bool fail = false;
  @override
  Future<SampleRecordData?> loadDraft() async => await loadGate?.future;
  @override
  Future<void> saveDraft(SampleRecordData record) async {
    final wait = gate;
    gate = null;
    if (wait != null) await wait.future;
    if (fail) throw StateError('simulated storage failure');
    saved.add(record);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _openForm(WidgetTester tester, _Repository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SampleRecordScreen(repository: repository),
              ),
            ),
            child: const Text('Open sample'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open sample'));
  await tester.pumpAndSettle();
}

Finder get factoryField => find.byType(TextFormField).first;

void main() {
  testWidgets('leaving before the debounce saves the latest text', (
    tester,
  ) async {
    final repository = _Repository();
    await _openForm(tester, repository);
    await tester.enterText(factoryField, 'Latest factory');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(repository.saved.last.factoryName, 'Latest factory');
    expect(find.byType(SampleRecordScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edits during a slow write are queued and saved afterwards', (
    tester,
  ) async {
    final repository = _Repository();
    await _openForm(tester, repository);
    final gate = repository.gate = Completer<void>();
    await tester.enterText(factoryField, 'First');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.enterText(factoryField, 'Latest');
    await tester.pump(const Duration(milliseconds: 800));
    gate.complete();
    await tester.pumpAndSettle();
    expect(repository.saved.map((record) => record.factoryName), [
      'First',
      'Latest',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save keeps form open and supports retry', (tester) async {
    final repository = _Repository();
    await _openForm(tester, repository);
    repository.fail = true;
    await tester.enterText(factoryField, 'Keep this');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SampleRecordScreen), findsOneWidget);
    expect(repository.saved, isEmpty);
    expect(find.byKey(const Key('sample_record_retry_save')), findsOneWidget);
    expect(tester.takeException(), isNull);
    repository.fail = false;
    await tester.tap(find.byKey(const Key('sample_record_retry_save')));
    await tester.pumpAndSettle();
    expect(repository.saved.last.factoryName, 'Keep this');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SampleRecordScreen), findsNothing);
  });

  testWidgets(
    'forced removal flushes pending snapshot before controllers are disposed',
    (tester) async {
      final repository = _Repository();
      await _openForm(tester, repository);
      await tester.enterText(factoryField, 'Pending');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(repository.saved.last.factoryName, 'Pending');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('finishing draft load after dispose does not touch controllers', (
    tester,
  ) async {
    final repository = _Repository();
    final load = repository.loadGate = Completer<SampleRecordData?>();
    await tester.pumpWidget(
      MaterialApp(home: SampleRecordScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    load.complete(
      SampleRecordData(
        factoryName: 'Old',
        createdAt: DateTime(2026, 10, 9),
        streams: const [],
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
