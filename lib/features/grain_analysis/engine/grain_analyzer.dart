import 'dart:math' as math;
import 'dart:typed_data';

import '../models/grain.dart';
import 'background_model.dart';
import 'binary_ops.dart';
import 'cluster_splitter.dart';
import 'geometry.dart';
import 'grain_analysis_config.dart';
import 'homography.dart';
import 'image_quality.dart';
import 'lab_color.dart';
import 'marker_detector.dart';
import 'raster.dart';
import 'rectifier.dart';
import 'tray_layout.dart';
import 'tray_outline_detector.dart';

typedef AnalysisProgress = void Function(double fraction, String stage);

/// Kết quả xử lý một ảnh qua bước 1-5 (mục 7): nắn ảnh, tách nền, tách
/// hạt chạm nhau, ước cụm, lọc và đo.
class GrainImageAnalysis {
  const GrainImageAnalysis({
    required this.imageWidth,
    required this.imageHeight,
    required this.frameWidth,
    required this.frameHeight,
    required this.frameToImage,
    required this.pixelsPerMm,
    required this.markersFound,
    required this.tiltDegrees,
    required this.issues,
    required this.metrics,
    required this.grains,
    required this.medianAreaPx,
    required this.edgeCutCount,
    required this.dustCount,
    required this.ignoredRegionCount,
    required this.clusterAreaFraction,
    required this.algorithmVersion,
    required this.elapsedMs,
    this.excludedRegions = const [],
    this.trayId = '',
  });

  /// Kích thước ảnh gốc (đã xoay theo EXIF).
  final int imageWidth;
  final int imageHeight;

  /// Kích thước khung đã nắn — hệ tọa độ của [grains].
  final int frameWidth;
  final int frameHeight;

  /// Đổi tọa độ khung đã nắn → ảnh gốc (để vẽ lên ảnh gốc).
  final Homography frameToImage;

  /// Null khi không thấy mốc khay: không có số đo mm (FR-02).
  final double? pixelsPerMm;
  final bool markersFound;
  final double? tiltDegrees;
  final List<QualityIssue> issues;

  /// Số đo thô của từng phép kiểm tra — để chỉnh ngưỡng ở giai đoạn 0.
  final Map<String, double> metrics;
  final List<Grain> grains;
  final double medianAreaPx;

  /// Vật thể chạm mép vùng phân tích — bị loại, không được đếm.
  final int edgeCutCount;
  final int dustCount;

  /// Vùng quá lớn so với một hạt (bóng đổ, mép giấy...) — không tính.
  final int ignoredRegionCount;
  final double clusterAreaFraction;
  final String algorithmVersion;
  final int elapsedMs;

  /// Vùng không phân tích (logo khay), pixel theo khung đã nắn.
  final List<PixelRect> excludedRegions;

  /// Loại khay đã dùng để phân tích ([TrayLayout.id]).
  final String trayId;

  int get totalCount =>
      grains.fold(0, (sum, grain) => sum + grain.countedGrains);
}

class GrainAnalyzer {
  const GrainAnalyzer({
    this.config = const GrainAnalysisConfig(),
    this.layout = TrayLayout.a4,
  });

  final GrainAnalysisConfig config;
  final TrayLayout layout;

  /// Xử lý ảnh [image] (độ phân giải gốc, không thu nhỏ trước khi tách hạt).
  /// [minPixelsPerMm] lấy theo hồ sơ nguyên liệu; null thì dùng mặc định.
  GrainImageAnalysis analyze(
    RgbRaster image, {
    int imageIndex = 0,
    double? minPixelsPerMm,
    AnalysisProgress? onProgress,
  }) {
    final watch = Stopwatch()..start();
    final metrics = <String, double>{};
    final issues = <QualityIssue>[];
    void progress(double f, String stage) => onProgress?.call(f, stage);

    // ---------------------------------------------- Bước 1: nắn ảnh
    progress(0.02, layout.hasMarkers ? 'Tìm mốc góc khay' : 'Tìm viền khay');
    final pose = layout.hasMarkers
        ? _locateByMarkers(image)
        : _locateByOutline(image, metrics);
    RgbRaster frame;
    Homography frameToImage;
    double? ppm;
    double? tilt;
    List<double>? gains;
    var excluded = const <PixelRect>[];
    if (pose != null) {
      final mmToImage = pose.mmToImage;
      final naturalPpm = pose.naturalPpm;
      metrics['pixelsPerMm'] = naturalPpm;
      ppm = math.min(naturalPpm, config.maxPixelsPerMm);
      tilt = mmToImage.tiltDegrees(
        focalPx: config.focalLengthFactor * math.max(image.width, image.height),
        centerX: image.width / 2,
        centerY: image.height / 2,
      );
      metrics['tiltDegrees'] = tilt;
      if (tilt > config.maxTiltDegrees) issues.add(QualityIssue.tilt);
      final minPpm = minPixelsPerMm ?? config.defaultMinPixelsPerMm;
      if (naturalPpm < minPpm) issues.add(QualityIssue.resolution);

      final roi = layout.roiRect;
      frameToImage = mmToImage.compose(
        Homography.scaleTranslate(1 / ppm, roi.left, roi.top),
      );
      gains = whiteBalanceGains(
        image,
        pose.whiteToImage,
        layout.whitePatchRect,
      );
      excluded = [
        for (final r in pose.excluded.map(
          (r) => r.inflate(config.excludedMarginMm),
        ))
          PixelRect(
            ((r.left - roi.left) * ppm).floor(),
            ((r.top - roi.top) * ppm).floor(),
            ((r.right - roi.left) * ppm).ceil(),
            ((r.bottom - roi.top) * ppm).ceil(),
          ),
      ];
      progress(0.08, 'Nắn phối cảnh');
      frame = warpPerspective(
        image,
        frameToImage,
        (roi.width * ppm).round(),
        (roi.height * ppm).round(),
      );
    } else {
      issues.add(QualityIssue.markers);
      final border =
          (config.noMarkerBorderFraction * math.min(image.width, image.height))
              .round();
      frame = image.crop(
        border,
        border,
        image.width - 2 * border,
        image.height - 2 * border,
      );
      frameToImage = Homography.scaleTranslate(
        1,
        border.toDouble(),
        border.toDouble(),
      );
    }

    // ------------------------------- Mục 9: kiểm tra nhanh trên ảnh thu nhỏ
    progress(0.2, 'Kiểm tra chất lượng ảnh');
    final small = frame.downscaleTo(config.qualityMaxEdge);
    final highlights = highlightFraction(small, config.highlightLevel);
    metrics['highlightFraction'] = highlights;
    if (gains != null) {
      applyGains(frame, gains);
      if (!identical(small, frame)) applyGains(small, gains);
      metrics['whiteBalanceApplied'] = 1;
    }
    final sharpness = laplacianVariance(
      small.toGray(),
      small.width,
      small.height,
    );
    metrics['laplacianVariance'] = sharpness;
    if (sharpness < config.minLaplacianVariance) issues.add(QualityIssue.blur);

    // Có mốc: màu nền lấy từ dải viền vùng rải mẫu (mục 7, bước 2).
    // Không mốc: không biết viền khay ở đâu nên lấy màu chiếm nhiều nhất.
    final w = frame.width, h = frame.height;
    // Tỉ lệ dùng để quy tham số mm ra pixel. Không có mốc thì ước theo cỡ
    // ảnh — để kết quả không phụ thuộc độ phân giải máy (không báo ra ngoài).
    final scalePpm = ppm ?? math.max(w, h) / config.assumedFrameLongEdgeMm;
    final smallScale = small.width / w;
    final reference = ppm != null
        ? estimateBackgroundLab(
            small,
            (config.backgroundBandMm * ppm * smallScale).round(),
          )
        : estimateDominantLab(small);
    metrics['backgroundL'] = reference[0];
    final background = BackgroundModel.estimate(
      small,
      cellPx: math.max(8, config.backgroundCellMm * scalePpm * smallScale),
      reference: reference,
      maxDeviation: config.backgroundMaxDeviationDeltaE,
      minSupport: config.backgroundMinSupport,
    );
    // Khay trắng thật: dùng bộ tham số khay sáng (xem
    // [GrainAnalysisConfig.lightTrayLightnessWeight]).
    final lightTray = pose?.lightFloor ?? false;
    // Khay tối có vân (khay đen): hạt sáng hơn hẳn nền, nhưng chỗ loáng đèn
    // vệt vân sáng gần bằng hạt — hạ trần ngưỡng để bắt hạt ở chỗ loáng, rồi
    // xóa vệt vân mảnh bằng phép mở bán kính lớn hơn.
    final darkTray = pose != null && !layout.hasMarkers && !lightTray;
    final unevenness = background.unevenness();
    metrics['backgroundUnevenness'] = unevenness;
    final maxUnevenness = darkTray
        ? config.darkTrayMaxBackgroundUnevenness
        : config.maxBackgroundUnevenness;
    if (unevenness > maxUnevenness ||
        highlights > config.maxHighlightFraction) {
      issues.add(QualityIssue.lighting);
    }

    // ------------------------------------------------ Bước 2: tách nền
    progress(0.3, 'Tách nền');
    final distance = _distanceToBackground(
      frame,
      background,
      small.width.toDouble(),
      small.height.toDouble(),
      lightTray ? config.lightTrayLightnessWeight : config.lightnessWeight,
    );
    final threshold = _foregroundThreshold(
      distance,
      lightTray
          ? config.lightTrayMinForegroundDeltaE
          : config.minForegroundDeltaE,
      darkTray
          ? config.darkTrayMaxForegroundDeltaE
          : config.maxForegroundDeltaE,
    );
    metrics['foregroundDeltaE'] = threshold / 2;
    var mask = Uint8List(distance.length);
    for (var i = 0; i < mask.length; i++) {
      if (distance[i] > threshold) mask[i] = 1;
    }
    final openR = math.max(
      1,
      ((darkTray ? config.darkTrayOpenRadiusMm : config.openRadiusMm) *
              scalePpm)
          .round(),
    );
    final closeR = math.max(1, (config.closeRadiusMm * scalePpm).round());
    mask = morphOpen(mask, w, h, openR);
    mask = morphClose(mask, w, h, closeR);

    progress(0.45, 'Tách từng hạt');
    final components = labelComponents(mask, w, h);
    mask = Uint8List(0); // giải phóng bộ nhớ

    // ------------------------- Bước 5 (lọc): bỏ nhiễu, vật thể chạm mép
    final minArea = math.max(
      config.minObjectAreaPx.toDouble(),
      config.minObjectAreaMm2 * scalePpm * scalePpm,
    );
    final candidates = <ComponentStats>[];
    var edgeCut = 0;
    final edgeAreas = <ComponentStats>[];
    for (final s in components.stats) {
      if (s.area < minArea) continue;
      // Vùng không phân tích (logo khay) cũng là mép: logo và hạt nằm đè
      // lên logo đều không tính.
      final touchesEdge =
          s.minX == 0 ||
          s.minY == 0 ||
          s.maxX == w - 1 ||
          s.maxY == h - 1 ||
          _touchesExcluded(s, components.labels, w, excluded);
      if (touchesEdge) {
        edgeAreas.add(s);
      } else {
        candidates.add(s);
      }
    }
    // Cỡ một hạt: trung vị theo diện tích (nửa tổng diện tích nằm ở vật thể
    // nhỏ hơn mức này) — hàng trăm đốm nhiễu nhỏ không kéo lệch được như
    // trung vị đếm theo số vật thể.
    final rough = _areaWeightedMedian([for (final s in candidates) s.area]);
    final typical = [
      for (final s in candidates)
        if (s.area >= 0.3 * rough && s.area <= config.clusterAreaFactor * rough)
          s.area.toDouble(),
    ];
    final medianArea = typical.isEmpty ? rough : median(typical);
    final dustLimit =
        (darkTray ? config.darkTrayDustAreaFraction : config.dustAreaFraction) *
        medianArea;
    for (final s in edgeAreas) {
      if (s.area >= dustLimit) edgeCut++;
    }

    // --------------------------- Bước 3-5: tách cụm, ước cụm, đo từng hạt
    final grains = <Grain>[];
    var dust = 0;
    var ignored = 0;
    var clusterArea = 0.0, totalArea = 0.0;
    final lut = LabLut.instance;
    for (var c = 0; c < candidates.length; c++) {
      final s = candidates[c];
      if (c % 50 == 0) {
        progress(0.5 + 0.48 * c / candidates.length, 'Đo từng hạt');
      }
      if (s.area < dustLimit) {
        dust++;
        continue;
      }
      // Vùng quá lớn so với một hạt: bóng đổ, mép giấy, vết bẩn — không
      // đoán thành hàng trăm hạt.
      if (s.area > config.maxClusterGrains * medianArea) {
        ignored++;
        continue;
      }
      final bw = s.bboxWidth + 2, bh = s.bboxHeight + 2;
      final ox = s.minX - 1, oy = s.minY - 1;
      final local = Uint8List(bw * bh);
      var contrast = 0;
      for (var y = 0; y < s.bboxHeight; y++) {
        final row = (s.minY + y) * w + s.minX;
        for (var x = 0; x < s.bboxWidth; x++) {
          if (components.labels[row + x] == s.label) {
            local[(y + 1) * bw + x + 1] = 1;
            contrast += distance[row + x];
          }
        }
      }
      // Hạt thật khác nền rõ rệt; vân giấy, bóng mờ chỉ vừa chớm ngưỡng.
      if (contrast / s.area < config.minContrastRatio * threshold) {
        dust++;
        continue;
      }
      // Lấp lỗ trong hạt (chấm sẫm gần màu nền). Làm riêng từng hạt: lấp
      // trên cả ảnh sẽ lấp luôn vùng nền bị mép giấy bao quanh.
      fillHoles(local, bw, bh);
      final regions = s.area > config.clusterAreaFactor * medianArea
          ? splitCluster(local, bw, bh, medianArea, config)
          : [local];
      for (final region in regions) {
        final grain = _measure(
          region,
          bw,
          bh,
          ox,
          oy,
          frame,
          lut,
          ppm,
          medianArea,
          'i$imageIndex-${grains.length + 1}',
          imageIndex,
        );
        if (grain == null) continue;
        // Khay tối có vân: mảng vân sót lại ở chỗ loáng đèn thường méo mó,
        // còn hạt đơn thì gần lồi. Cụm nhiều hạt (độ đặc thấp) giữ nguyên.
        if (darkTray &&
            !grain.isCluster &&
            grain.areaPx < medianArea &&
            _solidity(grain.contour) < config.darkTrayMinSolidity) {
          dust++;
          continue;
        }
        totalArea += grain.areaPx;
        if (grain.isCluster) clusterArea += grain.areaPx;
        grains.add(grain);
      }
    }
    final clusterFraction = totalArea == 0 ? 0.0 : clusterArea / totalArea;
    metrics['clusterAreaFraction'] = clusterFraction;
    if (clusterFraction > config.maxClusterAreaFraction) {
      issues.add(QualityIssue.overlap);
    }
    progress(1, 'Hoàn tất');
    return GrainImageAnalysis(
      imageWidth: image.width,
      imageHeight: image.height,
      frameWidth: w,
      frameHeight: h,
      frameToImage: frameToImage,
      pixelsPerMm: ppm,
      markersFound: pose != null,
      tiltDegrees: tilt,
      issues: issues,
      metrics: metrics,
      grains: grains,
      medianAreaPx: medianArea,
      edgeCutCount: edgeCut,
      dustCount: dust,
      ignoredRegionCount: ignored,
      clusterAreaFraction: clusterFraction,
      algorithmVersion: grainAlgorithmVersion,
      elapsedMs: watch.elapsedMilliseconds,
      excludedRegions: excluded,
      trayId: layout.id,
    );
  }

  /// Tấm nền in: 4 tâm mốc → phép nắn mm-trên-giấy → ảnh.
  _TrayPose? _locateByMarkers(RgbRaster image) {
    final markers = detectTrayMarkers(image, config, layout);
    if (markers == null) return null;
    final mmToImage = Homography.fromPoints([
      for (final c in layout.markerCenters) [c.x, c.y],
    ], markers.imagePoints);
    if (mmToImage == null) return null;
    final p = markers.imagePoints;
    final naturalPpm =
        ((_dist(p[0], p[1]) + _dist(p[3], p[2])) /
                (2 * layout.markerSpacingXMm) +
            (_dist(p[0], p[3]) + _dist(p[1], p[2])) /
                (2 * layout.markerSpacingYMm)) /
        2;
    return _TrayPose(mmToImage, naturalPpm, mmToImage, const []);
  }

  /// Khay thật không mốc: 4 góc viền ngoài → phép nắn mặt viền → ảnh, rồi
  /// quy về mặt đáy khay (nơi hạt nằm).
  ///
  /// Viền cao hơn đáy [TrayLayout.rimHeightMm] nên gần máy hơn và trông to
  /// hơn. Với máy chụp thẳng xuống, ảnh của đáy = ảnh của viền co lại quanh
  /// tâm ảnh theo hệ số s = D / (D + chiều cao thành), D là khoảng cách từ
  /// máy tới mặt viền, ước từ tiêu cự và cỡ khay trên ảnh.
  _TrayPose? _locateByOutline(RgbRaster image, Map<String, double> metrics) {
    final outline = detectTrayOutline(image, config, layout);
    if (outline == null) return null;
    final wMm = layout.pageWidthMm, hMm = layout.pageHeightMm;
    final rimToImage = Homography.fromPoints([
      [0, 0],
      [wMm, 0],
      [wMm, hMm],
      [0, hMm],
    ], outline.imagePoints);
    if (rimToImage == null) return null;
    final p = outline.imagePoints;
    final rimPpm =
        ((_dist(p[0], p[1]) + _dist(p[3], p[2])) / (2 * wMm) +
            (_dist(p[0], p[3]) + _dist(p[1], p[2])) / (2 * hMm)) /
        2;
    final focalPx =
        config.focalLengthFactor * math.max(image.width, image.height);
    final distanceMm = focalPx / rimPpm;
    final s = distanceMm / (distanceMm + layout.rimHeightMm);
    final cx = image.width / 2, cy = image.height / 2;
    var floorToImage = Homography([
      s,
      0,
      cx * (1 - s),
      0,
      s,
      cy * (1 - s),
      0,
      0,
      1,
    ]).compose(rimToImage);
    metrics['outlineSupport'] = outline.support;
    metrics['cameraDistanceMm'] = distanceMm;
    metrics['rimToFloorScale'] = s;

    // Đáy khay sáng (khay trắng) hay tối (khay đen): trung vị độ sáng trên
    // lưới điểm trong vùng phân tích — hạt chỉ chiếm phần nhỏ.
    final lumas = <int>[];
    final roi = layout.roiRect;
    for (var j = 0; j < 40; j++) {
      for (var i = 0; i < 30; i++) {
        final q = floorToImage.apply(
          roi.left + roi.width * (i + 0.5) / 30,
          roi.top + roi.height * (j + 0.5) / 40,
        );
        final x = q[0].floor(), y = q[1].floor();
        if (x < 0 || y < 0 || x >= image.width || y >= image.height) continue;
        lumas.add(image.lumaAt(y * image.width + x));
      }
    }
    lumas.sort();
    final floorLuma = lumas.isEmpty ? 0 : lumas[lumas.length ~/ 2];
    final lightFloor = floorLuma >= config.lightTrayMinLuma;
    metrics['trayFloorLuma'] = floorLuma.toDouble();

    var excluded = layout.excludedRects;
    if (excluded.isNotEmpty) {
      // Khay đối xứng: logo ở đầu này hay đầu kia (xoay 180°)? So hình ảnh
      // ở mỗi đầu với hình logo mẫu.
      final rotate = Homography([-1, 0, wMm, 0, -1, hMm, 0, 0, 1]);
      final rotated = [
        for (final r in excluded)
          MmRect(wMm - r.right, hMm - r.bottom, wMm - r.left, hMm - r.top),
      ];
      final hereFit = _logoCorrelation(image, floorToImage, lightFloor);
      final thereFit = _logoCorrelation(
        image,
        floorToImage.compose(rotate),
        lightFloor,
      );
      final here = hereFit.corr, there = thereFit.corr;
      metrics['logoScore'] = here;
      metrics['logoScoreRotated'] = there;
      // Dời vùng bỏ qua theo chỗ logo khớp nhất (chụp nghiêng làm lệch).
      List<MmRect> shifted(List<MmRect> rects, double dx, double dy) => [
        for (final r in rects)
          MmRect(r.left + dx, r.top + dy, r.right + dx, r.bottom + dy),
      ];
      final minCorr = config.logoMinCorrelation;
      if (there >= minCorr && there - here >= 0.2) {
        floorToImage = floorToImage.compose(rotate);
        excluded = shifted(excluded, thereFit.dx, thereFit.dy);
      } else if (here >= minCorr && here - there >= 0.2) {
        excluded = shifted(excluded, hereFit.dx, hereFit.dy);
      } else if (here < config.logoCoveredMaxCorrelation &&
          there < config.logoCoveredMaxCorrelation) {
        // Không đầu nào giống logo: đáy khay đã được lót tấm nền (giấy, nỉ
        // màu tối cho gạo trắng) che mất logo — phân tích cả đáy.
        excluded = const [];
        metrics['logoCovered'] = 1;
      } else {
        // Không chắc logo ở đâu: bỏ cả hai đầu cho an toàn.
        excluded = [...excluded, ...rotated];
        metrics['excludedBothEnds'] = 1;
      }
    }
    return _TrayPose(
      floorToImage,
      rimPpm * s,
      rimToImage,
      excluded,
      lightFloor: lightFloor,
    );
  }

  /// Hệ số tương quan (-1..1) giữa ảnh tại vùng logo (theo [mmToImage]) và
  /// hình logo mẫu [TrayLayout.logoTemplate]. Lấy độ sáng trung bình từng ô
  /// 2 mm (vân mảnh như vân gỗ khay đen mờ đi); logo sẫm trên khay sáng,
  /// sáng trên khay tối nên đổi dấu theo [lightFloor]. Nền loang (bóng đổ,
  /// loáng đèn) và hạt rải ngẫu nhiên không giống hình logo nên tương quan
  /// thấp. Trả về 0 nếu không có mẫu hoặc vùng nằm ngoài ảnh.
  ({double corr, double dx, double dy}) _logoCorrelation(
    RgbRaster image,
    Homography mmToImage,
    bool lightFloor,
  ) {
    // Chụp nghiêng làm vị trí logo ước được lệch vài mm: thử dịch mẫu
    // ±6 mm, lấy chỗ khớp nhất.
    var best = (corr: 0.0, dx: 0.0, dy: 0.0);
    for (var dy = -6.0; dy <= 6; dy += 2) {
      for (var dx = -6.0; dx <= 6; dx += 2) {
        final c = _logoCorrelationAt(image, mmToImage, lightFloor, dx, dy);
        if (c > best.corr) best = (corr: c, dx: dx, dy: dy);
      }
    }
    return best;
  }

  double _logoCorrelationAt(
    RgbRaster image,
    Homography mmToImage,
    bool lightFloor,
    double dx,
    double dy,
  ) {
    final rows = layout.logoTemplate;
    if (rows.isEmpty) return 0;
    final zone = layout.excludedRects.first;
    const cell = TrayLayout.logoCellMm, sub = 4;
    final xs = <double>[], ts = <double>[];
    for (var j = 0; j < rows.length; j++) {
      for (var i = 0; i < rows[j].length; i++) {
        var sum = 0.0;
        for (var v = 0; v < sub; v++) {
          for (var u = 0; u < sub; u++) {
            final q = mmToImage.apply(
              zone.left + dx + (i + (u + 0.5) / sub) * cell,
              zone.top + dy + (j + (v + 0.5) / sub) * cell,
            );
            final x = q[0].floor(), y = q[1].floor();
            if (x < 0 || y < 0 || x >= image.width || y >= image.height) {
              return 0;
            }
            sum += image.lumaAt(y * image.width + x);
          }
        }
        final mean = sum / (sub * sub);
        xs.add(lightFloor ? -mean : mean);
        ts.add(switch (rows[j][i]) {
          '#' => 1.0,
          '+' => 0.5,
          _ => 0.0,
        });
      }
    }
    final n = xs.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final mt = ts.reduce((a, b) => a + b) / n;
    var sxt = 0.0, sxx = 0.0, stt = 0.0;
    for (var k = 0; k < n; k++) {
      final dx = xs[k] - mx, dt = ts[k] - mt;
      sxt += dx * dt;
      sxx += dx * dx;
      stt += dt * dt;
    }
    if (sxx == 0 || stt == 0) return 0;
    return sxt / math.sqrt(sxx * stt);
  }

  /// Diện tích đường viền / diện tích bao lồi (1 = lồi hoàn toàn).
  static double _solidity(List<double> contour) {
    final pts = [
      for (var i = 0; i + 1 < contour.length; i += 2)
        [contour[i], contour[i + 1]],
    ];
    if (pts.length < 3) return 1;
    final hull = polygonArea(convexHull(pts));
    return hull <= 0 ? 1 : polygonArea(pts) / hull;
  }

  static double _dist(List<double> a, List<double> b) =>
      math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2));

  /// Vật thể [s] có pixel nằm trong vùng không phân tích nào không.
  static bool _touchesExcluded(
    ComponentStats s,
    Int32List labels,
    int width,
    List<PixelRect> excluded,
  ) {
    for (final r in excluded) {
      final x0 = math.max(s.minX, r.left), x1 = math.min(s.maxX + 1, r.right);
      final y0 = math.max(s.minY, r.top), y1 = math.min(s.maxY + 1, r.bottom);
      for (var y = y0; y < y1; y++) {
        for (var x = x0; x < x1; x++) {
          if (labels[y * width + x] == s.label) return true;
        }
      }
    }
    return false;
  }

  /// Khoảng màu (ΔE, đơn vị 0,5 để vừa 1 byte) từ mỗi pixel tới màu nền
  /// tại chính vị trí đó.
  Uint8List _distanceToBackground(
    RgbRaster frame,
    BackgroundModel background,
    double modelWidth,
    double modelHeight,
    double lightnessWeight,
  ) {
    final lut = LabLut.instance;
    final wl2 = lightnessWeight * lightnessWeight;
    final w = frame.width, h = frame.height;
    final out = Uint8List(w * h);
    final bl = Float32List(w), ba = Float32List(w), bb = Float32List(w);
    final d = frame.data;
    for (var y = 0; y < h; y++) {
      background.fillRow(y, w, h, modelWidth, modelHeight, bl, ba, bb);
      var o = y * w * 3;
      final row = y * w;
      for (var x = 0; x < w; x++, o += 3) {
        final idx = LabLut.indexOf(d[o], d[o + 1], d[o + 2]);
        final dl = lut.l[idx] - bl[x];
        final da = lut.a[idx] - ba[x];
        final db = lut.b[idx] - bb[x];
        final dist = math.sqrt(wl2 * dl * dl + da * da + db * db) * 2;
        out[row + x] = dist >= 255 ? 255 : dist.round();
      }
    }
    return out;
  }

  /// Ngưỡng tách hạt (đơn vị như [_distanceToBackground]): lấy mức nhỏ hơn
  /// giữa Otsu và "nền + [noiseSigmas] độ lệch nhiễu", kẹp trong khoảng ΔE
  /// của cấu hình. Otsu một mình bị hạt sẫm kéo ngưỡng lên cao, bỏ sót hạt
  /// sáng màu gần màu nền.
  double _foregroundThreshold(
    Uint8List distance,
    double minDeltaE,
    double maxDeltaE,
  ) {
    final histogram = List<int>.filled(256, 0);
    for (final v in distance) {
      histogram[v]++;
    }
    final otsu = otsuThreshold(histogram) + 0.5;
    // Đa số pixel là nền: trung vị và MAD của khoảng cách ≈ mức nhiễu nền.
    int percentile(double p) {
      final target = distance.length * p;
      var acc = 0;
      for (var i = 0; i < 256; i++) {
        acc += histogram[i];
        if (acc >= target) return i;
      }
      return 255;
    }

    final med = percentile(0.5);
    var mad = 0;
    {
      final dev = List<int>.filled(256, 0);
      for (var i = 0; i < 256; i++) {
        dev[(i - med).abs()] += histogram[i];
      }
      var acc = 0;
      for (var i = 0; i < 256; i++) {
        acc += dev[i];
        if (acc >= distance.length / 2) {
          mad = i;
          break;
        }
      }
    }
    final noise = med + config.noiseSigmas * 1.4826 * math.max(1, mad);
    return math.min(otsu, noise).clamp(minDeltaE * 2, maxDeltaE * 2).toDouble();
  }

  static double _areaWeightedMedian(List<int> areas) {
    if (areas.isEmpty) return 0;
    final sorted = List<int>.of(areas)..sort();
    final total = sorted.fold<int>(0, (a, b) => a + b);
    var acc = 0;
    for (final a in sorted) {
      acc += a;
      if (acc * 2 >= total) return a.toDouble();
    }
    return sorted.last.toDouble();
  }

  /// Đo một hạt từ mặt nạ cục bộ [region] (khung [bw] × [bh] đặt tại
  /// ([ox], [oy]) trên ảnh đã nắn).
  Grain? _measure(
    Uint8List region,
    int bw,
    int bh,
    int ox,
    int oy,
    RgbRaster frame,
    LabLut lut,
    double? ppm,
    double medianArea,
    String id,
    int imageIndex,
  ) {
    var area = 0;
    var sx = 0.0, sy = 0.0, sl = 0.0, sa = 0.0, sb = 0.0;
    final corners = <List<double>>[];
    final fw = frame.width;
    for (var y = 0; y < bh; y++) {
      for (var x = 0; x < bw; x++) {
        final i = y * bw + x;
        if (region[i] == 0) continue;
        area++;
        sx += x;
        sy += y;
        final o = ((oy + y) * fw + ox + x) * 3;
        final idx = LabLut.indexOf(
          frame.data[o],
          frame.data[o + 1],
          frame.data[o + 2],
        );
        sl += lut.l[idx];
        sa += lut.a[idx];
        sb += lut.b[idx];
        final boundary =
            x == 0 ||
            y == 0 ||
            x == bw - 1 ||
            y == bh - 1 ||
            region[i - 1] == 0 ||
            region[i + 1] == 0 ||
            region[i - bw] == 0 ||
            region[i + bw] == 0;
        if (boundary) {
          final gx = (ox + x).toDouble(), gy = (oy + y).toDouble();
          corners
            ..add([gx, gy])
            ..add([gx + 1, gy])
            ..add([gx, gy + 1])
            ..add([gx + 1, gy + 1]);
        }
      }
    }
    if (area == 0) return null;
    final rect = minAreaRect(convexHull(corners));
    final raw = traceContour(region, bw, bh);
    final simplified = simplifyClosed(raw, config.contourSimplifyPx);
    final contour = <double>[
      for (var i = 0; i < simplified.length; i += 2) ...[
        simplified[i] + ox,
        simplified[i + 1] + oy,
      ],
    ];
    final estimated = area > config.clusterAreaFactor * medianArea
        ? math.max(2, (area / medianArea).round())
        : 1;
    return Grain(
      id: id,
      imageIndex: imageIndex,
      contour: contour,
      centroidX: ox + sx / area + 0.5,
      centroidY: oy + sy / area + 0.5,
      areaPx: area.toDouble(),
      lengthPx: rect.length,
      widthPx: rect.width,
      lengthMm: ppm == null ? null : rect.length / ppm,
      widthMm: ppm == null ? null : rect.width / ppm,
      areaMm2: ppm == null ? null : area / (ppm * ppm),
      meanColorLab: [sl / area, sa / area, sb / area],
      estimatedCount: estimated,
    );
  }
}

/// Tìm khay thật không mốc (khay AnySort...) trên ảnh — dùng khi người dùng
/// chọn tấm nền in nhưng ảnh không có mốc (quên đổi ô "Khay chuẩn"). Không
/// đoán ngược từ khay thật sang tấm nền in: A4 và A3 cùng tỉ lệ nên không
/// phân biệt được, đoán sai sẽ sai số đo mm.
TrayLayout? findPlainTray(
  RgbRaster image, {
  GrainAnalysisConfig config = const GrainAnalysisConfig(),
}) {
  for (final l in TrayLayout.all) {
    if (!l.hasMarkers && detectTrayOutline(image, config, l) != null) return l;
  }
  return null;
}

/// Vị trí khay trên ảnh sau bước 1.
class _TrayPose {
  const _TrayPose(
    this.mmToImage,
    this.naturalPpm,
    this.whiteToImage,
    this.excluded, {
    this.lightFloor = false,
  });

  /// mm trên mặt đặt hạt (giấy hoặc đáy khay) → pixel ảnh gốc.
  final Homography mmToImage;

  /// Số pixel / mm trên mặt đặt hạt, trước khi giới hạn trần.
  final double naturalPpm;

  /// Phép nắn dùng để lấy ô trắng chuẩn ([TrayLayout.whitePatchRect]).
  final Homography whiteToImage;

  /// Vùng không phân tích, mm theo [mmToImage].
  final List<MmRect> excluded;

  /// Khay thật có đáy sáng (khay trắng): tách hạt dùng tham số "lightTray".
  final bool lightFloor;
}
