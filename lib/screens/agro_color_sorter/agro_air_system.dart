import '../../data/product_data.dart';
import '../../providers/acomp_suitable_provider.dart';
import '../../providers/acomp_tank_provider.dart';

/// Nguyên liệu phân loại của dòng H (trong `air_compressor/materials.json`).
const agroAirMaterialName = 'Các loại đậu';

/// Gắn máy nén khí và bình tích khí cho một model dòng H, tính bằng đúng hai
/// chức năng "Lựa chọn công suất máy nén" và "Tính thể tích bình chứa":
/// số ejector × Cm của "Các loại đậu" → công suất tối thiểu → model ACOMP
/// PM VSD cùng công suất → lưu lượng ở áp suất tối ưu → bình chứa đề xuất
/// (các thông số khác của bình giữ mặc định như màn tính bình chứa).
/// Không tính được (thiếu dữ liệu, vượt dải) thì để trống.
Map<String, String> withAgroAirSystem(Map<String, String> spec) {
  final result = Map<String, String>.of(spec)
    ..remove('air_compressor')
    ..remove('air_tank');

  final material = materialDataList
      .where((m) => m.name == agroAirMaterialName)
      .firstOrNull;
  if (material == null) return result;

  final suitable = AcompSuitableProvider()
    ..setMaterial(material)
    ..setEjectorCount(spec['ejector_qty'] ?? '');
  final power = suitable.minPower;
  if (power == null || power <= 0) return result;

  final compressor = acompSpecData
      .where((c) => c.series == 'PM VSD' && c.powerKW == power)
      .firstOrNull;
  if (compressor == null) return result;
  result['air_compressor'] = '${_formatNumber(compressor.powerHP)} HP';

  final flow = material.optimalPressure >= 8
      ? compressor.flow8Bar
      : compressor.flow7Bar;
  final tank = AcompTankProvider()..setQc(flow.toString());
  final volume = tank.vRec;
  if (volume != null && volume > 0) {
    result['air_tank'] = '${_formatNumber(volume)} lít';
  }
  return result;
}

String _formatNumber(double value) => value == value.truncateToDouble()
    ? value.toInt().toString()
    : value.toString();
