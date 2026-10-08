import 'dart:convert';

/// Catalog thiết bị (máy đóng gói / trộn / sàng) — dữ liệu tĩnh đọc từ 1
/// asset JSON, CHỈ gồm thông số có trong catalog nhà cung cấp. Tách khỏi
/// database máy nghiền để công cụ chọn máy, bộ lọc, sao lưu và file Excel
/// nguồn của máy nghiền không bị ảnh hưởng.
class EquipmentCatalog {
  const EquipmentCatalog({
    required this.catalogVersion,
    required this.criteria,
    required this.series,
    required this.machines,
  });

  final String catalogVersion;

  /// Tiêu chí của công cụ "Chọn máy phù hợp" (khác nhau theo loại máy).
  final List<SelectorCriterion> criteria;
  final List<EquipmentSeries> series;
  final List<EquipmentMachine> machines;

  factory EquipmentCatalog.parse(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    return EquipmentCatalog(
      catalogVersion: root['catalogVersion'] as String? ?? '',
      criteria: [
        for (final c in root['criteria'] as List? ?? const [])
          SelectorCriterion.fromJson(c as Map<String, dynamic>),
      ],
      series: [
        for (final s in root['series'] as List)
          EquipmentSeries.fromJson(s as Map<String, dynamic>),
      ],
      machines: [
        for (final m in root['machines'] as List)
          EquipmentMachine.fromJson(m as Map<String, dynamic>),
      ],
    );
  }
}

/// 1 dòng máy. Các khối chữ cùng ý nghĩa với GrindingSeries để trang dòng
/// máy / trang thông số hiển thị y hệt máy nghiền.
class EquipmentSeries {
  const EquipmentSeries({
    required this.seriesCode,
    required this.displayCode,
    required this.nameVi,
    this.nameEn = '',
    this.groupVi = '',
    this.pdfPages = '',
    this.image,
    this.imageCaption,
    this.applicationVi = '',
    this.structureVi = '',
    this.workingPrincipleVi = '',
    this.featuresVi = '',
    this.notes = '',
  });

  final String seriesCode;
  final String displayCode;
  final String nameVi;
  final String nameEn;

  /// Nhóm công đoạn để trang chính chia mục (VD "Xát trắng & lau bóng").
  /// Rỗng thì trang chính liệt kê dòng máy liền một danh sách.
  final String groupVi;
  final String pdfPages;
  final String? image;
  final String? imageCaption;
  final String applicationVi;
  final String structureVi;
  final String workingPrincipleVi;
  final String featuresVi;

  /// Ghi chú nội bộ (Remark trong catalog) — không hiển thị cho khách.
  final String notes;

  factory EquipmentSeries.fromJson(Map<String, dynamic> json) =>
      EquipmentSeries(
        seriesCode: json['seriesCode'] as String,
        displayCode: json['displayCode'] as String? ?? '',
        nameVi: json['nameVi'] as String? ?? '',
        nameEn: json['nameEn'] as String? ?? '',
        groupVi: json['groupVi'] as String? ?? '',
        pdfPages: json['pdfPages'] as String? ?? '',
        image: json['image'] as String?,
        imageCaption: json['imageCaption'] as String?,
        applicationVi: json['applicationVi'] as String? ?? '',
        structureVi: json['structureVi'] as String? ?? '',
        workingPrincipleVi: json['workingPrincipleVi'] as String? ?? '',
        featuresVi: json['featuresVi'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}

/// Nhóm thông số = 3 tab trên trang thông số.
enum EquipmentSpecGroup { technical, extra, install }

class EquipmentSpec {
  const EquipmentSpec({
    required this.group,
    required this.key,
    required this.label,
    required this.value,
  });

  final EquipmentSpecGroup group;

  /// Khoá ngữ nghĩa (pack_weight, work_volume, mesh...) — quyết định
  /// icon/màu, ô giá trị trên thẻ model và hàng trong bảng so sánh.
  final String key;
  final String label;
  final String value;

  factory EquipmentSpec.fromJson(Map<String, dynamic> json) => EquipmentSpec(
    group: EquipmentSpecGroup.values.byName(json['group'] as String),
    key: json['key'] as String,
    label: json['label'] as String,
    value: json['value'] as String,
  );
}

/// Thẻ chỉ số nổi bật: [title] đã kèm đơn vị, [value] chỉ có số — giống
/// "Công suất (kg/h) / 80 - 300" của máy nghiền.
class EquipmentHighlight {
  const EquipmentHighlight({
    required this.kind,
    required this.title,
    required this.value,
  });

  /// speed | weight | power | volume | capacity | mesh — chọn icon/màu.
  final String kind;
  final String title;
  final String value;

  factory EquipmentHighlight.fromJson(Map<String, dynamic> json) =>
      EquipmentHighlight(
        kind: json['kind'] as String,
        title: json['title'] as String,
        value: json['value'] as String,
      );
}

/// Kiểu đối chiếu của 1 tiêu chí chọn máy.
enum SelectorCriterionType {
  /// Chọn 1 lựa chọn; máy đạt khi danh sách của máy có lựa chọn đó.
  choice,

  /// Giá trị yêu cầu phải nằm trong dải [min, max] của máy (máy chỉ ghi mức
  /// tối đa thì chỉ so với mức tối đa).
  range,

  /// Khả năng tối đa của máy phải ≥ yêu cầu (dung tích, năng suất, tốc độ).
  atLeast,

  /// Giá trị của máy phải ≤ giới hạn (công suất điện).
  atMost,
}

class SelectorOption {
  const SelectorOption(this.value, this.label);

  final String value;
  final String label;
}

/// Đơn vị nhập/hiển thị; [factor] quy về đơn vị gốc (VD kg = 1000 g).
class SelectorUnit {
  const SelectorUnit(this.label, this.factor);

  final String label;
  final double factor;
}

class SelectorCriterion {
  const SelectorCriterion({
    required this.key,
    required this.type,
    required this.label,
    String? inputLabel,
    this.options = const [],
    this.units = const [],
    this.matchNote,
  }) : inputLabel = inputLabel ?? label;

  final String key;
  final SelectorCriterionType type;

  /// Tên tiêu chí trong kết quả, VD "Khối lượng mỗi gói".
  final String label;

  /// Nhãn ô nhập trên form.
  final String inputLabel;
  final List<SelectorOption> options;

  /// Đơn vị tăng dần theo [SelectorUnit.factor]; phần tử đầu là đơn vị gốc.
  final List<SelectorUnit> units;

  /// Ghi chú thêm khi đạt (VD "thực tế tùy nguyên liệu").
  final String? matchNote;

  bool get isNumeric => type != SelectorCriterionType.choice;

  String labelOf(String option) => options
      .firstWhere(
        (o) => o.value == option,
        orElse: () => SelectorOption(option, option),
      )
      .label;

  factory SelectorCriterion.fromJson(Map<String, dynamic> json) =>
      SelectorCriterion(
        key: json['key'] as String,
        type: SelectorCriterionType.values.byName(json['type'] as String),
        label: json['label'] as String,
        inputLabel: json['inputLabel'] as String?,
        options: [
          for (final o in json['options'] as List? ?? const [])
            SelectorOption(
              (o as Map<String, dynamic>)['value'] as String,
              o['label'] as String,
            ),
        ],
        units: [
          for (final u in json['units'] as List? ?? const [])
            SelectorUnit(
              (u as Map<String, dynamic>)['label'] as String,
              (u['factor'] as num).toDouble(),
            ),
        ],
        matchNote: json['matchNote'] as String?,
      );
}

/// Số liệu chọn máy của 1 model cho 1 tiêu chí. `null` ở mọi trường nghĩa
/// là catalog không nói rõ: bộ chọn máy báo "chưa có dữ liệu", KHÔNG coi là
/// đạt hay không đạt.
class SelectorValue {
  const SelectorValue({
    this.options,
    this.min,
    this.max,
    this.limit,
    this.unit,
  });

  /// Lựa chọn máy đáp ứng (tiêu chí choice).
  final Set<String>? options;
  final double? min;
  final double? max;

  /// Giới hạn trên đã biết khi chưa có [max] (VD chỉ có tổng dung tích
  /// thùng, chưa có dung tích nạp tối đa): yêu cầu vượt [limit] chắc chắn
  /// không đạt, còn lại là chưa đủ dữ liệu.
  final double? limit;

  /// Đơn vị hiển thị riêng của model (VD "bao/phút" thay cho "túi/phút").
  final String? unit;

  factory SelectorValue.fromJson(Object? json) {
    if (json is List) {
      return SelectorValue(options: {for (final o in json) o as String});
    }
    final map = json as Map<String, dynamic>;
    return SelectorValue(
      min: (map['min'] as num?)?.toDouble(),
      max: (map['max'] as num?)?.toDouble(),
      limit: (map['limit'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
    );
  }
}

class EquipmentMachine {
  const EquipmentMachine({
    required this.machineId,
    required this.seriesCode,
    required this.model,
    this.pdfPage,
    this.image,
    this.imageCaption,
    this.needsVerification = false,
    this.verificationNote,
    this.selection = const {},
    this.selectionNotes = const {},
    this.highlights = const [],
    this.specs = const [],
  });

  final String machineId;
  final String seriesCode;
  final String model;
  final int? pdfPage;

  /// Ảnh riêng của model — null thì dùng ảnh của dòng máy.
  final String? image;
  final String? imageCaption;

  /// Cờ nội bộ: catalog có số liệu lệch nhau, cần xác nhận với nhà cung cấp.
  /// KHÔNG hiển thị cho khách hàng.
  final bool needsVerification;
  final String? verificationNote;

  /// Khoá tiêu chí → số liệu chọn máy. Thiếu khoá = chưa có dữ liệu.
  final Map<String, SelectorValue> selection;

  /// Lý do riêng khi tiêu chí chưa có dữ liệu (VD thiết bị định lượng không
  /// quyết định loại bao bì).
  final Map<String, String> selectionNotes;

  final List<EquipmentHighlight> highlights;
  final List<EquipmentSpec> specs;

  List<EquipmentSpec> specsOf(EquipmentSpecGroup group) =>
      specs.where((s) => s.group == group).toList();

  String? valueOf(String key) {
    for (final spec in specs) {
      if (spec.key == key) return spec.value;
    }
    return null;
  }

  factory EquipmentMachine.fromJson(
    Map<String, dynamic> json,
  ) => EquipmentMachine(
    machineId: json['machineId'] as String,
    seriesCode: json['seriesCode'] as String,
    model: json['model'] as String,
    pdfPage: json['pdfPage'] as int?,
    image: json['image'] as String?,
    imageCaption: json['imageCaption'] as String?,
    needsVerification: json['needsVerification'] as bool? ?? false,
    verificationNote: json['verificationNote'] as String?,
    selection: {
      for (final MapEntry(:key, :value)
          in (json['selection'] as Map<String, dynamic>? ?? const {}).entries)
        if (value != null) key: SelectorValue.fromJson(value),
    },
    selectionNotes: {
      for (final MapEntry(:key, :value)
          in (json['selectionNotes'] as Map<String, dynamic>? ?? const {})
              .entries)
        key: value as String,
    },
    highlights: [
      for (final h in json['highlights'] as List? ?? const [])
        EquipmentHighlight.fromJson(h as Map<String, dynamic>),
    ],
    specs: [
      for (final s in json['specs'] as List? ?? const [])
        EquipmentSpec.fromJson(s as Map<String, dynamic>),
    ],
  );
}
