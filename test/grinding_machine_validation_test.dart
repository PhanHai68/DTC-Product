import 'dart:convert';
import 'dart:io';

import 'package:dtc_product/features/grinding_machine/services/grinding_database_validator.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_machine_importer.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> seed() => jsonDecode(File('assets/database/grinding_machine_seed.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('Seed hợp lệ, tên model trùng giữa series được giữ; specs trống là cảnh báo', () {
    final report = GrindingDatabaseValidator.validate(seed());
    expect(report.canImport, isTrue, reason: report.issues.join('\n'));
    expect(report.snapshot!.machines.where((m) => m.model == 'AS-200'), hasLength(2));
    expect(report.issues.where((i) => i.message.contains('thông số trống')), hasLength(4));
  });

  final invalidCases = <String, void Function(Map<String, dynamic>)>{
    'thiếu models': (r) => r.remove('models'),
    'models rỗng': (r) => r['models'] = [],
    'thiếu model': (r) => r['models'][0]['model'] = ' ',
    'thiếu active': (r) => r['models'][0].remove('active'),
    'ID trùng': (r) => r['models'][1]['machineId'] = r['models'][0]['machineId'],
    'tên trùng trong series': (r) => r['models'][1]['model'] = r['models'][0]['model'],
    'series không tồn tại': (r) => r['models'][0]['seriesCode'] = 'MISSING',
    'spec trỏ sai model': (r) => r['extraSpecs'][0]['machineId'] = 'MISSING',
    'mapping trỏ sai nguyên liệu': (r) => r['materialSeriesMap'][0]['materialId'] = 'MISSING',
    'mapping trùng': (r) => (r['materialSeriesMap'] as List).add(Map<String, dynamic>.from(r['materialSeriesMap'][0])),
    'chuỗi thay số': (r) => r['models'][0]['capacityMinKgH'] = 'abc',
    'số âm': (r) => r['models'][0]['capacityMinKgH'] = -1,
    'số không hữu hạn': (r) => r['models'][0]['capacityMinKgH'] = double.infinity,
    'min vượt max': (r) => r['models'][0]['capacityMinKgH'] = 9999,
    'đơn vị sai': (r) => r['models'][0]['finenessUnit'] = 'kg/h',
    'thiếu đơn vị': (r) => r['models'][0]['finenessUnit'] = null,
    'boolean sai': (r) => r['materials'][0]['oily'] = 2,
    'version sai': (r) => r['databaseVersion'] = 'mới nhất',
    'version thiếu': (r) => r.remove('databaseVersion'),
    'config thiếu': (r) => (r['aiConfig'] as List).removeAt(0),
    'config sai kiểu': (r) => r['aiConfig'][0]['value'] = '40',
    'tắt guardrail chưa hỗ trợ': (r) => (r['aiConfig'] as List).firstWhere((v) => v['key'] == 'allow_unknown_input_size')['value'] = false,
  };
  for (final c in invalidCases.entries) {
    test('Chặn ${c.key} trước khi tạo snapshot', () {
      final root = seed();
      c.value(root);
      final report = GrindingDatabaseValidator.validate(root);
      expect(report.hasErrors, isTrue);
      expect(report.snapshot, isNull);
    });
  }
  test('Thiếu thông số kỹ thuật giữ null, không đổi thành zero', () {
    final root = seed();
    root['models'][0]['capacityMinKgH'] = null;
    final report = GrindingDatabaseValidator.validate(root);
    expect(report.canImport, isTrue);
    expect(report.snapshot!.machines.first.capacityMinKgH, isNull);
    expect(report.issues.any((v) => v.message.contains('thiếu thông số')), isTrue);
  });
  test('Chuẩn hóa ký hiệu micron nhưng không sửa source', () {
    final root = seed();
    root['models'][0]['finenessUnit'] = 'μm';
    final report = GrindingDatabaseValidator.validate(root);
    expect(report.snapshot!.machines.first.finenessUnit, 'µm');
    expect(root['models'][0]['finenessUnit'], 'μm');
  });
  test('JSON rỗng/hỏng/sai root bị chặn; BOM UTF-8 được hỗ trợ', () {
    for (final source in ['{}', '[1]', '{', 'null']) {
      expect(GrindingMachineImporter.inspect(source).canImport, isFalse);
    }
    expect(GrindingMachineImporter.inspect('\uFEFF${jsonEncode(seed())}').canImport, isTrue);
  });
  test('So version theo từng thành phần số', () {
    expect(GrindingDatabaseValidator.compareVersions('1.10', '1.2'), greaterThan(0));
    expect(GrindingDatabaseValidator.compareVersions('1.1', '1.1.0'), 0);
    expect(GrindingDatabaseValidator.compareVersions('1.1', '2.0'), lessThan(0));
  });
}
