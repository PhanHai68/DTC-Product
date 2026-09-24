/// 1 model máy nghiền cụ thể (VD "ASP-350") — dữ liệu lấy nguyên từ sheet
/// `Models` của DTC_Grinding_Machine_Database_AI_Ready.xlsx.
///
/// Các trường thông số kỹ thuật (capacity/input/fineness/motor/kích
/// thước/trọng lượng) đều `nullable`: `null` nghĩa là DATABASE KHÔNG CÓ dữ
/// liệu này cho model — KHÔNG được suy diễn/gán mặc định 0, vì 0 sẽ bị hiểu
/// nhầm là "giá trị thật bằng 0" khi lọc/so sánh/chọn máy.
class GrindingMachine {
  final String machineId;
  final String seriesCode;
  final String model;
  final bool active;
  final int? pdfPage;
  final double? capacityMinKgH;
  final double? capacityMaxKgH;
  final double? inputSizeMaxMm;
  final String? inputSizeNote;
  final double? finenessMin;
  final double? finenessMax;

  /// Đơn vị độ mịn: 'mm' | 'mesh' | 'µm' tuỳ dòng máy — PHẢI đọc cùng
  /// [finenessMin]/[finenessMax], không được so sánh chéo đơn vị.
  final String? finenessUnit;
  final double? mainMotorKwMin;
  final double? mainMotorKwMax;
  final double? speedRpmMin;
  final double? speedRpmMax;
  final double? lengthMm;
  final double? widthMm;
  final double? heightMm;
  final double? weightKg;
  final String? sourceDocument;
  final String? editNote;

  const GrindingMachine({
    required this.machineId,
    required this.seriesCode,
    required this.model,
    this.active = true,
    this.pdfPage,
    this.capacityMinKgH,
    this.capacityMaxKgH,
    this.inputSizeMaxMm,
    this.inputSizeNote,
    this.finenessMin,
    this.finenessMax,
    this.finenessUnit,
    this.mainMotorKwMin,
    this.mainMotorKwMax,
    this.speedRpmMin,
    this.speedRpmMax,
    this.lengthMm,
    this.widthMm,
    this.heightMm,
    this.weightKg,
    this.sourceDocument,
    this.editNote,
  });

  /// Kích thước phủ bì dạng "D x R x C mm" — trả về null nếu thiếu bất kỳ
  /// chiều nào (không hiển thị kích thước không đầy đủ).
  String? get dimensionsDisplay {
    if (lengthMm == null || widthMm == null || heightMm == null) return null;
    String fmt(double v) => v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toString();
    return '${fmt(lengthMm!)} x ${fmt(widthMm!)} x ${fmt(heightMm!)} mm';
  }

  factory GrindingMachine.fromJson(Map<String, dynamic> json) =>
      GrindingMachine(
        machineId: json['machineId'] as String,
        seriesCode: json['seriesCode'] as String,
        model: json['model'] as String,
        active: switch (json['active']) {
          bool v => v,
          int v => v != 0,
          _ => true,
        },
        pdfPage: json['pdfPage'] as int?,
        capacityMinKgH: (json['capacityMinKgH'] as num?)?.toDouble(),
        capacityMaxKgH: (json['capacityMaxKgH'] as num?)?.toDouble(),
        inputSizeMaxMm: (json['inputSizeMaxMm'] as num?)?.toDouble(),
        inputSizeNote: json['inputSizeNote'] as String?,
        finenessMin: (json['finenessMin'] as num?)?.toDouble(),
        finenessMax: (json['finenessMax'] as num?)?.toDouble(),
        finenessUnit: json['finenessUnit'] as String?,
        mainMotorKwMin: (json['mainMotorKwMin'] as num?)?.toDouble(),
        mainMotorKwMax: (json['mainMotorKwMax'] as num?)?.toDouble(),
        speedRpmMin: (json['speedRpmMin'] as num?)?.toDouble(),
        speedRpmMax: (json['speedRpmMax'] as num?)?.toDouble(),
        lengthMm: (json['lengthMm'] as num?)?.toDouble(),
        widthMm: (json['widthMm'] as num?)?.toDouble(),
        heightMm: (json['heightMm'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        sourceDocument: json['sourceDocument'] as String?,
        editNote: json['editNote'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'machineId': machineId,
    'seriesCode': seriesCode,
    'model': model,
    'active': active ? 1 : 0,
    'pdfPage': pdfPage,
    'capacityMinKgH': capacityMinKgH,
    'capacityMaxKgH': capacityMaxKgH,
    'inputSizeMaxMm': inputSizeMaxMm,
    'inputSizeNote': inputSizeNote,
    'finenessMin': finenessMin,
    'finenessMax': finenessMax,
    'finenessUnit': finenessUnit,
    'mainMotorKwMin': mainMotorKwMin,
    'mainMotorKwMax': mainMotorKwMax,
    'speedRpmMin': speedRpmMin,
    'speedRpmMax': speedRpmMax,
    'lengthMm': lengthMm,
    'widthMm': widthMm,
    'heightMm': heightMm,
    'weightKg': weightKg,
    'sourceDocument': sourceDocument,
    'editNote': editNote,
  };
}
