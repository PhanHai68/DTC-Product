import '../models/grinding_machine.dart';

/// Định dạng hiển thị cho thông số máy nghiền — dùng chung cho list/detail/
/// compare để không lặp code format số ở nhiều nơi. CHỈ định dạng dữ liệu đã
/// có, không tự tạo giá trị khi thiếu (trả về `null`/rỗng để UI tự ẩn).
abstract final class GrindingFormat {
  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// "80 - 300 kg/h" — null nếu thiếu cả 2 mốc.
  static String? capacityRange(GrindingMachine machine) {
    final min = machine.capacityMinKgH;
    final max = machine.capacityMaxKgH;
    if (min == null && max == null) return null;
    if (min != null && max != null) {
      return '${_num(min)} - ${_num(max)} kg/h';
    }
    return '${_num((min ?? max)!)} kg/h';
  }

  /// "0.5 - 20 mm" / "10 - 120 mesh" — null nếu thiếu dữ liệu hoặc thiếu đơn
  /// vị (không hiển thị số mà không rõ đơn vị).
  static String? finenessRange(GrindingMachine machine) {
    final unit = machine.finenessUnit;
    final min = machine.finenessMin;
    final max = machine.finenessMax;
    if (unit == null || unit.isEmpty) return null;
    if (min == null && max == null) return null;
    if (min != null && max != null) {
      return '${_num(min)} - ${_num(max)} $unit';
    }
    return '${_num((min ?? max)!)} $unit';
  }

  /// "3 - 7.5 kW" — null nếu thiếu cả 2 mốc.
  static String? motorRange(GrindingMachine machine) {
    final min = machine.mainMotorKwMin;
    final max = machine.mainMotorKwMax;
    if (min == null && max == null) return null;
    if (min != null && max != null && min != max) {
      return '${_num(min)} - ${_num(max)} kW';
    }
    return '${_num((min ?? max)!)} kW';
  }

  /// "≤ 100 mm" — null nếu database không có input size.
  static String? inputSize(GrindingMachine machine) {
    if (machine.inputSizeNote != null && machine.inputSizeNote!.isNotEmpty) {
      return machine.inputSizeNote;
    }
    if (machine.inputSizeMaxMm != null) {
      return '≤ ${_num(machine.inputSizeMaxMm!)} mm';
    }
    return null;
  }

  /// Nhãn tiếng Việt ngắn cho 1 Selection Tag (mục 7 "Yêu cầu đặc biệt") —
  /// chỉ các tag THẬT SỰ có trong database mới hiển thị (không hard-code
  /// danh sách tag). Tag không có trong bảng dịch thì hiển thị nguyên văn đã
  /// thay "_" bằng khoảng trắng, không tự bịa nhãn sai nghĩa.
  static String tagLabel(String tag) {
    const labels = {
      'food': 'Thực phẩm',
      'chemical': 'Hóa chất',
      'pharma': 'Dược phẩm',
      'fibrous': 'Nguyên liệu giàu xơ',
      'hard_material': 'Nguyên liệu cứng',
      'heat_sensitive': 'Nhạy nhiệt',
      'low_heat': 'Sinh nhiệt thấp',
      'cryogenic': 'Làm lạnh sâu (nitơ lỏng)',
      'liquid_nitrogen': 'Cần nitơ lỏng',
      'nitrogen_optional': 'Có thể dùng nitơ lỏng',
      'wet': 'Nguyên liệu ẩm',
      'sticky': 'Nguyên liệu dính',
      'paste': 'Dạng nhão',
      'oily': 'Nguyên liệu dầu',
      'crystalline': 'Dạng kết tinh',
      'brittle': 'Giòn/dễ vỡ',
      'ultrafine': 'Bột siêu mịn',
      'ultrafine_um': 'Bột siêu mịn (µm)',
      'powder': 'Dạng bột',
      'low_fineness': 'Độ mịn thấp',
      'coarse': 'Nghiền thô',
      'pre_crushing': 'Nghiền sơ cấp',
      'large_input': 'Đầu vào kích thước lớn',
      'small_capacity': 'Công suất nhỏ',
      'continuous': 'Vận hành liên tục',
      'variable_speed': 'Tốc độ điều chỉnh được',
      'easy_clean': 'Dễ vệ sinh',
      'energy_saving': 'Tiết kiệm điện',
      'dust_control': 'Kiểm soát bụi',
      'dust_collection': 'Thu gom bụi',
      'dust_filter': 'Lọc bụi',
      'compressed_air': 'Cần khí nén',
      'screenless': 'Không dùng lưới lọc',
      'universal': 'Đa năng',
    };
    return labels[tag] ?? tag.replaceAll('_', ' ');
  }
}
