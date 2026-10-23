import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dtc_product/features/technical_dictionary/daily_word/daily_word_controller.dart';
import 'package:dtc_product/features/technical_dictionary/daily_word/daily_word_home_card.dart';
import 'package:dtc_product/features/technical_dictionary/daily_word/daily_word_picker.dart';
import 'package:dtc_product/features/technical_dictionary/data/technical_dictionary_database.dart';
import 'package:dtc_product/features/technical_dictionary/models/technical_term.dart';
import 'package:dtc_product/features/technical_dictionary/repositories/technical_dictionary_repository.dart';
import 'package:dtc_product/providers/settings_provider.dart';
import 'package:dtc_product/screens/home_personalization_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
}

final _data = TechnicalDictionaryData.fromJson(
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

DailyWordOptions _options({
  DailyWordMode mode = DailyWordMode.perDay,
  Set<String> groups = const {},
  bool review = true,
}) => DailyWordOptions(mode: mode, groups: groups, reviewLearned: review);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyWordController.debugResetLaunchWord();
  });

  group('DailyWordPicker', () {
    final rice = [
      for (final t in _data.terms)
        if (t.group == 'Xay xát lúa gạo') t,
    ];

    test('chỉ lấy trong nhóm máy đã chọn', () {
      final random = Random(1);
      for (var i = 0; i < 50; i++) {
        final term = DailyWordPicker.pick(
          terms: _data.terms,
          statusOf: (_) => null,
          groups: {'Máy nén khí', 'Xay xát lúa gạo'},
          reviewLearned: true,
          random: random,
        )!;
        expect(['Máy nén khí', 'Xay xát lúa gạo'], contains(term.group));
      }
    });

    test('tắt ôn tập thì không bao giờ ra từ đã thuộc', () {
      final learned = {for (final t in rice.skip(2)) t.key};
      final random = Random(2);
      for (var i = 0; i < 100; i++) {
        final term = DailyWordPicker.pick(
          terms: rice,
          statusOf: (t) => learned.contains(t.key) ? TermStatus.learned : null,
          groups: const {},
          reviewLearned: false,
          random: random,
        )!;
        expect(learned, isNot(contains(term.key)));
      }
    });

    test('ưu tiên từ đang học; từ đã thuộc chỉ thỉnh thoảng để ôn', () {
      final learning = rice.first.key;
      final learned = rice[1].key;
      TermStatus? status(TechnicalTerm t) => t.key == learning
          ? TermStatus.learning
          : t.key == learned
          ? TermStatus.learned
          : null;
      final random = Random(3);
      var learningHits = 0, learnedHits = 0;
      const runs = 1000;
      for (var i = 0; i < runs; i++) {
        final key = DailyWordPicker.pick(
          terms: rice,
          statusOf: status,
          groups: const {},
          reviewLearned: true,
          random: random,
        )!.key;
        if (key == learning) learningHits++;
        if (key == learned) learnedHits++;
      }
      // 1 từ đang học trong 42 từ mà ra khoảng một nửa số lần.
      expect(learningHits / runs, inInclusiveRange(0.35, 0.65));
      expect(learnedHits / runs, inInclusiveRange(0.04, 0.16));
    });

    test('không lặp lại từ vừa gặp và từ đang hiện', () {
      final recent = [for (final t in rice.take(15)) t.key];
      final random = Random(4);
      for (var i = 0; i < 100; i++) {
        final key = DailyWordPicker.pick(
          terms: rice,
          statusOf: (_) => null,
          groups: const {},
          reviewLearned: true,
          random: random,
          recent: recent,
          exclude: rice[20].key,
        )!.key;
        expect(recent, isNot(contains(key)));
        expect(key, isNot(rice[20].key));
      }
    });

    test('nhóm chỉ còn 1 từ chưa gặp vẫn chọn được, không trả null', () {
      final two = rice.take(2).toList();
      final term = DailyWordPicker.pick(
        terms: two,
        statusOf: (_) => TermStatus.learned,
        groups: const {},
        reviewLearned: false,
        random: Random(5),
        recent: [two[0].key, two[1].key],
        exclude: two[0].key,
      );
      expect(term?.key, two[1].key);
    });
  });

  group('DailyWordController', () {
    test('mỗi ngày một từ: cả ngày giữ nguyên, sang ngày mới thì đổi', () async {
      final (repository, db) = await _openRepository();
      addTearDown(db.close);
      var now = DateTime(2026, 10, 23, 8);
      DailyWordController create() => DailyWordController(
        repository: repository,
        now: () => now,
        random: Random(6),
      );

      final morning = create();
      await morning.apply(_options());
      final word = morning.current!;

      // Mở lại app buổi chiều cùng ngày.
      DailyWordController.debugResetLaunchWord();
      now = DateTime(2026, 10, 23, 17);
      final afternoon = create();
      await afternoon.apply(_options());
      expect(afternoon.current!.key, word.key);

      DailyWordController.debugResetLaunchWord();
      now = DateTime(2026, 10, 24, 8);
      final tomorrow = create();
      await tomorrow.apply(_options());
      expect(tomorrow.current!.key, isNot(word.key));
    });

    test('mỗi lần mở app: quay lại Home giữ từ, mở lại app thì đổi', () async {
      final (repository, db) = await _openRepository();
      addTearDown(db.close);
      final options = _options(mode: DailyWordMode.perLaunch);

      final first = DailyWordController(repository: repository);
      await first.apply(options);
      final word = first.current!;

      // Đi sang màn khác rồi quay về Home: thẻ dựng lại, cùng lần mở app.
      final back = DailyWordController(repository: repository);
      await back.apply(options);
      expect(back.current!.key, word.key);

      DailyWordController.debugResetLaunchWord();
      final relaunch = DailyWordController(repository: repository);
      await relaunch.apply(options);
      expect(relaunch.current!.key, isNot(word.key));
    });

    test('đổi nhóm ưu tiên thì chọn ngay từ thuộc nhóm mới', () async {
      final (repository, db) = await _openRepository();
      addTearDown(db.close);
      final controller = DailyWordController(repository: repository);
      await controller.apply(_options(groups: {'Máy tách màu'}));
      expect(controller.current!.group, 'Máy tách màu');

      await controller.apply(_options(groups: {'Máy nén khí'}));
      expect(controller.current!.group, 'Máy nén khí');
    });

    test('"Từ khác" đổi từ; "Đã thuộc" lưu trạng thái rồi đổi từ', () async {
      final (repository, db) = await _openRepository();
      addTearDown(db.close);
      final controller = DailyWordController(repository: repository);
      await controller.apply(_options());
      final first = controller.current!;

      await controller.next();
      final second = controller.current!;
      expect(second.key, isNot(first.key));

      await controller.markLearned();
      expect(controller.current!.key, isNot(second.key));
      final progress = await repository.loadProgress();
      expect(progress[second.key]?.status, TermStatus.learned);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(DailyWordController.historyKey),
        containsAllInOrder([first.key, second.key]),
      );
    });
  });

  group('cài đặt', () {
    test('mặc định: bật, mỗi ngày một từ, mọi nhóm, có ôn từ đã thuộc', () async {
      final settings = SettingsProvider(await SharedPreferences.getInstance());
      expect(settings.homeDailyWordEnabled, isTrue);
      expect(settings.homeDailyWordMode, DailyWordMode.perDay);
      expect(settings.homeDailyWordGroups, isEmpty);
      expect(settings.homeDailyWordReviewLearned, isTrue);
    });

    test('lưu, đọc lại và khôi phục mặc định', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);
      await settings.saveHomePersonalization(
        enabled: false,
        displayName: '',
        shortText: '',
        nameFontSize: SettingsProvider.defaultHomeNameFontSize,
        nameColor: null,
        nameItalic: false,
        shortTextFontSize: SettingsProvider.defaultHomeShortTextFontSize,
        shortTextColor: null,
        shortTextItalic: false,
        dailyWordEnabled: false,
        dailyWordMode: DailyWordMode.perLaunch,
        dailyWordGroups: ['Máy nén khí'],
        dailyWordReviewLearned: false,
      );
      final reloaded = SettingsProvider(prefs);
      expect(reloaded.homeDailyWordEnabled, isFalse);
      expect(reloaded.homeDailyWordMode, DailyWordMode.perLaunch);
      expect(reloaded.homeDailyWordGroups, ['Máy nén khí']);
      expect(reloaded.homeDailyWordReviewLearned, isFalse);

      await reloaded.resetHomePersonalization();
      final reset = SettingsProvider(prefs);
      expect(reset.homeDailyWordEnabled, isTrue);
      expect(reset.homeDailyWordMode, DailyWordMode.perDay);
      expect(reset.homeDailyWordGroups, isEmpty);
      expect(reset.homeDailyWordReviewLearned, isTrue);
    });
  });

  group('thẻ trên Home', () {
    Future<(SettingsProvider, GoRouter, Database)> pumpCard(
      WidgetTester tester,
    ) async {
      final (repository, db) =
          await tester.runAsync(_openRepository) ??
          (throw StateError('Không mở được database test'));
      addTearDown(db.close);
      final settings = SettingsProvider(await SharedPreferences.getInstance());
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: DailyWordHomeCard(
                createController: () =>
                    DailyWordController(repository: repository),
              ),
            ),
          ),
          GoRoute(
            path: '/technical-dictionary/term/:id',
            builder: (_, state) =>
                Text('chi tiết ${state.pathParameters['id']}'),
          ),
          GoRoute(
            path: '/settings/home_personalization',
            builder: (_, _) => const Text('cá nhân hóa'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return (settings, router, db);
    }

    String shownTerm(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('daily_word_term'))).data!;

    testWidgets('hiện từ sau khi nạp, "Từ khác" đổi từ, bấm thẻ mở chi tiết', (
      tester,
    ) async {
      await pumpCard(tester);
      expect(find.byKey(const Key('daily_word_home_card')), findsOneWidget);
      final first = shownTerm(tester);

      await tester.tap(find.byKey(const Key('daily_word_next')));
      await tester.pumpAndSettle();
      expect(shownTerm(tester), isNot(first));

      final term = _data.terms.firstWhere((t) => t.term == shownTerm(tester));
      await tester.tap(find.byKey(const Key('daily_word_term')));
      await tester.pumpAndSettle();
      expect(find.text('chi tiết ${term.id}'), findsOneWidget);
    });

    testWidgets('"Ẩn thẻ" tắt trong cài đặt, "Hoàn tác" bật lại', (
      tester,
    ) async {
      final (settings, _, _) = await pumpCard(tester);

      await tester.tap(find.byKey(const Key('daily_word_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ẩn thẻ'));
      await tester.pumpAndSettle();
      expect(settings.homeDailyWordEnabled, isFalse);
      expect(find.byKey(const Key('daily_word_home_card')), findsNothing);

      await tester.tap(find.text('Hoàn tác'));
      await tester.pumpAndSettle();
      expect(settings.homeDailyWordEnabled, isTrue);
      expect(find.byKey(const Key('daily_word_home_card')), findsOneWidget);
    });
  });

  testWidgets('màn Cá nhân hóa: chọn nhóm máy, chế độ đổi từ rồi lưu', (
    tester,
  ) async {
    TechnicalDictionaryRepository.debugSetSharedDictionary(_data);
    addTearDown(() => TechnicalDictionaryRepository.debugSetSharedDictionary(null));
    final settings = SettingsProvider(await SharedPreferences.getInstance());
    await tester.binding.setSurfaceSize(const Size(390, 3400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const MaterialApp(home: HomePersonalizationScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('daily_word_group_Máy nén khí')));
    await tester.tap(find.text(DailyWordMode.perLaunch.label));
    await tester.tap(find.byKey(const Key('daily_word_review_switch')));
    await tester.pumpAndSettle();
    expect(find.text('Chỉ lấy từ trong 1 nhóm đã chọn.'), findsOneWidget);
    // Chưa bấm Lưu thì chưa đổi.
    expect(settings.homeDailyWordGroups, isEmpty);

    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(settings.homeDailyWordGroups, ['Máy nén khí']);
    expect(settings.homeDailyWordMode, DailyWordMode.perLaunch);
    expect(settings.homeDailyWordReviewLearned, isFalse);
  });
}
