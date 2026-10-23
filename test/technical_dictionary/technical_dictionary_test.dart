import 'dart:convert';
import 'dart:io';

import 'package:dtc_product/features/technical_dictionary/data/technical_dictionary_database.dart';
import 'package:dtc_product/features/technical_dictionary/models/technical_term.dart';
import 'package:dtc_product/features/technical_dictionary/providers/technical_dictionary_provider.dart';
import 'package:dtc_product/features/technical_dictionary/repositories/technical_dictionary_repository.dart';
import 'package:dtc_product/features/technical_dictionary/technical_dictionary_routes.dart';
import 'package:dtc_product/features/technical_dictionary/utils/term_index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Đọc asset thẳng từ ổ đĩa: tránh `compute` của rootBundle với file lớn
/// (không chạy xong trong fake async của testWidgets).
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
}

TechnicalDictionaryData _loadData() => TechnicalDictionaryData.fromJson(
  jsonDecode(File(TechnicalDictionaryRepository.assetPath).readAsStringSync())
      as Map<String, dynamic>,
);

Future<(TechnicalDictionaryRepository, Database)> _openRepository() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  final database = TechnicalDictionaryDatabase.forTesting(db);
  await database.createSchemaForTesting(db);
  return (
    TechnicalDictionaryRepository(database: database, bundle: _FileBundle()),
    db,
  );
}

void main() {
  final data = _loadData();
  final index = TermIndex(data.terms);
  TechnicalTerm byTerm(String term) =>
      data.terms.firstWhere((t) => t.term == term);

  group('dữ liệu technical_terms.json', () {
    test('đủ thuật ngữ, STT không trùng, trường bắt buộc có dữ liệu', () {
      expect(data.terms.length, greaterThanOrEqualTo(1045));
      expect(data.terms.map((t) => t.id).toSet().length, data.terms.length);
      expect(data.groups, hasLength(7));
      expect(data.types, hasLength(10));
      for (final t in data.terms) {
        expect(t.term.trim(), isNotEmpty, reason: 'STT ${t.id}');
        expect(t.meaning.trim(), isNotEmpty, reason: 'STT ${t.id}');
        expect(data.groups, contains(t.group), reason: 'STT ${t.id}');
        expect(data.types, contains(t.type), reason: 'STT ${t.id}');
      }
    });

    test('không có hai thuật ngữ trùng tên', () {
      final names = data.terms.map((t) => t.term.toLowerCase()).toList();
      expect(names.toSet().length, names.length);
    });

    test('hầu hết "Từ liên quan" mở được thuật ngữ khác', () {
      var total = 0, resolved = 0;
      for (final t in data.terms) {
        for (final name in t.related) {
          total++;
          if (index.lookup(name) != null) resolved++;
        }
      }
      // 23/10/2026: 1.851 tham chiếu, chỉ còn ~18 từ chung chung chưa có.
      expect(resolved / total, greaterThan(0.98));
    });

    test('tên có dấu phẩy không bị tách khi đọc cột Từ liên quan', () {
      final related = data.terms.expand((t) => t.related).toSet();
      expect(related, contains('no bag, no fill'));
      expect(related, isNot(contains('no fill')));
    });
  });

  group('TermIndex.lookup', () {
    test('khớp thuật ngữ, viết tắt, tên gọi khác, bỏ ghi chú trong ngoặc', () {
      expect(index.lookup('ejector valve')?.term, 'ejector valve');
      expect(index.lookup('FAD')?.term, 'free air delivery');
      expect(index.lookup('frequency converter')?.term, 'inverter');
      expect(
        index.lookup('cold dryer (cách gọi TQ)')?.term,
        'refrigerated air dryer',
      );
      expect(index.lookup('Raymond mill')?.term, 'roller mill');
    });

    test('ô gộp "a / b" khớp cả cụm lẫn từng phần', () {
      expect(index.lookup('load/unload')?.term, 'load / unload');
      expect(index.lookup('gross weigher')?.term, 'net weigher / gross weigher');
      expect(
        index.lookup('oil and gas barrel / cylinder')?.term,
        'oil-gas separator tank',
      );
    });

    test('viết tắt liền có dấu "/" không bị tách', () {
      expect(index.lookup('L/C')?.term, 'letter of credit');
      expect(index.lookup('C')?.term, isNot('letter of credit'));
    });

    test('ưu tiên đúng chữ hoa/thường: PSI là kiểm hàng, psi là đơn vị', () {
      expect(index.lookup('PSI')?.term, 'pre-shipment inspection');
      expect(index.lookup('psi')?.term, 'pounds per square inch');
    });

    test('tên chưa có trong từ điển trả về null', () {
      expect(index.lookup('dust'), isNull);
      expect(index.lookup(''), isNull);
    });
  });

  group('TermIndex.search', () {
    test('gõ không dấu tìm được theo nghĩa tiếng Việt', () {
      final results = index.search('van sung', data.terms);
      expect(results.first.term, 'ejector valve');
    });

    test('viết tắt và tên gọi khác đứng đầu kết quả', () {
      expect(index.search('FAD', data.terms).first.term, 'free air delivery');
      expect(index.search('air end', data.terms).first.term, 'airend');
    });

    test('nhiều từ khóa: gõ có dấu thì khớp đúng dấu', () {
      // Không dấu: "tam" ra cả "tấm" lẫn "tâm" (ly tâm).
      expect(
        index.search('tach tam', data.terms).map((t) => t.term),
        containsAll(['length grader', 'dewatering machine']),
      );
      final accented = index.search('tách tấm', data.terms);
      expect(accented.map((t) => t.term), contains('length grader'));
      expect(accented.map((t) => t.term), isNot(contains('dewatering machine')));
    });

    test('từ khóa phải là đầu từ, không khớp giữa chữ', () {
      // Khớp đúng tên đứng trước khớp đầu từ (barite, barrier film...).
      final results = index.search('bar', data.terms);
      expect(results.first.term, 'bar');
      expect(index.search('ejector boa', data.terms).first.term, 'ejector board');
    });

    test('không có từ khóa thì xếp theo chữ cái', () {
      final pool = [byTerm('rotor'), byTerm('airend'), byTerm('bar')];
      expect(index.search('', pool).map((t) => t.term), [
        'airend',
        'bar',
        'rotor',
      ]);
    });
  });

  group('tiến độ học', () {
    test('lưu trạng thái, ghi chú; bỏ hết thì xóa dòng', () async {
      final (repository, db) = await _openRepository();
      addTearDown(db.close);
      final provider = TechnicalDictionaryProvider(repository: repository);
      await provider.init();
      final term = provider.termById(9)!;

      await provider.setStatus(term, TermStatus.learning);
      await provider.setNote(term, '  Hãng X gọi là "gun"  ');
      expect(provider.progressOf(term).status, TermStatus.learning);
      expect(provider.progressOf(term).note, 'Hãng X gọi là "gun"');

      final reloaded = TechnicalDictionaryProvider(repository: repository);
      await reloaded.init();
      expect(reloaded.progressOf(term).status, TermStatus.learning);
      expect(reloaded.progressOf(term).note, 'Hãng X gọi là "gun"');

      await provider.setStatus(term, null);
      await provider.setNote(term, '');
      expect(await db.query(TechnicalDictionaryDatabase.progressTable), isEmpty);
    });

    test('lọc theo nhóm, loại, tiến độ và thống kê theo nhóm', () async {
      final (repository, db) = await _openRepository();
      addTearDown(db.close);
      final provider = TechnicalDictionaryProvider(repository: repository);
      await provider.init();
      final all = provider.results.length;

      provider.setGroup('Xay xát lúa gạo');
      expect(provider.results, isNotEmpty);
      expect(provider.results.every((t) => t.group == 'Xay xát lúa gạo'), isTrue);

      final first = provider.results.first;
      await provider.setStatus(first, TermStatus.learned);
      provider.setProgressFilter(ProgressFilter.learned);
      expect(provider.results, [first]);

      final summary = provider.progressSummary();
      expect(summary.first.total, all);
      expect(summary.first.learned, 1);
      final rice = summary.firstWhere((s) => s.group == 'Xay xát lúa gạo');
      expect(rice.learned, 1);

      provider.clearFilters();
      expect(provider.results.length, all);
    });
  });

  testWidgets('tra cứu, mở chi tiết, bấm từ liên quan, đánh dấu đã thuộc', (
    tester,
  ) async {
    final (repository, db) = await tester.runAsync(_openRepository) ??
        (throw StateError('Không mở được database test'));
    addTearDown(db.close);
    final router = GoRouter(
      initialLocation: '/technical-dictionary',
      routes: [
        buildTechnicalDictionaryRoutes(
          createProvider: () =>
              TechnicalDictionaryProvider(repository: repository),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('dictionary_result_count'))).data,
      endsWith('thuật ngữ'),
    );

    await tester.enterText(find.byKey(const Key('dictionary_search')), 'van sung');
    await tester.pumpAndSettle();
    final ejectorValve = data.terms.firstWhere((t) => t.term == 'ejector valve');
    await tester.tap(find.byKey(Key('dictionary_term_${ejectorValve.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Giải thích'), findsOneWidget);
    expect(find.text('van súng (van phun tốc độ cao)'), findsOneWidget);

    // "solenoid valve" là từ liên quan có trong từ điển.
    final solenoid = data.terms.firstWhere((t) => t.term == 'solenoid valve');
    final chip = find.byKey(Key('dictionary_related_${solenoid.id}'));
    await tester.scrollUntilVisible(
      chip,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('van điện từ'), findsOneWidget);

    final learned = find.text('Đã thuộc');
    await tester.scrollUntilVisible(
      learned,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(learned);
    await tester.pumpAndSettle();
    final rows = await tester.runAsync(
      () => db.query(TechnicalDictionaryDatabase.progressTable),
    );
    expect(rows, [
      containsPair('term_key', 'solenoid valve'),
    ]);
    expect(rows!.single['status'], 'learned');
  });
}
