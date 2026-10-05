import '../models/grinding_machine.dart';

/// Định dạng hiển thị cho thông số máy nghiền — dùng chung cho list/detail/
/// compare để không lặp code format số ở nhiều nơi. CHỈ định dạng dữ liệu đã
/// có, không tự tạo giá trị khi thiếu (trả về `null`/rỗng để UI tự ẩn).
abstract final class GrindingFormat {
  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  /// So sánh tên model theo số tự nhiên: "ASC-200" < "ASC-300" < "ASC-1000"
  /// (SQL "ORDER BY model" so chuỗi nên "ASC-1000" đứng trước "ASC-200").
  static int compareModel(String a, String b) {
    final chunk = RegExp(r'\d+|\D+');
    final left = chunk.allMatches(a.toUpperCase()).map((m) => m[0]!).toList();
    final right = chunk.allMatches(b.toUpperCase()).map((m) => m[0]!).toList();
    for (var i = 0; i < left.length && i < right.length; i++) {
      final x = int.tryParse(left[i]);
      final y = int.tryParse(right[i]);
      final c = x != null && y != null
          ? x.compareTo(y)
          : left[i].compareTo(right[i]);
      if (c != 0) return c;
    }
    return left.length.compareTo(right.length);
  }

  /// Sắp theo dòng máy rồi model (số tự nhiên).
  static int compareMachine(GrindingMachine a, GrindingMachine b) {
    final bySeries = a.seriesCode.compareTo(b.seriesCode);
    return bySeries != 0 ? bySeries : compareModel(a.model, b.model);
  }

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
      // Nguyên lý / cấu tạo máy
      'cutting': 'Nghiền cắt',
      'hammer': 'Nghiền búa',
      'impact': 'Nghiền va đập',
      'pin_mill': 'Nghiền chốt',
      'jet_mill': 'Nghiền khí (Jet mill)',
      'roller': 'Nghiền trục cán',
      'screen': 'Có lưới sàng',
      'classifier': 'Có bộ phân cấp',
      'air_classifier': 'Phân cấp bằng khí',
      'multi_stage': 'Nghiền nhiều cấp',
      'blower': 'Có quạt hút',
      'cyclone': 'Có cyclone thu liệu',
      'cooling_air': 'Làm mát bằng khí',
      'coating': 'Bọc phủ hạt',
      // Nhóm nguyên liệu
      'almond': 'Hạnh nhân',
      'cacao': 'Ca cao',
      'peanut': 'Đậu phộng',
      'sesame': 'Mè (vừng)',
      'fruit': 'Trái cây',
      'vegetable': 'Rau củ',
      'herb': 'Dược liệu / thảo mộc',
      'medicine': 'Thuốc',
      'feed': 'Thức ăn chăn nuôi',
      'granule': 'Dạng hạt',
      'mineral': 'Khoáng sản',
      'plastic': 'Nhựa',
      'rubber': 'Cao su',
    };
    return labels[tag] ?? tag.replaceAll('_', ' ');
  }
}
