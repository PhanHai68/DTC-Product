/// Dữ liệu tra cứu lỗi máy tách màu — `color_sorter/common_errors.json`.
/// Dùng chung cho mọi dòng máy (gạo, thóc, trà, khoáng sản, nông sản).
class ColorSorterErrors {
  const ColorSorterErrors({
    required this.common,
    required this.detailed,
    required this.poorSorting,
    required this.blocks,
    required this.etmOutputs,
  });

  factory ColorSorterErrors.fromJson(Map<String, dynamic> json) =>
      ColorSorterErrors(
        common: [
          for (final item in json['common'] as List)
            CommonSorterError.fromJson(item as Map<String, dynamic>),
        ],
        detailed: [
          for (final item in json['detailed'] as List)
            DetailedSorterError.fromJson(item as Map<String, dynamic>),
        ],
        poorSorting: [
          for (final item in json['poorSorting'] as List)
            PoorSortingCause.fromJson(item as Map<String, dynamic>),
        ],
        blocks: [
          for (final item in json['blocks'] as List)
            SorterBlock.fromJson(item as Map<String, dynamic>),
        ],
        etmOutputs: [
          for (final item in json['etmOutputs'] as List)
            EtmOutput.fromJson(item as Map<String, dynamic>),
        ],
      );

  /// Lỗi thường gặp khi vận hành: tên lỗi → các bước kiểm tra.
  final List<CommonSorterError> common;

  /// Lỗi chi tiết: tên lỗi → từng nguyên nhân kèm cách khắc phục.
  final List<DetailedSorterError> detailed;

  /// Nguyên nhân tách màu kém (lọt hạt xấu, hao hạt tốt).
  final List<PoorSortingCause> poorSorting;

  /// Nguồn cấp và kết nối các khối điện.
  final List<SorterBlock> blocks;

  /// Chức năng các ngõ ra ETM #1 – #7.
  final List<EtmOutput> etmOutputs;
}

List<String> _strings(Object? value) => [
  for (final item in value as List) item as String,
];

class CommonSorterError {
  const CommonSorterError({required this.error, required this.checks});

  factory CommonSorterError.fromJson(Map<String, dynamic> json) =>
      CommonSorterError(
        error: json['error'] as String,
        checks: _strings(json['checks']),
      );

  final String error;
  final List<String> checks;
}

class DetailedSorterError {
  const DetailedSorterError({required this.error, required this.causes});

  factory DetailedSorterError.fromJson(Map<String, dynamic> json) =>
      DetailedSorterError(
        error: json['error'] as String,
        causes: [
          for (final item in json['causes'] as List)
            (
              cause: (item as Map)['cause'] as String,
              fix: item['fix'] as String,
            ),
        ],
      );

  final String error;
  final List<({String cause, String fix})> causes;
}

class PoorSortingCause {
  const PoorSortingCause({
    required this.cause,
    required this.explanation,
    required this.fixes,
    required this.note,
  });

  factory PoorSortingCause.fromJson(Map<String, dynamic> json) =>
      PoorSortingCause(
        cause: json['cause'] as String,
        explanation: json['explanation'] as String,
        fixes: _strings(json['fixes']),
        note: json['note'] as String? ?? '',
      );

  final String cause;
  final String explanation;
  final List<String> fixes;

  /// Bộ phận/điểm đo liên quan (VD "ETM #4, van solenoid").
  final String note;
}

class SorterBlock {
  const SorterBlock({
    required this.block,
    required this.power,
    required this.connections,
    required this.note,
  });

  factory SorterBlock.fromJson(Map<String, dynamic> json) => SorterBlock(
    block: json['block'] as String,
    power: json['power'] as String,
    connections: json['connections'] as String,
    note: json['note'] as String? ?? '',
  );

  final String block;
  final String power;
  final String connections;
  final String note;
}

class EtmOutput {
  const EtmOutput({
    required this.output,
    required this.function,
    required this.target,
    required this.note,
  });

  factory EtmOutput.fromJson(Map<String, dynamic> json) => EtmOutput(
    output: json['output'] as String,
    function: json['function'] as String,
    target: json['target'] as String? ?? '',
    note: json['note'] as String? ?? '',
  );

  final String output;
  final String function;
  final String target;
  final String note;
}
