import 'package:dtc_product/models/material_model.dart';
import 'package:dtc_product/providers/acomp_suitable_provider.dart';
import 'package:dtc_product/providers/acomp_tank_provider.dart';
import 'package:dtc_product/providers/color_sorter_provider.dart';
import 'package:flutter_test/flutter_test.dart';

AcompSuitableProvider _compressor(double power) => AcompSuitableProvider()
  ..setMaterial(
    MaterialModel(
      id: 1,
      name: 'Test',
      cm: power * 1000 / (1.3 * 6.2),
      optimalPressure: 7,
    ),
  )
  ..setEjectorCount('1');

AcompTankProvider _tank(String flow) => AcompTankProvider()
  ..setT0('35')
  ..setT1('35')
  ..setQc(flow);

void main() {
  group('Color sorter', () {
    for (final capacity in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      22.001,
      100.0,
    ]) {
      test('không đề xuất máy khi đầu vào $capacity không được hỗ trợ', () {
        final provider = ColorSorterProvider();
        addTearDown(provider.dispose);
        final result = provider.suggestModelByCapacity(capacity);
        expect(result['model'], isNull);
        expect(result['reason'], isNotEmpty);
      });
    }
    for (final entry in {
      6.0: 'SC4',
      8.5: 'SC8',
      11.5: 'SC10',
      16.0: 'SC12',
      16.001: 'SC16 Pro',
      22.0: 'SC16 Pro',
    }.entries) {
      test(
        'ngưỡng ${entry.key} chọn ${entry.value} có đủ năng suất catalog',
        () {
          final provider = ColorSorterProvider();
          addTearDown(provider.dispose);
          final result = provider.suggestModelByCapacity(entry.key);
          expect(result['model'], entry.value);
          final range = provider.getSpecByModel(
            entry.value,
          )!['Năng suất (tấn/giờ)']!;
          final max = double.parse(range.split('-').last.trim());
          expect(max, greaterThanOrEqualTo(entry.key));
        },
      );
    }
  });

  group('Compressor', () {
    for (final entry in {
      10.9: 11.0,
      11.1: 15.0,
      15.1: 22.0,
      22.1: 37.0,
      37.1: 45.0,
      45.1: 55.0,
      55.1: 75.0,
      75.1: 90.0,
      90.0: 90.0,
    }.entries) {
      test('nhu cầu ${entry.key} kW chọn ${entry.value} kW', () {
        final provider = _compressor(entry.key);
        addTearDown(provider.dispose);
        expect(provider.requiredPower, closeTo(entry.key, 1e-10));
        expect(provider.minPower, entry.value);
        expect(provider.recommendationError, isNull);
      });
    }
    test('vượt 90 kW không trả về máy 90 kW', () {
      final provider = _compressor(90.001);
      addTearDown(provider.dispose);
      expect(provider.minPower, isNull);
      expect(provider.recommendationError, contains('vượt 90 kW'));
    });
    for (final cm in [
      double.nan,
      double.infinity,
      -1.0,
      0.0,
      double.maxFinite,
    ]) {
      test('hệ số khí $cm không sinh đề xuất sai', () {
        final provider = AcompSuitableProvider()
          ..setMaterial(
            MaterialModel(id: 1, name: 'Test', cm: cm, optimalPressure: 7),
          )
          ..setEjectorCount('2');
        addTearDown(provider.dispose);
        expect(provider.minPower, isNull);
        expect(provider.recommendationError, isNotNull);
      });
    }
    test('chưa nhập béc không chọn máy và không có cảnh báo vượt dải', () {
      final provider = AcompSuitableProvider();
      addTearDown(provider.dispose);
      expect(provider.minPower, 0);
      expect(provider.recommendationError, isNull);
    });
  });

  group('Tank', () {
    test('giữ phép tính và bảng chọn trong dải hỗ trợ', () {
      final provider = _tank('1');
      addTearDown(provider.dispose);
      expect(provider.vTh, closeTo(1000 / 6, 1e-10));
      expect(provider.vRec, 200);
      expect(provider.recommendationError, isNull);
    });
    test('3.000 lít vẫn thuộc giới hạn; vượt giới hạn không ép về 3.000', () {
      final provider = _tank('18');
      addTearDown(provider.dispose);
      expect(provider.vTh, closeTo(3000, 1e-10));
      expect(provider.vRec, 3000);
      provider.setQc('18,001');
      expect(provider.vRec, isNull);
      expect(provider.recommendationError, contains('vượt 3.000 lít'));
    });
    for (final field in ['qc', 'tc', 'deltaP', 't0', 't1']) {
      test('chặn đầu vào không hữu hạn ở $field', () {
        final provider = _tank('1');
        addTearDown(provider.dispose);
        switch (field) {
          case 'qc':
            provider.setQc('Infinity');
          case 'tc':
            provider.setTc('NaN');
          case 'deltaP':
            provider.setDeltaP('Infinity');
          case 't0':
            provider.setT0('NaN');
          case 't1':
            provider.setT1('Infinity');
        }
        expect(provider.vRec, isNull);
        expect(provider.inputError, isNotNull);
      });
    }
    test('xóa thông số không âm thầm dùng lại mặc định', () {
      final provider = _tank('1');
      addTearDown(provider.dispose);
      provider.setTc('');
      expect(provider.vRec, isNull);
      expect(provider.inputError, isNotNull);
    });
    test('chu kỳ hoặc chênh áp bằng 0 không đề xuất bình 0 lít', () {
      final provider = _tank('1');
      addTearDown(provider.dispose);
      provider.setTc('0');
      expect(provider.vRec, isNull);
      provider.setTc('20');
      provider.setDeltaP('0');
      expect(provider.vRec, isNull);
    });
    test('chặn nhiệt độ làm mẫu số bằng 0 hoặc dung tích âm', () {
      final provider = _tank('1');
      addTearDown(provider.dispose);
      provider.setT1('-273,15');
      expect(provider.vRec, isNull);
      provider.setT1('35');
      provider.setT0('-300');
      expect(provider.vRec, isNull);
    });
    test('tràn số không trả về bình lớn nhất', () {
      final provider = _tank('1e308');
      addTearDown(provider.dispose);
      expect(provider.vRec, isNull);
      expect(provider.recommendationError, isNotNull);
    });
  });
}
