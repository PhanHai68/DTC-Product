import 'dart:math' as math;

import '../models/pipe_survey.dart';

/// Quy tắc + tên / mã vật tư khảo sát — `air_compressor/pipe_survey_constants.json`.
class SurveyConstants {
  const SurveyConstants({
    required this.barLengthM,
    required this.reservePercent,
    required this.defaultConnectionHeightM,
    required this.defaultDn,
    required this.sizes,
    required this.outerDiameter,
    required this.clampSpacingM,
    required this.tapeJointsPerRoll,
    required this.materials,
  });

  factory SurveyConstants.fromJson(Map<String, dynamic> j) {
    List<(int, double)> steps(String key) => [
      for (final e in j[key] as List)
        ((e as List)[0] as int, (e[1] as num).toDouble()),
    ];
    return SurveyConstants(
      barLengthM: (j['barLengthM'] as num).toDouble(),
      reservePercent: (j['reservePercent'] as num).toDouble(),
      defaultConnectionHeightM: (j['defaultConnectionHeightM'] as num)
          .toDouble(),
      defaultDn: j['defaultDn'] as int,
      sizes: [for (final s in j['sizes'] as List) s as int],
      outerDiameter: {
        for (final e in (j['outerDiameter'] as Map<String, dynamic>).entries)
          int.parse(e.key): e.value as int,
      },
      clampSpacingM: steps('clampSpacingM'),
      tapeJointsPerRoll: steps('tapeJointsPerRoll'),
      materials: {
        for (final m in j['materials'] as List)
          SurveyRole.values.byName((m as Map)['role'] as String):
              SurveyMaterial.fromJson(m.cast<String, dynamic>()),
      },
    );
  }

  /// Chiều dài một cây ống (m).
  final double barLengthM;

  /// Dự phòng phụ kiện (%), làm tròn lên; ống và van không cộng.
  final double reservePercent;

  /// Cao độ đầu nối ở máy mặc định (m).
  final double defaultConnectionHeightM;
  final int defaultDn;

  /// Các cỡ ống chọn được (DN).
  final List<int> sizes;

  /// DN → đường kính ngoài ống kẽm (mm), cách gọi trong file PO.
  final Map<int, int> outerDiameter;

  /// (DN tối đa, khoảng cách cùm m), DN tăng dần.
  final List<(int, double)> clampSpacingM;

  /// (DN tối đa, số mối ren mỗi cuộn băng keo non), DN tăng dần.
  final List<(int, double)> tapeJointsPerRoll;
  final Map<SurveyRole, SurveyMaterial> materials;

  int od(int dn) => outerDiameter[dn] ?? dn;

  double clampSpacingFor(int dn) =>
      clampSpacingM.firstWhere((e) => dn <= e.$1).$2;

  double tapeJointsFor(int dn) =>
      tapeJointsPerRoll.firstWhere((e) => dn <= e.$1).$2;
}

/// Loại vật tư bóc từ sơ đồ (thứ tự = thứ tự trong bảng vật tư).
enum SurveyRole {
  pipe,
  coupling,
  elbow,
  tee,
  reducer,
  ballValve,
  cap,
  clamp,
  tape,
}

/// Tên, mã, quy cách của một loại vật tư theo cỡ ống (khóa "50", "50x40");
/// cỡ không có trong dữ liệu dùng [generic] (thay {dn}, {od}, {dn2}, {od2}).
class SurveyMaterial {
  const SurveyMaterial({
    required this.unit,
    required this.generic,
    required this.sizes,
  });

  factory SurveyMaterial.fromJson(Map<String, dynamic> j) {
    Map<String, String?> variant(Map v) => {
      'code': v['code'] as String?,
      'name': v['name'] as String,
      'spec': v['spec'] as String?,
    };
    return SurveyMaterial(
      unit: j['unit'] as String,
      generic: variant(j['generic'] as Map),
      sizes: {
        for (final e in (j['sizes'] as Map).entries)
          e.key as String: variant(e.value as Map),
      },
    );
  }

  final String unit;
  final Map<String, String?> generic;
  final Map<String, Map<String, String?>> sizes;
}

/// Một dòng vật tư bóc được: [key] cố định (loại + cỡ) để gắn phần sửa tay.
class SurveyBomLine {
  const SurveyBomLine({
    required this.key,
    required this.role,
    required this.name,
    required this.unit,
    required this.qty,
    this.code,
    this.spec,
  });
  final String key;
  final SurveyRole role;
  final String? code;
  final String name;
  final String unit;
  final num qty;
  final String? spec;
}

/// Một đoạn trong bảng đoạn ống (đoạn ngang hoặc ống đứng xuống máy).
class SurveyRun {
  const SurveyRun({
    required this.label,
    required this.dn,
    required this.lengthM,
    this.measured = false,
    this.drop = false,
  });
  final String label;
  final int dn;
  final double lengthM;

  /// Chiều dài đo thực tế (không phải theo hình vẽ).
  final bool measured;

  /// Ống đứng xuống máy tại điểm sử dụng.
  final bool drop;
}

enum SurveyWarningCode {
  /// Chưa nhập độ cao treo ống: chưa tính ống đứng xuống máy.
  noHangHeight,

  /// Chưa có đoạn ống nào.
  empty,

  /// Điểm sử dụng không nối vào ống.
  isolatedPoint,

  /// Độ cao treo thấp hơn cao độ đầu nối (params: name).
  hangBelowConnection,
}

class SurveyWarning {
  const SurveyWarning(this.code, [this.params = const {}]);
  final SurveyWarningCode code;
  final Map<String, Object?> params;
}

class SurveyBom {
  const SurveyBom({
    required this.lines,
    required this.runs,
    required this.lengthByDn,
    required this.warnings,
  });

  final List<SurveyBomLine> lines;

  /// Bảng đoạn ống (ngang + ống đứng).
  final List<SurveyRun> runs;

  /// Tổng chiều dài ống (m, chưa làm tròn cây) theo DN.
  final Map<int, double> lengthByDn;
  final List<SurveyWarning> warnings;

  double get totalLengthM => lengthByDn.values.fold(0.0, (a, b) => a + b);
}

/// Bóc vật tư từ sơ đồ khảo sát. Hàm thuần.
///
/// - Ống: tổng chiều dài từng cỡ (đoạn ngang + ống đứng xuống máy = độ cao
///   treo − cao độ đầu nối), làm tròn lên nguyên cây.
/// - Co: mỗi góc rẽ 1 cái, mỗi ống đứng 1 cái ở đầu trên.
/// - Tê: chỗ 3 nhánh 1 cái, chỗ 4 nhánh 2 cái, mỗi điểm sử dụng nằm giữa
///   tuyến thêm 1 cái lấy khí.
/// - Côn giảm: mỗi đoạn nhỏ hơn cỡ lớn nhất tại điểm nối.
/// - Nối ren 2 đầu kép: mối nối giữa các cây trên từng đoạn.
/// - Van bi: 1 cái mỗi điểm sử dụng. Nút bịt: mỗi đầu ống cụt.
/// - Cùm U: theo khoảng cách treo của từng cỡ. Băng keo non: theo số mối ren.
/// - Phụ kiện cộng dự phòng [SurveyConstants.reservePercent] %, làm tròn lên.
SurveyBom computeSurveyBom(PipeSurvey s, SurveyConstants c) {
  final warnings = <SurveyWarning>[];
  final runs = <SurveyRun>[];
  final length = <int, double>{};
  final count = <(SurveyRole, int, int?), int>{};
  final joints = <int, int>{};
  void add(SurveyRole role, int dn, int n, {int? dn2}) {
    if (n <= 0) return;
    count.update((role, dn, dn2), (v) => v + n, ifAbsent: () => n);
  }

  void addJoints(int dn, int n) =>
      joints.update(dn, (v) => v + n, ifAbsent: () => n);
  int couplingsFor(double len) =>
      math.max(0, (len / c.barLengthM - 1e-9).ceil() - 1);
  int clampsFor(double len, int dn) =>
      math.max(1, (len / c.clampSpacingFor(dn) - 1e-9).ceil());

  if (s.segments.isEmpty) {
    warnings.add(const SurveyWarning(SurveyWarningCode.empty));
  }

  // Đoạn ngang.
  for (final seg in s.segments) {
    final a = s.node(seg.a);
    final b = s.node(seg.b);
    if (a == null || b == null) continue;
    final dn = seg.dn ?? s.defaultDn;
    final len = seg.measuredM ?? surveySegmentDrawnLength(a, b);
    if (len <= 0) continue;
    runs.add(
      SurveyRun(
        label: '${_nodeLabel(s, a)} → ${_nodeLabel(s, b)}',
        dn: dn,
        lengthM: len,
        measured: seg.measuredM != null,
      ),
    );
    length.update(dn, (v) => v + len, ifAbsent: () => len);
    final cpl = couplingsFor(len);
    add(SurveyRole.coupling, dn, cpl);
    addJoints(dn, 2 * cpl);
    add(SurveyRole.clamp, dn, clampsFor(len, dn));
  }

  // Phụ kiện tại từng điểm.
  for (final node in s.nodes) {
    final segs = s.segmentsAt(node.id);
    final d = segs.length;
    final dns = [for (final seg in segs) seg.dn ?? s.defaultDn];
    final maxDn = dns.isEmpty ? s.defaultDn : dns.reduce(math.max);
    if (d == 2 && !_collinear(s, node, segs[0], segs[1])) {
      add(SurveyRole.elbow, maxDn, 1);
      addJoints(maxDn, 2);
    } else if (d == 3) {
      add(SurveyRole.tee, maxDn, 1);
      addJoints(maxDn, 3);
    } else if (d >= 4) {
      add(SurveyRole.tee, maxDn, d - 2);
      addJoints(maxDn, 3 * (d - 2));
    }
    // Côn giảm cho đoạn nhỏ hơn cỡ lớn nhất tại điểm.
    for (final dn in dns) {
      if (dn < maxDn) {
        add(SurveyRole.reducer, maxDn, 1, dn2: dn);
        addJoints(maxDn, 2);
      }
    }
    if (node.kind == SurveyNodeKind.usePoint) {
      if (d == 0) {
        warnings.add(
          SurveyWarning(SurveyWarningCode.isolatedPoint, {
            'name': _nodeLabel(s, node),
          }),
        );
      }
      // Điểm giữa tuyến: thêm tê lấy khí.
      if (d >= 2) {
        add(SurveyRole.tee, maxDn, 1);
        addJoints(maxDn, 3);
      }
      final dropDn =
          node.dropDn ?? (dns.isEmpty ? s.defaultDn : dns.reduce(math.min));
      add(SurveyRole.ballValve, dropDn, 1);
      addJoints(dropDn, 2);
      final hang = node.hangHeightM ?? s.hangHeightM;
      final conn = node.connectionHeightM ?? c.defaultConnectionHeightM;
      if (hang == null) continue;
      final drop = hang - conn;
      if (drop <= 0) {
        warnings.add(
          SurveyWarning(SurveyWarningCode.hangBelowConnection, {
            'name': _nodeLabel(s, node),
          }),
        );
        continue;
      }
      runs.add(
        SurveyRun(
          label: '${_nodeLabel(s, node)} (ống đứng)',
          dn: dropDn,
          lengthM: drop,
          drop: true,
        ),
      );
      length.update(dropDn, (v) => v + drop, ifAbsent: () => drop);
      add(SurveyRole.elbow, dropDn, 1);
      addJoints(dropDn, 2);
      final cpl = couplingsFor(drop);
      add(SurveyRole.coupling, dropDn, cpl);
      addJoints(dropDn, 2 * cpl);
      add(SurveyRole.clamp, dropDn, clampsFor(drop, dropDn));
    } else if (d == 1 && node.kind == SurveyNodeKind.junction) {
      // Đầu ống cụt.
      add(SurveyRole.cap, maxDn, 1);
      addJoints(maxDn, 1);
    }
  }
  if (s.hangHeightM == null && s.usePoints.any((n) => n.hangHeightM == null)) {
    warnings.add(const SurveyWarning(SurveyWarningCode.noHangHeight));
  }

  // Băng keo non theo số mối ren từng cỡ.
  final tapeRolls = joints.entries.fold(
    0,
    (sum, e) => sum + (e.value / c.tapeJointsFor(e.key) - 1e-9).ceil(),
  );

  int reserve(int n) => (n * (1 + c.reservePercent / 100) - 1e-9).ceil();
  final lines = <SurveyBomLine>[
    for (final dn in length.keys.toList()..sort((a, b) => b - a))
      _line(
        c,
        SurveyRole.pipe,
        dn,
        null,
        ((length[dn]! / c.barLengthM - 1e-9).ceil() * c.barLengthM).round(),
      ),
    for (final e
        in count.entries.toList()..sort((x, y) {
          final r = x.key.$1.index - y.key.$1.index;
          return r != 0 ? r : y.key.$2 - x.key.$2;
        }))
      _line(
        c,
        e.key.$1,
        e.key.$2,
        e.key.$3,
        e.key.$1 == SurveyRole.ballValve ? e.value : reserve(e.value),
      ),
    if (tapeRolls > 0) _line(c, SurveyRole.tape, 0, null, reserve(tapeRolls)),
  ];
  return SurveyBom(
    lines: lines,
    runs: runs,
    lengthByDn: length,
    warnings: warnings,
  );
}

SurveyBomLine _line(
  SurveyConstants c,
  SurveyRole role,
  int dn,
  int? dn2,
  num qty,
) {
  final m = c.materials[role]!;
  final key = dn2 == null ? '$dn' : '${dn}x$dn2';
  final v = m.sizes[key] ?? m.generic;
  String fill(String? t) => (t ?? '')
      .replaceAll('{dn2}', '${dn2 ?? ''}')
      .replaceAll('{od2}', dn2 == null ? '' : '${c.od(dn2)}')
      .replaceAll('{dn}', '$dn')
      .replaceAll('{od}', '${c.od(dn)}');
  final spec = fill(v['spec']);
  return SurveyBomLine(
    key: '${role.name}${role == SurveyRole.tape ? '' : key}',
    role: role,
    code: v['code'],
    name: fill(v['name']),
    unit: m.unit,
    qty: qty,
    spec: spec.isEmpty ? null : spec,
  );
}

/// Chiều dài đoạn theo hình vẽ (m).
double surveySegmentDrawnLength(SurveyNode a, SurveyNode b) =>
    math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

/// Hai đoạn qua [node] thẳng hàng (không phải góc rẽ).
bool _collinear(
  PipeSurvey s,
  SurveyNode node,
  SurveySegment p,
  SurveySegment q,
) {
  final a = s.node(p.other(node.id));
  final b = s.node(q.other(node.id));
  if (a == null || b == null) return true;
  final ax = a.x - node.x, ay = a.y - node.y;
  final bx = b.x - node.x, by = b.y - node.y;
  final cross = ax * by - ay * bx;
  return cross.abs() < 1e-6 && ax * bx + ay * by < 0;
}

String _nodeLabel(PipeSurvey s, SurveyNode n) {
  if (n.name.trim().isNotEmpty) return n.name.trim();
  return switch (n.kind) {
    SurveyNodeKind.compressor => 'Cụm máy',
    SurveyNodeKind.usePoint => 'Điểm sử dụng',
    SurveyNodeKind.junction => 'Điểm ${s.nodes.indexOf(n) + 1}',
  };
}
