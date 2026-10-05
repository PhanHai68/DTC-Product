import 'dart:convert';

/// Catalog "Máy đóng gói" (nằm trong module Máy nghiền) — dữ liệu tĩnh đọc
/// từ assets/database/packing_machine_catalog.json, CHỈ gồm thông số có
/// trong catalog nhà cung cấp. Tách khỏi database máy nghiền để công cụ chọn
/// máy, bộ lọc, sao lưu và file Excel nguồn của máy nghiền không bị ảnh
/// hưởng (tiêu chí kg/h, độ mịn không áp dụng cho máy đóng gói).
class PackingCatalog {
  const PackingCatalog({
    required this.catalogVersion,
    required this.series,
    required this.machines,
  });

  final String catalogVersion;
  final List<PackingSeries> series;
  final List<PackingMachine> machines;

  factory PackingCatalog.parse(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    return PackingCatalog(
      catalogVersion: root['catalogVersion'] as String? ?? '',
      series: [
        for (final s in root['series'] as List)
          PackingSeries.fromJson(s as Map<String, dynamic>),
      ],
      machines: [
        for (final m in root['machines'] as List)
          PackingMachine.fromJson(m as Map<String, dynamic>),
      ],
    );
  }
}

/// 1 dòng máy đóng gói. Các khối chữ cùng ý nghĩa với GrindingSeries để
/// trang dòng máy / trang thông số hiển thị y hệt máy nghiền.
class PackingSeries {
  const PackingSeries({
    required this.seriesCode,
    required this.displayCode,
    required this.nameVi,
    this.nameEn = '',
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
  final String pdfPages;
  final String? image;
  final String? imageCaption;
  final String applicationVi;
  final String structureVi;
  final String workingPrincipleVi;
  final String featuresVi;

  /// Ghi chú nội bộ (Remark trong catalog) — không hiển thị cho khách.
  final String notes;

  factory PackingSeries.fromJson(Map<String, dynamic> json) => PackingSeries(
    seriesCode: json['seriesCode'] as String,
    displayCode: json['displayCode'] as String? ?? '',
    nameVi: json['nameVi'] as String? ?? '',
    nameEn: json['nameEn'] as String? ?? '',
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
enum PackingSpecGroup { technical, extra, install }

class PackingSpec {
  const PackingSpec({
    required this.group,
    required this.key,
    required this.label,
    required this.value,
  });

  final PackingSpecGroup group;

  /// Khoá ngữ nghĩa (pack_weight, speed, power_kw...) — quyết định icon/màu
  /// và các ô giá trị trên thẻ model.
  final String key;
  final String label;
  final String value;

  factory PackingSpec.fromJson(Map<String, dynamic> json) => PackingSpec(
    group: PackingSpecGroup.values.byName(json['group'] as String),
    key: json['key'] as String,
    label: json['label'] as String,
    value: json['value'] as String,
  );
}

/// Thẻ chỉ số nổi bật: [title] đã kèm đơn vị, [value] chỉ có số — giống
/// "Công suất (kg/h) / 80 - 300" của máy nghiền.
class PackingHighlight {
  const PackingHighlight({
    required this.kind,
    required this.title,
    required this.value,
  });

  /// speed | weight | power
  final String kind;
  final String title;
  final String value;

  factory PackingHighlight.fromJson(Map<String, dynamic> json) =>
      PackingHighlight(
        kind: json['kind'] as String,
        title: json['title'] as String,
        value: json['value'] as String,
      );
}

/// Dạng nguyên liệu máy đóng gói xử lý được (theo phần mô tả catalog).
enum PackingMaterialForm {
  powder('Bột'),
  granule('Hạt nhỏ'),
  tea('Trà / dược liệu túi lọc');

  const PackingMaterialForm(this.label);
  final String label;
}

/// Loại bao bì thành phẩm.
enum PackingPackaging {
  bag('Túi / gói'),
  bottle('Chai / lon'),
  teabag('Túi lọc trà'),
  bigbag('Bao lớn 5 - 50 kg');

  const PackingPackaging(this.label);
  final String label;
}

enum PackingAutomation {
  auto('Tự động hoàn toàn'),
  semi('Bán tự động');

  const PackingAutomation(this.label);
  final String label;
}

/// Số liệu dùng cho công cụ chọn máy — chỉ suy ra từ catalog. Trường `null`
/// (hoặc danh sách `null`) nghĩa là catalog không nói rõ: bộ chọn máy báo
/// "chưa có dữ liệu", KHÔNG coi là đạt hay không đạt.
class PackingSelectionData {
  const PackingSelectionData({
    this.forms,
    this.weightMinG,
    this.weightMaxG,
    this.speedMin,
    this.speedMax,
    this.speedUnit = 'túi/phút',
    this.powerKw,
    this.packaging,
    this.automation,
  });

  final Set<PackingMaterialForm>? forms;
  final double? weightMinG;
  final double? weightMaxG;
  final double? speedMin;
  final double? speedMax;
  final String speedUnit;
  final double? powerKw;
  final Set<PackingPackaging>? packaging;
  final PackingAutomation? automation;

  factory PackingSelectionData.fromJson(Map<String, dynamic> json) {
    Set<T>? names<T extends Enum>(Object? raw, List<T> values) => raw == null
        ? null
        : {for (final n in raw as List) values.byName(n as String)};
    final automation = json['automation'] as String?;
    return PackingSelectionData(
      forms: names(json['forms'], PackingMaterialForm.values),
      weightMinG: (json['weightMinG'] as num?)?.toDouble(),
      weightMaxG: (json['weightMaxG'] as num?)?.toDouble(),
      speedMin: (json['speedMin'] as num?)?.toDouble(),
      speedMax: (json['speedMax'] as num?)?.toDouble(),
      speedUnit: json['speedUnit'] as String? ?? 'túi/phút',
      powerKw: (json['powerKw'] as num?)?.toDouble(),
      packaging: names(json['packaging'], PackingPackaging.values),
      automation: automation == null
          ? null
          : PackingAutomation.values.byName(automation),
    );
  }
}

class PackingMachine {
  const PackingMachine({
    required this.machineId,
    required this.seriesCode,
    required this.model,
    this.pdfPage,
    this.image,
    this.imageCaption,
    this.needsVerification = false,
    this.verificationNote,
    this.selection = const PackingSelectionData(),
    this.highlights = const [],
    this.specs = const [],
  });

  final String machineId;
  final String seriesCode;
  final String model;
  final int? pdfPage;

  /// Ảnh riêng của model (VD 3 máy trà túi lọc khác nhau) — null thì dùng
  /// ảnh của dòng máy.
  final String? image;
  final String? imageCaption;

  /// Cờ nội bộ: catalog có số liệu lệch nhau, cần xác nhận với nhà cung cấp.
  /// KHÔNG hiển thị cho khách hàng.
  final bool needsVerification;
  final String? verificationNote;

  final PackingSelectionData selection;

  final List<PackingHighlight> highlights;
  final List<PackingSpec> specs;

  List<PackingSpec> specsOf(PackingSpecGroup group) =>
      specs.where((s) => s.group == group).toList();

  String? valueOf(String key) {
    for (final spec in specs) {
      if (spec.key == key) return spec.value;
    }
    return null;
  }

  factory PackingMachine.fromJson(Map<String, dynamic> json) => PackingMachine(
    machineId: json['machineId'] as String,
    seriesCode: json['seriesCode'] as String,
    model: json['model'] as String,
    pdfPage: json['pdfPage'] as int?,
    image: json['image'] as String?,
    imageCaption: json['imageCaption'] as String?,
    needsVerification: json['needsVerification'] as bool? ?? false,
    verificationNote: json['verificationNote'] as String?,
    selection: json['selection'] == null
        ? const PackingSelectionData()
        : PackingSelectionData.fromJson(
            json['selection'] as Map<String, dynamic>,
          ),
    highlights: [
      for (final h in json['highlights'] as List? ?? const [])
        PackingHighlight.fromJson(h as Map<String, dynamic>),
    ],
    specs: [
      for (final s in json['specs'] as List? ?? const [])
        PackingSpec.fromJson(s as Map<String, dynamic>),
    ],
  );
}
