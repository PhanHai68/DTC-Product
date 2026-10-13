import 'package:dtc_product/data/product_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kiểm tra dữ liệu trong assets/database/color_sorter/ sau mỗi lần sửa JSON:
/// test báo rõ file, model và trường bị sai.
void main() {
  group('Máy tách màu', () {
    final specsByFile = {
      'sc_rice.json': () => colorSorterSpecs,
      'sf7_paddy.json': () => paddyColorSorterSpecs,
      'df_tea.json': () => teaColorSorterSpecs,
      'sx8_mineral.json': () => mineralColorSorterSpecs,
      'h7_agro.json': () => agroColorSorterSpecs,
    };

    specsByFile.forEach((file, specs) {
      test('$file: mỗi máy có tên model và không trùng model', () {
        final models = <String>[];
        for (final (index, spec) in specs().indexed) {
          final model = (spec['Model'] ?? spec['model'] ?? '').trim();
          expect(
            model,
            isNotEmpty,
            reason: '$file: mục thứ ${index + 1} thiếu model',
          );
          models.add(model);
        }
        expect(models, isNotEmpty, reason: '$file không có máy nào');
        expect(
          models.toSet().length,
          models.length,
          reason: '$file có model bị trùng: $models',
        );
      });
    });

    test('df_tea.json, sx8_mineral.json, h7_agro.json: id không trùng', () {
      final ids = [
        for (final spec in [
          ...teaColorSorterSpecs,
          ...mineralColorSorterSpecs,
          ...agroColorSorterSpecs,
        ])
          spec['id'],
      ];
      expect(ids, everyElement(isNotNull));
      expect(ids.toSet().length, ids.length, reason: 'id bị trùng: $ids');
    });

    test('aux_equipment.json: model nào cũng có danh sách thiết bị có tên', () {
      expect(auxEquipSpecsByModel, isNotEmpty);
      auxEquipSpecsByModel.forEach((model, items) {
        expect(items, isNotEmpty, reason: '$model không có thiết bị nào');
        for (final item in items) {
          expect(
            item['Tên thiết bị']?.trim(),
            isNotEmpty,
            reason: '$model có thiết bị thiếu "Tên thiết bị"',
          );
        }
      });
    });

    test(
      'tea_aux_equipment.json: thiết bị có tên và components là danh sách',
      () {
        for (final item in teaAuxEquipData) {
          expect((item['name'] as String).trim(), isNotEmpty);
          final components = item['components'];
          if (components != null) {
            expect(
              components,
              isA<List<String>>(),
              reason: '${item['name']}: components phải là danh sách chuỗi',
            );
          }
        }
      },
    );
  });

  test('báo lỗi rõ ràng khi file JSON sai cú pháp', () {
    final sources = {for (final path in ProductData.assetPaths) path: '[]'};
    sources[ProductData.auxEquipmentPath] = '{}';
    sources[ProductData.colorSorterRicePath] = '[{"Model": "SC4",}]';
    expect(
      () => ProductData.loadFromStrings(sources),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('sc_rice.json'),
        ),
      ),
    );
  });
}
