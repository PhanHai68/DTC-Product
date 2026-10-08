import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../engine/grain_analyzer.dart';
import '../engine/result_calculator.dart';
import '../engine/tray_layout.dart';
import '../models/analysis_session.dart';
import '../models/grain.dart';
import '../repositories/grain_analysis_repository.dart';
import '../services/grain_analysis_runner.dart';
import '../services/grain_photo_service.dart';

/// State của Phân tích mẫu AI — chỉ sống trong nhóm route
/// `/grain-analysis` (xem grain_analysis_routes.dart).
class GrainAnalysisProvider extends ChangeNotifier {
  GrainAnalysisProvider({
    GrainAnalysisRepository? repository,
    GrainPhotoService? photoService,
    GrainAnalysisRunner? runner,
  }) : _repository = repository ?? GrainAnalysisRepository(),
       photoService = photoService ?? GrainPhotoService(),
       runner = runner ?? const GrainAnalysisRunner();

  final GrainAnalysisRepository _repository;
  final GrainPhotoService photoService;
  final GrainAnalysisRunner runner;

  bool _isLoading = true;
  String? _error;
  List<AnalysisSessionSummary> _sessions = const [];
  String _operatorName = '';
  TrayLayout _tray = TrayLayout.a4;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<AnalysisSessionSummary> get sessions => _sessions;
  String get operatorName => _operatorName;
  TrayLayout get tray => _tray;
  bool get isSupported => photoService.storage.isSupported;

  Future<void> init() async {
    if (!isSupported) {
      _isLoading = false;
      _notify();
      return;
    }
    try {
      _operatorName =
          await _repository.getSetting(GrainAnalysisRepository.operatorKey) ??
          '';
      _tray = TrayLayout.byId(
        await _repository.getSetting(GrainAnalysisRepository.trayKey),
      );
      _sessions = await _repository.listSessions();
    } catch (error) {
      _error = 'Không mở được dữ liệu Phân tích mẫu: $error';
    }
    _isLoading = false;
    _notify();
  }

  Future<void> refresh() async {
    _sessions = await _repository.listSessions();
    _notify();
  }

  Future<void> savePreferences({String? operatorName, TrayLayout? tray}) async {
    if (operatorName != null && operatorName != _operatorName) {
      _operatorName = operatorName;
      await _repository.setSetting(
        GrainAnalysisRepository.operatorKey,
        operatorName,
      );
    }
    if (tray != null && tray.id != _tray.id) {
      _tray = tray;
      await _repository.setSetting(GrainAnalysisRepository.trayKey, tray.id);
    }
    _notify();
  }

  String newSessionId() => const Uuid().v4();

  /// Tạo phiên nháp từ các ảnh đã phân tích rồi lưu.
  Future<AnalysisSession> createSession({
    required String id,
    required AnalysisMode mode,
    required SampleType sampleType,
    required String? lotCode,
    required double? sampleWeightG,
    required String? note,
    required TrayLayout tray,
    required List<({String fileName, GrainImageAnalysis analysis})> images,
  }) async {
    final now = DateTime.now();
    final grains = [for (final i in images) ...i.analysis.grains];
    final session = AnalysisSession(
      id: id,
      mode: mode,
      lotCode: lotCode,
      sampleType: sampleType,
      sampleWeightG: sampleWeightG,
      trayId: tray.id,
      images: [
        for (final i in images)
          SessionImage(
            fileName: i.fileName,
            width: i.analysis.imageWidth,
            height: i.analysis.imageHeight,
            frameWidth: i.analysis.frameWidth,
            frameHeight: i.analysis.frameHeight,
            frameToImage: i.analysis.frameToImage.toList(),
            pixelsPerMm: i.analysis.pixelsPerMm,
            markersFound: i.analysis.markersFound,
            tiltDegrees: i.analysis.tiltDegrees,
            issues: [for (final q in i.analysis.issues) q.name],
            metrics: i.analysis.metrics,
            medianAreaPx: i.analysis.medianAreaPx,
            edgeCutCount: i.analysis.edgeCutCount,
            dustCount: i.analysis.dustCount,
            ignoredRegionCount: i.analysis.ignoredRegionCount,
            clusterAreaFraction: i.analysis.clusterAreaFraction,
          ),
      ],
      grains: grains,
      results: const [],
      status: SessionStatus.draft,
      algorithmVersion: images.first.analysis.algorithmVersion,
      createdBy: _operatorName,
      createdAt: now,
      updatedAt: now,
      note: note,
    );
    final withResults = session.copyWith(results: computeResults(session));
    await _repository.saveSession(withResults);
    await refresh();
    return withResults;
  }

  Future<AnalysisSession?> loadSession(String id) => _repository.getSession(id);

  /// Tính lại kết quả từ dữ liệu hạt (sau mỗi lần sửa tay).
  static List<ClassResult> computeResults(AnalysisSession s) {
    if (s.mode == AnalysisMode.quick && s.images.length >= 2) {
      return GrainResultCalculator.quickCount(
        wholeGrains: s.grainsOf(0),
        wholePixelsPerMm: s.images[0].pixelsPerMm,
        groupGrains: s.grainsOf(1),
        groupPixelsPerMm: s.images[1].pixelsPerMm,
      ).toClassResults();
    }
    return GrainResultCalculator.countResults(s.grainsOf(0));
  }

  /// Ghi các hạt vừa sửa tay; trả về phiên đã tính lại kết quả.
  Future<AnalysisSession> applyEdits(
    AnalysisSession session, {
    List<Grain> upserted = const [],
    List<String> deletedIds = const [],
  }) async {
    final byId = {for (final g in session.grains) g.id: g};
    for (final id in deletedIds) {
      byId.remove(id);
    }
    for (final g in upserted) {
      byId[g.id] = g;
    }
    var next = session.copyWith(
      grains: byId.values.toList(),
      updatedAt: DateTime.now(),
    );
    next = next.copyWith(results: computeResults(next));
    await _repository.saveEdits(
      next,
      upserted: upserted,
      deletedIds: deletedIds,
    );
    await refresh();
    return next;
  }

  Future<AnalysisSession> confirm(AnalysisSession session) async {
    final next = session.copyWith(
      status: SessionStatus.confirmed,
      updatedAt: DateTime.now(),
    );
    await _repository.saveEdits(next, upserted: const []);
    await refresh();
    return next;
  }

  Future<void> deleteSession(AnalysisSession session) async {
    await _repository.deleteSession(session.id);
    for (final f in session.imagePaths) {
      await photoService.delete(f);
    }
    await refresh();
  }

  /// Xóa ảnh đã chụp của một phiên bị hủy giữa chừng.
  Future<void> discardImages(Iterable<String> fileNames) async {
    for (final f in fileNames) {
      await photoService.delete(f);
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
