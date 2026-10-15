import 'dart:io';

import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/screens/mineral_color_sorter/mineral_color_sorter_screen.dart';
import 'package:dtc_product/screens/mineral_color_sorter/mineral_sorter_selector_screen.dart';
import 'package:dtc_product/screens/mineral_color_sorter_menu_screen.dart';
import 'package:dtc_product/services/mineral_sorter_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MineralSelectionRequest _req(
  double min,
  double max,
  double tph, {
  StoneCondition condition = StoneCondition.dry,
}) => MineralSelectionRequest(
  minMm: min,
  maxMm: max,
  tonsPerHour: tph,
  condition: condition,
);

List<String> _models(MineralSelectionRequest request) => [
  for (final m in selectMineralSorters(mineralColorSorterSpecs, request))
    m.model,
];

Map<String, String> _spec(String model) =>
    mineralColorSorterSpecs.firstWhere((s) => s['model'] == model);

void main() {
  group('Dữ liệu ASORT trong sx8_mineral.json', () {
    const asort = [
      'SA6-2C',
      'SA6-2SC',
      'SA8-2C',
      'SA8-2SC',
      'SA6-2AL',
      'SA4-1AL',
      'SA4-2AL',
      'SA4-2BL',
      'SA4-1L',
      'SA6-2SL',
      'SA6-1SL',
    ];

    test('đủ 11 model catalog, SX8 giữ nguyên ở đầu danh sách', () {
      final models = [for (final s in mineralColorSorterSpecs) s['model']];
      expect(models.first, 'SX8');
      expect(models.skip(1), asort);
    });

    test('mỗi model đọc được dải năng suất và có ảnh trong assets', () {
      for (final model in asort) {
        final spec = _spec(model);
        expect(
          parseMineralBands(spec['capacity_display']),
          isNotEmpty,
          reason: model,
        );
        expect(spec['stone_type'], isNotEmpty, reason: model);
        final image = asortSorterImagePath(model);
        expect(image, isNotNull, reason: model);
        expect(File(image!).existsSync(), isTrue, reason: image);
      }
    });

    test('số liệu khớp catalog (mẫu kiểm tra)', () {
      final sa6 = _spec('SA6-2C');
      expect(
        sa6['capacity_display'],
        '0.1–0.4 mm: 2–5 t/h\n0.4–0.7 mm: 3–6 t/h\n0.7–1.2 mm: 5–7 t/h',
      );
      expect(sa6['mix_ratio'], '1 : 15');
      expect(sa6['camera_per_chute'], '2');
      expect(sa6['power_kw'], '6.5');
      expect(sa6['dimensions_display_mm'], '3790 x 2067 x 2611');
      expect(_spec('SA6-2SC')['camera_per_chute'], '4');
      expect(
        _spec('SA4-2BL')['capacity_display'],
        contains('1.2–2.5 mm: 1.5–4 t/h'),
      );
      expect(_spec('SA6-1SL')['capacity_display'], '30–80 mm: 20–50 t/h');
      expect(_spec('SA6-2SL')['weight_kg'], '3693');
      // Bảng bổ sung: số máng, ejector, camera, chiều rộng nhận diện, AI.
      final al = _spec('SA6-2AL');
      expect(al['chutes_qty'], '5');
      expect(al['ejector_per_layer'], '768');
      expect(al['ejector_qty'], '1536'); // 768 × 2 tầng
      expect(al['camera_per_layer'], '12');
      expect(al['recognition_width'], '1800 mm');
      expect(al['sorting_range'], '1.2–5.0 mm');
      expect(_spec('SA6-2C')['ejector_qty'], '1536'); // 128 × 6 × 2
      expect(_spec('SA6-2C')['camera_qty'], '24'); // 2 × 6 × 2
      expect(_spec('SA6-1SL')['ai_function'], 'Tùy chọn (Option)');
      // SA4-1L không có trong bảng bổ sung: chỉ thêm phạm vi phân loại.
      final l = _spec('SA4-1L');
      expect(l['sorting_range'], '6–30 mm');
      expect(l.containsKey('chutes_qty'), isFalse);
      expect(l.containsKey('ai_function'), isFalse);
      // Chỉ dòng SA có Loại nguyên liệu và Phạm vi phân loại.
      final sx8 = _spec('SX8');
      expect(sx8.containsKey('stone_type'), isFalse);
      expect(sx8.containsKey('sorting_range'), isFalse);
    });
  });

  group('selectMineralSorters', () {
    test('đá bột 0.1–0.4 mm, 4 t/h: SA6 vừa đủ xếp trước SA8', () {
      final result = selectMineralSorters(
        mineralColorSorterSpecs,
        _req(0.1, 0.4, 4),
      );
      expect(result.first.model, anyOf('SA6-2C', 'SA6-2SC'));
      expect(result.first.fit, MineralFit.fits);
      expect(result.map((m) => m.model), containsAll(['SX8', 'SA8-2C']));
      expect(
        result.map((m) => m.model),
        isNot(contains('SA4-1AL')),
        reason: 'SA4-1AL chỉ từ 1.2 mm',
      );
    });

    test('dải trải qua nhiều cỡ: năng suất theo dải khó nhất', () {
      final match = selectMineralSorters(
        mineralColorSorterSpecs,
        _req(0.1, 1.2, 5),
      ).firstWhere((m) => m.model == 'SA8-2C');
      expect(match.minTph, 3); // dải 0.1–0.4 mm: 3–6 t/h
      expect(match.maxTph, 6);
      expect(match.fit, MineralFit.fits);
    });

    test('không nhận máy có khoảng trống giữa các dải', () {
      // SA4-1AL: 1.2–2.5, 2.5–5.0, 10–30 mm (trống 5–10 mm).
      expect(_models(_req(3, 8, 5)), isNot(contains('SA4-1AL')));
      expect(_models(_req(12, 20, 5)), contains('SA4-1AL'));
    });

    test('đá ướt chỉ chọn dòng "Đá ướt & khô"', () {
      final models = _models(_req(10, 30, 10, condition: StoneCondition.wet));
      expect(models, containsAll(['SA4-1L', 'SA6-2SL']));
      expect(models, isNot(contains('SA4-2AL')));
      for (final model in models) {
        expect(mineralHandlesWetStone(_spec(model)), isTrue, reason: model);
      }
    });

    test('sản lượng lớn cần nhiều máy; nhỏ hơn mức thấp là dư công suất', () {
      final big = selectMineralSorters(
        mineralColorSorterSpecs,
        _req(40, 60, 120),
      ).single;
      expect(big.model, 'SA6-1SL');
      expect(big.fit, MineralFit.multiple);
      expect(big.machineCount, 3); // 120 / 50

      final small = selectMineralSorters(
        mineralColorSorterSpecs,
        _req(40, 60, 10),
      ).single;
      expect(small.fit, MineralFit.oversized);
    });

    test('không model nào phủ được thì trả rỗng, gợi ý dải hỗ trợ', () {
      expect(_models(_req(5, 9, 3)), isEmpty);
      final wet = mineralSupportedRanges(
        mineralColorSorterSpecs,
        StoneCondition.wet,
      );
      expect(wet, [(6.0, 80.0)]);
    });
  });

  group('Giao diện', () {
    // Màn mới kiểm ở khổ điện thoại nhỏ 360dp.
    Future<void> pump(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: home));
      await tester.pumpAndSettle();
    }

    testWidgets('menu Khoáng sản có mục Chọn máy phù hợp', (tester) async {
      await pump(tester, const MineralColorSorterMenuScreen());
      expect(find.text('Chọn máy phù hợp'), findsOneWidget);
    });

    testWidgets('nhập cỡ hạt và sản lượng thì hiện model đề xuất', (
      tester,
    ) async {
      await pump(tester, const MineralSorterSelectorScreen());
      expect(find.byKey(const Key('mineral_select_message')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('mineral_select_min')), '10');
      await tester.enterText(find.byKey(const Key('mineral_select_max')), '30');
      await tester.enterText(find.byKey(const Key('mineral_select_tph')), '8');
      await tester.pumpAndSettle();

      expect(find.text('Đề xuất'), findsOneWidget);
      expect(
        find.byKey(const Key('mineral_select_result_SA4-1L')),
        findsOneWidget,
      );
    });

    testWidgets('dải không hỗ trợ thì báo và gợi ý', (tester) async {
      await pump(tester, const MineralSorterSelectorScreen());
      await tester.enterText(find.byKey(const Key('mineral_select_min')), '5');
      await tester.enterText(find.byKey(const Key('mineral_select_max')), '9');
      await tester.enterText(find.byKey(const Key('mineral_select_tph')), '3');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mineral_select_no_match')), findsOneWidget);
    });

    testWidgets('màn thông số mở đúng model ASORT kèm ảnh và trường mới', (
      tester,
    ) async {
      // Cùng cách đặt khổ màn hình với test SX8 có sẵn.
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(
          home: MineralColorSorterScreen(initialModel: 'SA6-2C'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Loại nguyên liệu'), findsOneWidget);
      expect(find.text('Phạm vi phân loại'), findsOneWidget);
      expect(find.text('0.1–1.2 mm'), findsOneWidget);
      expect(find.text('Đá bột'), findsWidgets);
      expect(find.text('Tỷ lệ lẫn (xấu : tốt)'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/color_sorter/asort_sa6-2c.jpg',
        ),
        findsOneWidget,
      );
      // SX8 vẫn là một lựa chọn trong danh sách model.
      expect(find.widgetWithText(FilterChip, 'SX8'), findsOneWidget);
    });
  });
}
