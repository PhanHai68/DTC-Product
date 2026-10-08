/// Mọi ngưỡng và tham số của thuật toán phân tích mẫu bằng ảnh (NFR-05).
///
/// Các giá trị mặc định là điểm khởi đầu theo tài liệu yêu cầu (mục 7, 9);
/// chỉnh lại ở giai đoạn 0 bằng `tool/grain_count_cli.dart --config <json>`
/// rồi chép bộ đã chỉnh vào đây. File này không import Flutter để chạy được
/// cả trong app lẫn script dòng lệnh.
library;

/// Phiên bản thuật toán, ghi vào mỗi phiên (NFR-07). Tăng khi đổi tham số
/// mặc định hoặc logic xử lý.
const grainAlgorithmVersion = 'grain-count-1.3.1';

class GrainAnalysisConfig {
  const GrainAnalysisConfig({
    this.markerDetectMaxEdge = 1600,
    this.markerMinAreaFraction = 0.0003,
    this.markerMaxAreaFraction = 0.05,
    this.markerMinFill = 0.55,
    this.markerMaxFill = 0.97,
    this.markerMinHoleRatio = 0.06,
    this.markerMaxHoleRatio = 0.45,
    this.markerMaxAspect = 1.8,
    this.outlineDetectMaxEdge = 1000,
    this.outlineMinAreaFraction = 0.1,
    this.outlineLineTolerancePx = 1.5,
    this.outlineMaxLines = 6,
    this.outlineRansacIterations = 300,
    this.excludedMarginMm = 2,
    this.logoMinCorrelation = 0.45,
    this.logoCoveredMaxCorrelation = 0.35,
    this.lightTrayMinLuma = 160,
    this.lightTrayLightnessWeight = 1.0,
    this.lightTrayMinForegroundDeltaE = 10,
    this.darkTrayMaxForegroundDeltaE = 14,
    this.darkTrayOpenRadiusMm = 0.6,
    this.darkTrayDustAreaFraction = 0.35,
    this.darkTrayMinSolidity = 0.85,
    this.darkTrayMaxBackgroundUnevenness = 0.5,
    this.maxPixelsPerMm = 30,
    this.focalLengthFactor = 0.75,
    this.maxTiltDegrees = 10,
    this.qualityMaxEdge = 1600,
    this.minLaplacianVariance = 40,
    this.maxBackgroundUnevenness = 0.15,
    this.backgroundCellMm = 12,
    this.backgroundMinSupport = 0.15,
    this.backgroundMaxDeviationDeltaE = 25,
    this.highlightLevel = 250,
    this.maxHighlightFraction = 0.01,
    this.defaultMinPixelsPerMm = 10,
    this.maxClusterAreaFraction = 0.05,
    this.backgroundBandMm = 5,
    this.noMarkerBorderFraction = 0.01,
    this.minForegroundDeltaE = 10,
    this.maxForegroundDeltaE = 40,
    this.noiseSigmas = 6,
    this.minContrastRatio = 1.5,
    this.lightnessWeight = 1.0,
    this.openRadiusMm = 0.2,
    this.closeRadiusMm = 0.2,
    this.assumedFrameLongEdgeMm = 300,
    this.minObjectAreaPx = 12,
    this.minObjectAreaMm2 = 0.3,
    this.maxClusterGrains = 25,
    this.clusterAreaFactor = 1.6,
    this.dustAreaFraction = 0.10,
    this.seedThresholds = const [0.35, 0.45, 0.55, 0.65, 0.75, 0.85],
    this.minFragmentFraction = 0.35,
    this.splitAreaSlack = 0.6,
    this.contourSimplifyPx = 0.8,
  });

  // ------------------------------------------------ Bước 1: nắn ảnh (mốc)

  /// Cạnh dài tối đa của ảnh thu nhỏ dùng để tìm mốc góc khay.
  final int markerDetectMaxEdge;

  /// Diện tích một mốc so với cả ảnh: nhỏ nhất / lớn nhất.
  final double markerMinAreaFraction;
  final double markerMaxAreaFraction;

  /// Tỉ lệ phần đen của mốc trong hình chữ nhật bao.
  final double markerMinFill;
  final double markerMaxFill;

  /// Tỉ lệ ô trắng giữa mốc so với cả mốc (mốc in có ô trắng 8/18 cạnh).
  final double markerMinHoleRatio;
  final double markerMaxHoleRatio;

  /// Tỉ lệ dài/rộng tối đa của hình bao mốc (chụp nghiêng làm mốc méo).
  final double markerMaxAspect;

  // ------------------------------------- Bước 1: khay không mốc (theo viền)

  /// Cạnh dài tối đa của ảnh thu nhỏ dùng để tìm viền khay.
  final int outlineDetectMaxEdge;

  /// Vùng sáng (khay) phải chiếm ít nhất tỉ lệ này diện tích ảnh.
  final double outlineMinAreaFraction;

  /// Điểm biên cách đường thẳng không quá chừng này (pixel ảnh thu nhỏ) thì
  /// coi là nằm trên cạnh khay.
  final double outlineLineTolerancePx;

  /// Số đường thẳng tối đa dò trên biên, và số lần thử RANSAC mỗi đường.
  final int outlineMaxLines;
  final int outlineRansacIterations;

  /// Nới vùng không phân tích (logo) thêm chừng này mm mỗi phía.
  final double excludedMarginMm;

  /// Logo nhận ra ở một đầu khay khi tương quan với hình logo mẫu ≥ mức này
  /// và hơn đầu kia ≥ 0,2 — để biết khay đang xoay chiều nào. Ảnh thật
  /// 08/10/2026: đầu có logo 0,65–0,86, đầu không có ≤ 0,30.
  final double logoMinCorrelation;

  /// Cả hai đầu dưới mức này: logo bị tấm lót che, phân tích cả đáy khay.
  final double logoCoveredMaxCorrelation;

  /// Khay thật có độ sáng đáy (trung vị, 0..255) ≥ mức này là khay sáng.
  /// Máy ảnh tự cân sáng nên khay đen trên ảnh chỉ xám vừa (đo được 113–130),
  /// khay trắng kể cả chỗ bóng đổ ≈ 175–220.
  final int lightTrayMinLuma;

  /// Khay sáng: trọng số độ sáng và ngưỡng tách nền tối thiểu riêng, thay
  /// cho [lightnessWeight], [minForegroundDeltaE]. Mặc định bằng tham số
  /// chung. Đã thử 0,15 / 3 cho gạo trắng trên khay trắng (gạo chỉ khác nền
  /// ở độ ngả vàng): đếm được 122/~150 hạt nhưng khay trắng trống cũng ra 59
  /// "hạt" do vân nứt của khay — không dùng. Gạo trắng nên dùng khay đen.
  final double lightTrayLightnessWeight;
  final double lightTrayMinForegroundDeltaE;

  /// Khay thật có đáy tối (khay đen có vân): chỗ loáng đèn vệt vân sáng gần
  /// bằng hạt. Hạ trần ngưỡng tách nền ([maxForegroundDeltaE]) để bắt hạt ở
  /// đó, rồi xóa vệt vân mảnh bằng phép mở bán kính lớn hơn ([openRadiusMm]).
  /// Hạt phải rộng hơn 2 × bán kính mở. Chỉnh trên 7 ảnh khay đen 08/10/2026.
  final double darkTrayMaxForegroundDeltaE;
  final double darkTrayOpenRadiusMm;

  /// Khay tối: phép mở còn để lại các đốm vân tròn nhỏ (≈ 2 × bán kính mở)
  /// và mảng vân méo. Bỏ vật nhỏ hơn tỉ lệ này × diện tích trung vị (thay
  /// cho [dustAreaFraction]; mảnh hạt vỡ nhỏ hơn cũng không được đếm) và vật
  /// đơn nhỏ hơn một hạt có độ đặc (diện tích / bao lồi) dưới mức này.
  final double darkTrayDustAreaFraction;
  final double darkTrayMinSolidity;

  /// Khay tối có vân: vân làm số đo độ đều nền cao hơn thật — dùng mức này
  /// thay [maxBackgroundUnevenness]. Ảnh thử: ánh sáng tốt 0,37, có vệt
  /// loáng đèn 0,65.
  final double darkTrayMaxBackgroundUnevenness;

  /// Trần độ phân giải ảnh đã nắn, để giới hạn bộ nhớ khi chụp quá gần.
  final double maxPixelsPerMm;

  /// Tiêu cự ước lượng = hệ số × cạnh dài ảnh, dùng để ước góc nghiêng.
  final double focalLengthFactor;

  // ---------------------------------------- Mục 9: kiểm tra chất lượng ảnh

  /// Góc nghiêng tối đa so với chụp thẳng từ trên xuống (độ).
  final double maxTiltDegrees;

  /// Cạnh dài của ảnh thu nhỏ dùng cho các phép kiểm tra nhanh.
  final int qualityMaxEdge;

  /// Phương sai Laplacian tối thiểu (đo trên ảnh thu nhỏ [qualityMaxEdge]).
  final double minLaplacianVariance;

  /// Chênh độ sáng nền tối đa giữa các vùng khay (0,15 = 15%).
  final double maxBackgroundUnevenness;

  /// Pixel có kênh màu ≥ mức này là cháy sáng.
  final int highlightLevel;

  /// Tỉ lệ diện tích cháy sáng tối đa (0,01 = 1%).
  final double maxHighlightFraction;

  /// pixelsPerMm tối thiểu khi chưa có hồ sơ nguyên liệu.
  final double defaultMinPixelsPerMm;

  /// Diện tích cụm không tách được tối đa so với tổng diện tích hạt.
  final double maxClusterAreaFraction;

  // --------------------------------------------------- Bước 2: tách nền

  /// Bề rộng dải viền khay dùng lấy màu nền chung (mm), khi có mốc.
  final double backgroundBandMm;

  /// Nền được ước cục bộ trên lưới ô cạnh này (mm) để chịu được giấy/khay
  /// sáng không đều. Cũng dùng để đo độ đều ánh sáng (mục 9).
  final double backgroundCellMm;

  /// Ô chỉ hợp lệ khi màu nền chiếm ít nhất tỉ lệ này số pixel của ô.
  final double backgroundMinSupport;

  /// Ô có màu lệch màu nền chung quá mức này (ΔE) coi như bị hạt che kín.
  final double backgroundMaxDeviationDeltaE;

  /// Không có mốc: bỏ dải viền ảnh rộng bằng tỉ lệ này.
  final double noMarkerBorderFraction;

  /// Ngưỡng khoảng màu (ΔE Lab) giữa hạt và nền; tự chọn theo Otsu rồi
  /// kẹp trong khoảng này.
  final double minForegroundDeltaE;
  final double maxForegroundDeltaE;

  /// Ngưỡng không vượt quá mức nhiễu nền + chừng này độ lệch chuẩn (ước từ
  /// trung vị và MAD) — giữ được hạt sáng màu gần màu nền.
  final double noiseSigmas;

  /// Khoảng màu trung bình của một vật thể phải ≥ hệ số này × ngưỡng tách
  /// nền; thấp hơn là vân giấy / bóng mờ, không phải hạt.
  final double minContrastRatio;

  /// Trọng số chênh độ sáng L khi đo khoảng màu (giảm để bớt nhạy bóng đổ).
  final double lightnessWeight;

  /// Bán kính phép mở / đóng hình thái (mm).
  final double openRadiusMm;
  final double closeRadiusMm;

  /// Không thấy mốc khay: chưa biết tỉ lệ pixel/mm thật, tạm coi cạnh dài
  /// ảnh ≈ chừng này mm (khay A4 đầy khung) để quy các tham số mm ra pixel.
  /// Chỉ dùng cho xử lý, không báo thành số đo.
  final double assumedFrameLongEdgeMm;

  /// Vật thể nhỏ hơn số pixel này, hoặc nhỏ hơn [minObjectAreaMm2], bị bỏ
  /// ngay (nhiễu, vân giấy).
  final int minObjectAreaPx;
  final double minObjectAreaMm2;

  /// Vùng lớn hơn chừng này × diện tích trung vị không phải cụm hạt (bóng
  /// đổ, mép giấy, vết bẩn): không tính vào kết quả, báo cho người dùng.
  final int maxClusterGrains;

  // -------------------------------------------- Bước 3-5: tách cụm, lọc

  /// Vùng lớn hơn hệ số này × diện tích trung vị là cụm cần tách.
  final double clusterAreaFactor;

  /// Bỏ vật thể nhỏ hơn tỉ lệ này × diện tích trung vị (bụi, mảnh vụn).
  final double dustAreaFraction;

  /// Các mức cắt (theo tỉ lệ khoảng cách lớn nhất) thử lần lượt để tìm
  /// hạt giống cho watershed; chọn mức cho số hạt gần ước lượng nhất.
  final List<double> seedThresholds;

  /// Mảnh sau watershed nhỏ hơn tỉ lệ này × trung vị thì gộp vào hạt kề.
  final double minFragmentFraction;

  /// Cụm tách được tối đa (diện tích / trung vị + mức này) mảnh, làm tròn
  /// xuống: cụm 1,98 hạt → tối đa 2 mảnh, cụm 2,4 hạt (hạt nhỏ) → 3 mảnh.
  final double splitAreaSlack;

  /// Sai số tối đa (px) khi rút gọn đường viền.
  final double contourSimplifyPx;

  /// Đọc cấu hình từ JSON; khóa nào thiếu thì lấy theo [base] (mặc định là
  /// bộ tham số chung).
  factory GrainAnalysisConfig.fromJson(
    Map<String, Object?> json, {
    GrainAnalysisConfig base = const GrainAnalysisConfig(),
  }) {
    final d = base;
    double n(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    int i(String key, int fallback) => (json[key] as num?)?.toInt() ?? fallback;
    return GrainAnalysisConfig(
      markerDetectMaxEdge: i('markerDetectMaxEdge', d.markerDetectMaxEdge),
      markerMinAreaFraction: n(
        'markerMinAreaFraction',
        d.markerMinAreaFraction,
      ),
      markerMaxAreaFraction: n(
        'markerMaxAreaFraction',
        d.markerMaxAreaFraction,
      ),
      markerMinFill: n('markerMinFill', d.markerMinFill),
      markerMaxFill: n('markerMaxFill', d.markerMaxFill),
      markerMinHoleRatio: n('markerMinHoleRatio', d.markerMinHoleRatio),
      markerMaxHoleRatio: n('markerMaxHoleRatio', d.markerMaxHoleRatio),
      markerMaxAspect: n('markerMaxAspect', d.markerMaxAspect),
      outlineDetectMaxEdge: i('outlineDetectMaxEdge', d.outlineDetectMaxEdge),
      outlineMinAreaFraction: n(
        'outlineMinAreaFraction',
        d.outlineMinAreaFraction,
      ),
      outlineLineTolerancePx: n(
        'outlineLineTolerancePx',
        d.outlineLineTolerancePx,
      ),
      outlineMaxLines: i('outlineMaxLines', d.outlineMaxLines),
      outlineRansacIterations: i(
        'outlineRansacIterations',
        d.outlineRansacIterations,
      ),
      excludedMarginMm: n('excludedMarginMm', d.excludedMarginMm),
      logoMinCorrelation: n('logoMinCorrelation', d.logoMinCorrelation),
      logoCoveredMaxCorrelation: n(
        'logoCoveredMaxCorrelation',
        d.logoCoveredMaxCorrelation,
      ),
      lightTrayMinLuma: i('lightTrayMinLuma', d.lightTrayMinLuma),
      lightTrayLightnessWeight: n(
        'lightTrayLightnessWeight',
        d.lightTrayLightnessWeight,
      ),
      lightTrayMinForegroundDeltaE: n(
        'lightTrayMinForegroundDeltaE',
        d.lightTrayMinForegroundDeltaE,
      ),
      darkTrayMaxForegroundDeltaE: n(
        'darkTrayMaxForegroundDeltaE',
        d.darkTrayMaxForegroundDeltaE,
      ),
      darkTrayOpenRadiusMm: n('darkTrayOpenRadiusMm', d.darkTrayOpenRadiusMm),
      darkTrayDustAreaFraction: n(
        'darkTrayDustAreaFraction',
        d.darkTrayDustAreaFraction,
      ),
      darkTrayMinSolidity: n('darkTrayMinSolidity', d.darkTrayMinSolidity),
      darkTrayMaxBackgroundUnevenness: n(
        'darkTrayMaxBackgroundUnevenness',
        d.darkTrayMaxBackgroundUnevenness,
      ),
      maxPixelsPerMm: n('maxPixelsPerMm', d.maxPixelsPerMm),
      focalLengthFactor: n('focalLengthFactor', d.focalLengthFactor),
      maxTiltDegrees: n('maxTiltDegrees', d.maxTiltDegrees),
      qualityMaxEdge: i('qualityMaxEdge', d.qualityMaxEdge),
      minLaplacianVariance: n('minLaplacianVariance', d.minLaplacianVariance),
      maxBackgroundUnevenness: n(
        'maxBackgroundUnevenness',
        d.maxBackgroundUnevenness,
      ),
      backgroundCellMm: n('backgroundCellMm', d.backgroundCellMm),
      backgroundMinSupport: n('backgroundMinSupport', d.backgroundMinSupport),
      backgroundMaxDeviationDeltaE: n(
        'backgroundMaxDeviationDeltaE',
        d.backgroundMaxDeviationDeltaE,
      ),
      highlightLevel: i('highlightLevel', d.highlightLevel),
      maxHighlightFraction: n('maxHighlightFraction', d.maxHighlightFraction),
      defaultMinPixelsPerMm: n(
        'defaultMinPixelsPerMm',
        d.defaultMinPixelsPerMm,
      ),
      maxClusterAreaFraction: n(
        'maxClusterAreaFraction',
        d.maxClusterAreaFraction,
      ),
      backgroundBandMm: n('backgroundBandMm', d.backgroundBandMm),
      noMarkerBorderFraction: n(
        'noMarkerBorderFraction',
        d.noMarkerBorderFraction,
      ),
      minForegroundDeltaE: n('minForegroundDeltaE', d.minForegroundDeltaE),
      maxForegroundDeltaE: n('maxForegroundDeltaE', d.maxForegroundDeltaE),
      noiseSigmas: n('noiseSigmas', d.noiseSigmas),
      minContrastRatio: n('minContrastRatio', d.minContrastRatio),
      lightnessWeight: n('lightnessWeight', d.lightnessWeight),
      openRadiusMm: n('openRadiusMm', d.openRadiusMm),
      closeRadiusMm: n('closeRadiusMm', d.closeRadiusMm),
      assumedFrameLongEdgeMm: n(
        'assumedFrameLongEdgeMm',
        d.assumedFrameLongEdgeMm,
      ),
      minObjectAreaPx: i('minObjectAreaPx', d.minObjectAreaPx),
      minObjectAreaMm2: n('minObjectAreaMm2', d.minObjectAreaMm2),
      maxClusterGrains: i('maxClusterGrains', d.maxClusterGrains),
      clusterAreaFactor: n('clusterAreaFactor', d.clusterAreaFactor),
      dustAreaFraction: n('dustAreaFraction', d.dustAreaFraction),
      seedThresholds:
          (json['seedThresholds'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          d.seedThresholds,
      minFragmentFraction: n('minFragmentFraction', d.minFragmentFraction),
      splitAreaSlack: n('splitAreaSlack', d.splitAreaSlack),
      contourSimplifyPx: n('contourSimplifyPx', d.contourSimplifyPx),
    );
  }

  Map<String, Object?> toJson() => {
    'markerDetectMaxEdge': markerDetectMaxEdge,
    'markerMinAreaFraction': markerMinAreaFraction,
    'markerMaxAreaFraction': markerMaxAreaFraction,
    'markerMinFill': markerMinFill,
    'markerMaxFill': markerMaxFill,
    'markerMinHoleRatio': markerMinHoleRatio,
    'markerMaxHoleRatio': markerMaxHoleRatio,
    'markerMaxAspect': markerMaxAspect,
    'outlineDetectMaxEdge': outlineDetectMaxEdge,
    'outlineMinAreaFraction': outlineMinAreaFraction,
    'outlineLineTolerancePx': outlineLineTolerancePx,
    'outlineMaxLines': outlineMaxLines,
    'outlineRansacIterations': outlineRansacIterations,
    'excludedMarginMm': excludedMarginMm,
    'logoMinCorrelation': logoMinCorrelation,
    'logoCoveredMaxCorrelation': logoCoveredMaxCorrelation,
    'lightTrayMinLuma': lightTrayMinLuma,
    'lightTrayLightnessWeight': lightTrayLightnessWeight,
    'lightTrayMinForegroundDeltaE': lightTrayMinForegroundDeltaE,
    'darkTrayMaxForegroundDeltaE': darkTrayMaxForegroundDeltaE,
    'darkTrayOpenRadiusMm': darkTrayOpenRadiusMm,
    'darkTrayDustAreaFraction': darkTrayDustAreaFraction,
    'darkTrayMinSolidity': darkTrayMinSolidity,
    'darkTrayMaxBackgroundUnevenness': darkTrayMaxBackgroundUnevenness,
    'maxPixelsPerMm': maxPixelsPerMm,
    'focalLengthFactor': focalLengthFactor,
    'maxTiltDegrees': maxTiltDegrees,
    'qualityMaxEdge': qualityMaxEdge,
    'minLaplacianVariance': minLaplacianVariance,
    'maxBackgroundUnevenness': maxBackgroundUnevenness,
    'backgroundCellMm': backgroundCellMm,
    'backgroundMinSupport': backgroundMinSupport,
    'backgroundMaxDeviationDeltaE': backgroundMaxDeviationDeltaE,
    'highlightLevel': highlightLevel,
    'maxHighlightFraction': maxHighlightFraction,
    'defaultMinPixelsPerMm': defaultMinPixelsPerMm,
    'maxClusterAreaFraction': maxClusterAreaFraction,
    'backgroundBandMm': backgroundBandMm,
    'noMarkerBorderFraction': noMarkerBorderFraction,
    'minForegroundDeltaE': minForegroundDeltaE,
    'maxForegroundDeltaE': maxForegroundDeltaE,
    'noiseSigmas': noiseSigmas,
    'minContrastRatio': minContrastRatio,
    'lightnessWeight': lightnessWeight,
    'openRadiusMm': openRadiusMm,
    'closeRadiusMm': closeRadiusMm,
    'assumedFrameLongEdgeMm': assumedFrameLongEdgeMm,
    'minObjectAreaPx': minObjectAreaPx,
    'minObjectAreaMm2': minObjectAreaMm2,
    'maxClusterGrains': maxClusterGrains,
    'clusterAreaFactor': clusterAreaFactor,
    'dustAreaFraction': dustAreaFraction,
    'seedThresholds': seedThresholds,
    'minFragmentFraction': minFragmentFraction,
    'splitAreaSlack': splitAreaSlack,
    'contourSimplifyPx': contourSimplifyPx,
  };
}
