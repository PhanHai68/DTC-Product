import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/grinding_extra_spec.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_material.dart';
import '../models/grinding_material_series_map.dart';
import '../models/grinding_recommendation.dart';
import '../models/grinding_selection_request.dart';
import '../models/grinding_series.dart';
import '../models/grinding_import_report.dart';
import '../repositories/grinding_machine_repository.dart';
import '../services/grinding_machine_importer.dart';
import '../services/grinding_selection_engine.dart';
import '../services/grinding_database_validator.dart';
import '../services/grinding_excel_parser.dart';

/// Đường dẫn asset chứa dữ liệu seed (convert 1 lần từ file Excel
/// DTC_Grinding_Machine_Database_AI_Ready.xlsx) — xem README trong
/// assets/database/.
const _seedAssetPath = 'assets/database/grinding_machine_seed.json';

/// Quản lý dữ liệu module "Máy nghiền": tự seed database lần đầu mở màn
/// hình (hoặc khi file seed đóng gói có `databaseVersion` mới hơn bản đã
/// import), sau đó giữ danh sách series/model cho Home/Search/Series list.
class GrindingMachineProvider extends ChangeNotifier {
  GrindingMachineProvider({GrindingMachineRepository? repository})
    : _repository = repository ?? GrindingMachineRepository();

  final GrindingMachineRepository _repository;

  List<GrindingSeries> _series = const [];
  List<GrindingMachine> _machines = const [];
  bool _isLoading = false;
  String? _error;
  bool _initialized = false;
  bool _disposed = false;
  Future<void> _operation = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _operation.then((_) => action());
    _operation = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<GrindingSeries> get series => _series;
  List<GrindingMachine> get machines => _machines;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<GrindingMachine> machinesOf(String seriesCode) =>
      _machines.where((m) => m.seriesCode == seriesCode).toList();

  int machineCountOf(String seriesCode) =>
      _machines.where((m) => m.seriesCode == seriesCode).length;

  /// Nạp dữ liệu cho Home: seed database nếu chưa có hoặc file seed đóng gói
  /// đã cập nhật phiên bản mới, sau đó đọc series + machines.
  Future<void> loadHome() => _serial(_loadHome);

  Future<void> _loadHome() async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final meta = await _repository.getImportMetadata();
      final importedVersion = meta['databaseVersion'];
      // Metadata cũ chưa có importOrigin: giữ dữ liệu hiện có. Chỉ tự nâng
      // seed khi biết chắc catalog trước đó cũng đến từ seed.
      if (importedVersion == null || meta['importOrigin'] == 'seed') {
        final seedJson = await rootBundle.loadString(_seedAssetPath);
        final snapshot = GrindingMachineImporter.parse(seedJson);
        if (importedVersion == null ||
            (GrindingDatabaseValidator.validVersion(importedVersion) &&
                GrindingDatabaseValidator.compareVersions(
                      snapshot.databaseVersion,
                      importedVersion,
                    ) >
                    0)) {
          await _repository.importSnapshot(
            snapshot,
            origin: 'seed',
            expectedRevision: meta['importedAt'],
            checkRevision: true,
          );
        }
      }
      await _reload();
    } catch (error) {
      _error = 'Không thể tải dữ liệu Máy nghiền: $error';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> _reload() async {
    final series = await _repository.getAllSeries();
    final machines = await _repository.getAllMachines();
    _series = series;
    _machines = machines;
    _initialized = true;
  }

  Future<void> _ready() async {
    if (!_initialized) await loadHome();
    if (!_initialized) {
      throw StateError(_error ?? 'Chưa tải được dữ liệu Máy nghiền.');
    }
  }

  Future<Map<String, String?>> getImportMetadata() async {
    await _ready();
    return _repository.getImportMetadata();
  }

  Future<GrindingImportPreview> previewImport(
    String fileName,
    Uint8List bytes,
  ) => _serial(() async {
    if (!_initialized) await _loadHome();
    if (!_initialized) throw StateError(_error ?? 'Chưa tải được database.');
    GrindingImportReport report;
    final name = fileName.toLowerCase();
    if (name.endsWith('.xlsx')) {
      report = await compute(GrindingExcelParser.parse, bytes);
    } else if (name.endsWith('.json')) {
      try {
        report = await compute(
          GrindingMachineImporter.inspect,
          utf8.decode(bytes),
        );
      } on FormatException {
        report = GrindingImportReport(
          issues: const [
            GrindingImportIssue('JSON', 'File phải sử dụng mã hóa UTF-8.'),
          ],
        );
      }
    } else {
      report = GrindingImportReport(
        issues: const [
          GrindingImportIssue('File', 'Chỉ hỗ trợ .xlsx và .json.'),
        ],
      );
    }
    final meta = await _repository.getImportMetadata();
    final snapshot = report.snapshot;
    final issues = [...report.issues];
    final currentVersion = meta['databaseVersion'];
    if (snapshot != null && currentVersion != null) {
      if (!GrindingDatabaseValidator.validVersion(currentVersion)) {
        issues.add(
          const GrindingImportIssue(
            'Phiên bản',
            'Database hiện tại có version không hợp lệ.',
          ),
        );
      } else {
        final comparison = GrindingDatabaseValidator.compareVersions(
          snapshot.databaseVersion,
          currentVersion,
        );
        if (comparison < 0) {
          issues.add(
            GrindingImportIssue(
              'Phiên bản',
              'File ${snapshot.databaseVersion} cũ hơn database $currentVersion; không cho phép hạ phiên bản.',
            ),
          );
        } else if (comparison == 0) {
          issues.add(
            const GrindingImportIssue(
              'Phiên bản',
              'File cùng phiên bản hiện tại; xác nhận sẽ thay thế toàn bộ catalog bằng nội dung file.',
              isError: false,
            ),
          );
        }
      }
    }
    final old = {
      for (final m in await _repository.getAllMachines(activeOnly: false))
        m.machineId: m,
    };
    final added = <String>[];
    final updated = <String>[];
    final removed = <String>[];
    if (snapshot != null) {
      final ids = snapshot.machines.map((m) => m.machineId).toSet();
      for (final m in snapshot.machines) {
        final previous = old[m.machineId];
        if (previous == null) {
          added.add(m.machineId);
        } else {
          // Bao gồm EAV; bỏ khóa SQLite tự sinh khi so sánh.
          List<String> specs(Iterable<GrindingExtraSpec> values) =>
              values.map((v) {
                final row = v.toJson()..remove('id');
                return jsonEncode(row);
              }).toList()..sort();
          final oldSpecs = specs(await _repository.getExtraSpecs(m.machineId));
          final newSpecs = specs(
            snapshot.extraSpecs.where((v) => v.machineId == m.machineId),
          );
          if (jsonEncode(previous.toJson()) != jsonEncode(m.toJson()) ||
              !listEquals(oldSpecs, newSpecs)) {
            updated.add(m.machineId);
          }
        }
      }
      removed.addAll(old.keys.where((id) => !ids.contains(id)));
      if (removed.isNotEmpty) {
        issues.add(
          GrindingImportIssue(
            'Model không còn trong file',
            '${removed.length} model sẽ bị loại khỏi catalog khi thay thế. Xem danh sách trước khi xác nhận.',
            isError: false,
          ),
        );
      }
    }
    return GrindingImportPreview(
      fileName: fileName,
      report: GrindingImportReport(snapshot: snapshot, issues: issues),
      revision: meta['importedAt'],
      currentVersion: currentVersion,
      added: List.unmodifiable(added),
      updated: List.unmodifiable(updated),
      removed: List.unmodifiable(removed),
    );
  });

  Future<void> applyImport(GrindingImportPreview preview) => _serial(() async {
    if (!preview.report.canImport) {
      throw StateError('File chưa vượt qua kiểm tra dữ liệu.');
    }
    _isLoading = true;
    _error = null;
    _notify();
    try {
      await _repository.importSnapshot(
        preview.report.snapshot!,
        origin: 'file',
        fileName: preview.fileName,
        expectedRevision: preview.revision,
        checkRevision: true,
      );
      await _reload();
    } catch (error) {
      _error = 'Không thể hoàn tất cập nhật: $error';
      rethrow;
    } finally {
      _isLoading = false;
      _notify();
    }
  });

  Future<List<GrindingMachine>> search(String query) async {
    await _ready();
    return _repository.searchMachines(query);
  }

  Future<GrindingMachine?> getMachine(String machineId) async {
    await _ready();
    return _repository.getMachineById(machineId);
  }

  Future<GrindingSeries?> getSeries(String seriesCode) async {
    await _ready();
    return _repository.getSeriesByCode(seriesCode);
  }

  Future<List<GrindingExtraSpec>> getExtraSpecs(String machineId) async {
    await _ready();
    return _repository.getExtraSpecs(machineId);
  }

  Future<List<GrindingMaterial>> getAllMaterials() async {
    await _ready();
    return _repository.getAllMaterials();
  }

  Future<List<String>> getAllDistinctTags() async {
    await _ready();
    return _repository.getAllDistinctTags();
  }

  /// Toàn bộ Selection Tags gộp theo seriesCode (mục 3, 9 Phase 6) — proxy
  /// 1:1 sang method Repository sẵn có (đã dùng nội bộ trong [recommend]),
  /// để màn hình danh sách dựng chỉ mục search/filter 1 lần trong RAM thay
  /// vì gọi lại `getSelectionTags` cho từng series.
  Future<Map<String, Set<String>>> getAllSelectionTagsGrouped() async {
    await _ready();
    return _repository.getAllSelectionTagsGrouped();
  }

  /// Danh sách seriesCode tương thích với [materialId] theo dữ liệu ĐÃ XÁC
  /// MINH (`status == 'Verified'`) trong Material_Series_Map — không suy
  /// đoán tương thích cho nguyên liệu chưa có dòng map nào.
  Future<Set<String>> getCompatibleSeriesCodes(String materialId) async {
    await _ready();
    final maps = await _repository.getMaterialSeriesMapFor(materialId);
    return maps.where((m) => m.isVerified).map((m) => m.seriesCode).toSet();
  }

  /// Toàn bộ dòng Material_Series_Map (mọi status) cho [materialId] — proxy
  /// 1:1 sang Repository. Khác [getCompatibleSeriesCodes] (đã rút gọn thành
  /// tập hợp seriesCode "tương thích"), dùng cho
  /// GrindingMachineSelectionService (Phase 6) vì cần biết cả dấu
  /// `scoreAdjustment` để phân biệt MATCH/NOT_MATCH thay vì chỉ 1 tập hợp.
  Future<List<GrindingMaterialSeriesMap>> getMaterialSeriesMapFor(
    String materialId,
  ) async {
    await _ready();
    return _repository.getMaterialSeriesMapFor(materialId);
  }

  /// Tập hợp toàn bộ dữ liệu cần cho Selection Engine (mục 7-8) rồi chấm
  /// điểm — trả về tối đa 3 đề xuất tốt nhất, danh sách rỗng nếu không có
  /// model nào đạt các hard filter (capacity/fineness/input/tag).
  Future<List<GrindingRecommendation>> recommend(
    GrindingSelectionRequest request, {
    required String materialName,
  }) async {
    await _ready();
    final maps = await _repository.getMaterialSeriesMapFor(request.materialId);
    final materialScoreAdjustments = {
      for (final m in maps.where((m) => m.isVerified))
        m.seriesCode: m.scoreAdjustment,
    };
    final seriesTags = await _repository.getAllSelectionTagsGrouped();
    final aiConfig = await _repository.getAllAiConfig();
    final weights = {
      for (final c in aiConfig)
        if (c.asNum != null) c.key: c.asNum!,
    };
    final seriesByCode = {for (final s in _series) s.seriesCode: s};

    return GrindingSelectionEngine.recommend(
      context: GrindingSelectionContext(
        machines: _machines,
        seriesByCode: seriesByCode,
        seriesTags: seriesTags,
        materialScoreAdjustments: materialScoreAdjustments,
        materialName: materialName,
        weights: weights,
      ),
      request: request,
    );
  }
}
