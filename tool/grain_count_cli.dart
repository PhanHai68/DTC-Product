// Giai đoạn 0 — thử thuật toán đếm hạt ngoài app, trên ảnh thật.
//
// Dùng chính module thuật toán của app (lib/features/grain_analysis/engine)
// nên số đếm ở đây và trong app luôn trùng nhau trên cùng một file ảnh.
//
// Cách chạy (trong thư mục DTCproduct):
//
//   dart run tool/grain_count_cli.dart <thư mục ảnh> [tùy chọn]
//
// Tùy chọn:
//   --manual <file.csv>    số đếm tay, mỗi dòng: tên_file,số_hạt
//   --config <file.json>   bộ tham số thử (khóa thiếu thì lấy mặc định)
//   --tray a4|a3|anysort   tấm nền in A4/A3, hoặc khay trắng AnySort 21×15 cm
//                          (mặc định a4)
//   --min-ppm <số>         pixelsPerMm tối thiểu (mặc định theo cấu hình)
//   --out <file.csv>       file kết quả (mặc định <thư mục ảnh>/ket_qua_dem.csv)
//   --overlay <thư mục>    lưu ảnh đánh dấu từng hạt để kiểm tra bằng mắt
//   --write-config <file>  ghi bộ tham số mặc định ra JSON để chỉnh
//   --benchmark            đo thời gian trên ảnh tổng hợp ~12 MP, 1.000 hạt
//
// Tiêu chí nghiệm thu giai đoạn 0: trên các ảnh đạt chất lượng, đếm sai
// không quá 2% so với đếm tay.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dtc_product/features/grain_analysis/engine/grain_analysis_config.dart';
import 'package:dtc_product/features/grain_analysis/engine/grain_analyzer.dart';
import 'package:dtc_product/features/grain_analysis/engine/image_decode.dart';
import 'package:dtc_product/features/grain_analysis/engine/tray_layout.dart';
import 'package:image/image.dart' as img;

import 'grain_analysis/synthetic_tray.dart';

Future<void> main(List<String> args) async {
  final options = _parse(args);
  if (options.containsKey('help') || args.isEmpty) {
    stdout.writeln(_usage);
    return;
  }
  final layout = TrayLayout.byId(options['tray'] as String?);
  var config = const GrainAnalysisConfig();
  if (options['config'] case final String path) {
    config = GrainAnalysisConfig.fromJson(
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>,
    );
  }
  if (options['write-config'] case final String path) {
    File(path).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(config.toJson()),
    );
    stdout.writeln('Đã ghi bộ tham số vào $path');
    return;
  }
  final analyzer = GrainAnalyzer(config: config, layout: layout);
  if (options.containsKey('benchmark')) {
    _benchmark(analyzer);
    return;
  }

  final folder = options['_'] as String?;
  if (folder == null) {
    stdout.writeln(_usage);
    return;
  }
  final dir = Directory(folder);
  if (!dir.existsSync()) {
    stderr.writeln('Không thấy thư mục ${dir.path}');
    exitCode = 2;
    return;
  }
  final manual = <String, int>{};
  if (options['manual'] case final String path) {
    for (final line in File(path).readAsLinesSync()) {
      final parts = line.split(RegExp(r'[,;\t]'));
      if (parts.length < 2) continue;
      final n = int.tryParse(parts[1].trim());
      if (n != null) manual[parts[0].trim().toLowerCase()] = n;
    }
  }
  final minPpm = double.tryParse('${options['min-ppm']}');
  final overlayDir = options['overlay'] == null
      ? null
      : (Directory(options['overlay'] as String)..createSync(recursive: true));

  final files =
      dir
          .listSync()
          .whereType<File>()
          .where(
            (f) => RegExp(
              r'\.(jpe?g|png)$',
              caseSensitive: false,
            ).hasMatch(f.path),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    stderr.writeln('Thư mục không có ảnh .jpg/.png');
    exitCode = 2;
    return;
  }

  final rows = <List<Object?>>[
    [
      'file',
      'so_hat_app',
      'so_hat_tay',
      'sai_so_%',
      'dat_chat_luong',
      'loi_anh',
      'co_moc',
      'pixels_per_mm',
      'goc_nghieng',
      'do_net',
      'chenh_sang_nen',
      'chay_sang',
      'ty_le_cum',
      'so_cum',
      'cham_mep',
      'bui',
      'vung_bat_thuong',
      'thoi_gian_ms',
    ],
  ];
  final errors = <double>[];
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final raster = decodeImageToRaster(file.readAsBytesSync());
    final r = analyzer.analyze(raster, minPixelsPerMm: minPpm);
    final expected = manual[name.toLowerCase()];
    final errorPct = expected == null || expected == 0
        ? null
        : 100 * (r.totalCount - expected) / expected;
    final good = r.issues.isEmpty;
    if (good && errorPct != null) errors.add(errorPct.abs());
    rows.add([
      name,
      r.totalCount,
      expected,
      errorPct?.toStringAsFixed(2),
      good ? 'co' : 'khong',
      r.issues.map((i) => i.name).join('|'),
      r.markersFound ? 'co' : 'khong',
      r.metrics['pixelsPerMm']?.toStringAsFixed(2),
      r.tiltDegrees?.toStringAsFixed(1),
      r.metrics['laplacianVariance']?.toStringAsFixed(1),
      r.metrics['backgroundUnevenness']?.toStringAsFixed(3),
      r.metrics['highlightFraction']?.toStringAsFixed(4),
      r.clusterAreaFraction.toStringAsFixed(3),
      r.grains.where((g) => g.isCluster).length,
      r.edgeCutCount,
      r.dustCount,
      r.ignoredRegionCount,
      r.elapsedMs,
    ]);
    stdout.writeln(
      '$name: ${r.totalCount} hạt'
      '${expected == null ? '' : ' (tay: $expected, sai ${errorPct!.toStringAsFixed(2)}%)'}'
      '${good ? '' : ' — ảnh chưa đạt: ${r.issues.map((i) => i.label).join(', ')}'}'
      ' [${r.elapsedMs} ms]',
    );
    if (overlayDir != null) {
      _writeOverlay(file, r, '${overlayDir.path}/${_stem(name)}_danh_dau.jpg');
    }
  }

  final out = File(
    (options['out'] as String?) ?? '${dir.path}/ket_qua_dem.csv',
  );
  out.writeAsStringSync(
    '﻿${rows.map((r) => r.map((v) => v ?? '').join(',')).join('\n')}\n',
  );
  stdout.writeln('\nĐã ghi ${out.path}');
  if (errors.isNotEmpty) {
    final mean = errors.reduce((a, b) => a + b) / errors.length;
    final worst = errors.reduce(math.max);
    final within = errors.where((e) => e <= 2).length;
    stdout.writeln(
      'Ảnh đạt chất lượng có số đếm tay: ${errors.length}. '
      'Sai số trung bình ${mean.toStringAsFixed(2)}%, lớn nhất '
      '${worst.toStringAsFixed(2)}%. Đạt ≤ 2%: $within/${errors.length}.',
    );
  }
}

/// Vẽ viền từng hạt lên ảnh gốc: xanh lá = hạt đơn, đỏ = cụm ước lượng.
void _writeOverlay(File source, GrainImageAnalysis r, String path) {
  final image = img.bakeOrientation(img.decodeImage(source.readAsBytesSync())!);
  final thickness = math.max(1, image.width ~/ 1500);
  // Khung vùng phân tích (xanh dương) và vùng bỏ qua như logo khay (cam).
  void drawRect(double l, double t, double rr, double b, img.Color color) {
    final corners = [
      [l, t],
      [rr, t],
      [rr, b],
      [l, b],
    ];
    for (var i = 0; i < 4; i++) {
      final a = r.frameToImage.apply(corners[i][0], corners[i][1]);
      final c = r.frameToImage.apply(
        corners[(i + 1) % 4][0],
        corners[(i + 1) % 4][1],
      );
      img.drawLine(
        image,
        x1: a[0].round(),
        y1: a[1].round(),
        x2: c[0].round(),
        y2: c[1].round(),
        color: color,
        thickness: thickness * 2,
      );
    }
  }

  drawRect(
    0,
    0,
    r.frameWidth.toDouble(),
    r.frameHeight.toDouble(),
    img.ColorRgb8(30, 120, 255),
  );
  for (final e in r.excludedRegions) {
    drawRect(
      e.left.toDouble(),
      e.top.toDouble(),
      e.right.toDouble(),
      e.bottom.toDouble(),
      img.ColorRgb8(255, 150, 0),
    );
  }
  for (final g in r.grains) {
    final color = g.isCluster
        ? img.ColorRgb8(255, 40, 40)
        : img.ColorRgb8(40, 230, 90);
    final c = g.contour;
    for (var i = 0; i < c.length; i += 2) {
      final j = (i + 2) % c.length;
      final a = r.frameToImage.apply(c[i], c[i + 1]);
      final b = r.frameToImage.apply(c[j], c[j + 1]);
      img.drawLine(
        image,
        x1: a[0].round(),
        y1: a[1].round(),
        x2: b[0].round(),
        y2: b[1].round(),
        color: color,
        thickness: thickness,
      );
    }
    if (g.isCluster) {
      final p = r.frameToImage.apply(g.centroidX, g.centroidY);
      img.drawString(
        image,
        '${g.estimatedCount}',
        font: img.arial24,
        x: p[0].round() - 6,
        y: p[1].round() - 12,
        color: img.ColorRgb8(255, 255, 0),
      );
    }
  }
  File(path).writeAsBytesSync(img.encodeJpg(image, quality: 85));
}

/// Ảnh tổng hợp cỡ ảnh điện thoại 12 MP: khay A4 ở 13,5 px/mm, ~1.000 hạt.
void _benchmark(GrainAnalyzer analyzer) {
  const layout = TrayLayout.a4;
  final rnd = math.Random(42);
  final roi = layout.roiRect.inflate(-3);
  final grains = <SynthGrain>[];
  const cellW = 5.2, cellH = 7.4;
  for (var y = roi.top + cellH / 2; y < roi.bottom - cellH / 2; y += cellH) {
    for (var x = roi.left + cellW / 2; x < roi.right - cellW / 2; x += cellW) {
      grains.add(
        SynthGrain(
          x + (rnd.nextDouble() - 0.5) * 0.6,
          y + (rnd.nextDouble() - 0.5) * 0.6,
          6.3 + rnd.nextDouble() * 0.6,
          2.0 + rnd.nextDouble() * 0.3,
          math.pi / 2 + (rnd.nextDouble() - 0.5) * 0.5,
        ),
      );
    }
  }
  stdout.writeln('Tạo ảnh tổng hợp ${grains.length} hạt...');
  final image = renderTray(layout: layout, grains: grains, ppm: 13.5);
  final bytes = img.encodeJpg(image, quality: 92);
  stdout.writeln(
    'Ảnh ${image.width} × ${image.height} '
    '(${(image.width * image.height / 1e6).toStringAsFixed(1)} MP)',
  );
  final watch = Stopwatch()..start();
  final raster = decodeImageToRaster(bytes);
  final decodeMs = watch.elapsedMilliseconds;
  final r = analyzer.analyze(raster);
  stdout.writeln(
    'Giải mã JPEG: $decodeMs ms; phân tích: ${r.elapsedMs} ms; '
    'đếm được ${r.totalCount}/${grains.length} hạt; '
    'lỗi ảnh: ${r.issues.map((i) => i.name).join(', ')}',
  );
}

String _stem(String name) => name.replaceFirst(RegExp(r'\.[^.]+$'), '');

Map<String, Object?> _parse(List<String> args) {
  final out = <String, Object?>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--help' || a == '-h') {
      out['help'] = true;
    } else if (a == '--benchmark') {
      out['benchmark'] = true;
    } else if (a.startsWith('--') && i + 1 < args.length) {
      out[a.substring(2)] = args[++i];
    } else {
      out['_'] = a;
    }
  }
  return out;
}

const _usage = '''
Đếm hạt trên thư mục ảnh (giai đoạn 0).

  dart run tool/grain_count_cli.dart <thư mục ảnh> [--manual dem_tay.csv]
      [--config tham_so.json] [--tray a4|a3|anysort] [--min-ppm 10]
      [--out ket_qua.csv] [--overlay thu_muc_anh_danh_dau]
  dart run tool/grain_count_cli.dart --write-config tham_so.json
  dart run tool/grain_count_cli.dart --benchmark
''';
