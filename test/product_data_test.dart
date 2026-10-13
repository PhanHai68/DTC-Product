import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/models/packing_feature.dart';
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

  group('Máy nén khí', () {
    test('specs.json: model không trùng, series hợp lệ, số liệu dương', () {
      final codes = <String>[];
      for (final spec in acompSpecData) {
        expect(spec.modelCode.trim(), isNotEmpty);
        codes.add(spec.modelCode);
        // AcompSpecProvider tách 2 danh sách theo đúng 2 tên series này.
        expect(
          spec.series,
          anyOf('PM VSD', 'Fixed Speed'),
          reason:
              '${spec.modelCode}: series phải là "PM VSD" hoặc "Fixed Speed"',
        );
        for (final (name, value) in [
          ('powerKW', spec.powerKW),
          ('powerHP', spec.powerHP),
          ('flow7Bar', spec.flow7Bar),
          ('flow8Bar', spec.flow8Bar),
        ]) {
          expect(value, greaterThan(0), reason: '${spec.modelCode}: $name');
        }
      }
      expect(codes.toSet().length, codes.length, reason: 'model bị trùng');
    });

    test('bảng lưu lượng sinh đúng từ specs.json', () {
      expect(acompModelsFlowData.length, acompSpecData.length);
      final first = acompSpecData.first;
      expect(acompModelsFlowData.first['model'], first.modelCode);
      expect(
        double.parse(acompModelsFlowData.first['flow7bar'] as String),
        first.flow7Bar,
      );
    });

    test('mccb_cable.json: model không trùng', () {
      final models = [for (final row in acompMccbData) row['model']];
      expect(models, everyElement(isNotNull));
      expect(models.toSet().length, models.length);
    });

    test('pipe_standard.json: đường kính tăng dần', () {
      // Màn tính ống chọn ống đầu tiên đủ lớn, nên bảng phải xếp tăng dần.
      final sizes = [for (final pipe in pipeStandardData) pipe['mm'] as num];
      for (var i = 1; i < sizes.length; i++) {
        expect(
          sizes[i],
          greaterThan(sizes[i - 1]),
          reason: 'pipe_standard.json: dòng ${i + 1} nhỏ hơn dòng trên',
        );
      }
    });

    test('common_errors.json: đủ 3 nhóm lỗi', () {
      expect(commonErrorsGeneral, isNotEmpty);
      expect(commonErrorsController, isNotEmpty);
      expect(commonErrorsOilLoss, isNotEmpty);
    });

    test('ds8011.json: mỗi tham số có mã và mô tả', () {
      for (final category in ds8011Parameters) {
        final items = category['items'] as List;
        expect(items, isNotEmpty, reason: '${category['category']}');
        for (final item in items.cast<Map<String, dynamic>>()) {
          expect((item['code'] as String).trim(), isNotEmpty);
          expect((item['description'] as String).trim(), isNotEmpty);
        }
      }
    });
  });

  group('Cân đóng gói', () {
    test('machines.json: model và stt không trùng', () {
      final models = [for (final m in packingMachines) m.model];
      final stts = [for (final m in packingMachines) m.stt];
      expect(models, everyElement(isNotEmpty));
      expect(models.toSet().length, models.length, reason: 'model bị trùng');
      expect(stts, everyElement(isNotNull), reason: 'máy thiếu stt');
      expect(stts.toSet().length, stts.length, reason: 'stt bị trùng');
    });

    test('machines.json: feature_set nào cũng có trong features.json', () {
      for (final machine in packingMachines) {
        expect(
          packingFeatureSets.keys,
          contains(machine.featureSet),
          reason:
              '${machine.model}: feature_set "${machine.featureSet}" '
              'không có trong features.json',
        );
      }
    });

    test('features.json: đủ nội dung và icon có trong app', () {
      packingFeatureSets.forEach((name, features) {
        expect(features, isNotEmpty, reason: 'bộ $name rỗng');
        for (final feature in features) {
          expect(feature['title']?.trim(), isNotEmpty, reason: 'bộ $name');
          expect(
            packingFeatureIcons.keys,
            contains(feature['icon']),
            reason:
                '$name / ${feature['title']}: icon "${feature['icon']}" '
                'chưa có trong packingFeatureIcons',
          );
        }
      });
    });
  });

  group('Dữ liệu dùng chung', () {
    test('air_compressor/materials.json: id không trùng, hệ số dương', () {
      final ids = [for (final m in materialDataList) m.id];
      expect(ids.toSet().length, ids.length, reason: 'id bị trùng');
      for (final m in materialDataList) {
        expect(m.name.trim(), isNotEmpty);
        expect(m.cm, greaterThan(0), reason: m.name);
        expect(m.optimalPressure, greaterThan(0), reason: m.name);
      }
    });

    test('color_sorter/power_consumption.json: model nào cũng có số liệu', () {
      expect(powerConsumptionData, isNotEmpty);
      powerConsumptionData.forEach((model, rows) {
        expect(rows, isNotEmpty, reason: model);
        for (final row in rows) {
          expect(row['Tiêu chí']?.trim(), isNotEmpty, reason: model);
        }
      });
    });
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
