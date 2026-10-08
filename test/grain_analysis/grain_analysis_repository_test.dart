import 'package:dtc_product/features/grain_analysis/data/grain_analysis_database.dart';
import 'package:dtc_product/features/grain_analysis/models/analysis_session.dart';
import 'package:dtc_product/features/grain_analysis/models/grain.dart';
import 'package:dtc_product/features/grain_analysis/repositories/grain_analysis_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Grain _grain(String id, {int image = 0, bool removed = false}) => Grain(
  id: id,
  imageIndex: image,
  contour: const [10, 10, 20.25, 10, 20, 15.5, 10.04, 15],
  centroidX: 15,
  centroidY: 12.5,
  areaPx: 55,
  lengthPx: 10,
  widthPx: 5.5,
  lengthMm: 1,
  widthMm: 0.55,
  areaMm2: 0.55,
  meanColorLab: const [80, 1.5, 12],
  removed: removed,
);

AnalysisSession _session(String id, {DateTime? at}) {
  final time = at ?? DateTime(2026, 10, 7, 21, 30);
  return AnalysisSession(
    id: id,
    mode: AnalysisMode.count,
    lotCode: 'LO-01',
    sampleType: SampleType.accept,
    sampleWeightG: 20,
    trayId: 'a4',
    images: const [
      SessionImage(
        fileName: 'x_0.jpg',
        width: 4000,
        height: 3000,
        frameWidth: 2000,
        frameHeight: 2600,
        frameToImage: [1, 0, 5, 0, 1, 6, 0, 0, 1],
        pixelsPerMm: 12.5,
        markersFound: true,
        tiltDegrees: 2.5,
        issues: ['blur'],
        metrics: {'laplacianVariance': 33.0},
        medianAreaPx: 1200,
        edgeCutCount: 1,
        dustCount: 3,
        clusterAreaFraction: 0.01,
      ),
    ],
    grains: [_grain('i0-1'), _grain('i0-2'), _grain('i0-10')],
    results: const [
      ClassResult(
        classId: ClassResult.allId,
        grainCount: 3,
        countPercent: 100,
        areaPercent: 100,
      ),
    ],
    status: SessionStatus.draft,
    algorithmVersion: 'grain-count-1.0.0',
    createdBy: 'QC Hải',
    createdAt: time,
    updatedAt: time,
  );
}

void main() {
  late Database db;
  late GrainAnalysisRepository repo;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await GrainAnalysisDatabase.instance.createSchemaForTesting(db);
    repo = GrainAnalysisRepository(
      database: GrainAnalysisDatabase.forTesting(db),
    );
  });

  tearDown(() => db.close());

  test('lưu và đọc lại đủ dữ liệu phiên (FR-08)', () async {
    await repo.saveSession(_session('s1'));
    final s = (await repo.getSession('s1'))!;

    expect(s.lotCode, 'LO-01');
    expect(s.sampleType, SampleType.accept);
    expect(s.sampleWeightG, 20);
    expect(s.createdBy, 'QC Hải');
    expect(s.algorithmVersion, 'grain-count-1.0.0');
    expect(s.createdAt, DateTime(2026, 10, 7, 21, 30));
    expect(s.imagePaths, ['x_0.jpg']);
    expect(s.pixelsPerMm, 12.5);
    expect(s.poorQuality, isTrue);
    expect(s.images.single.frameToImage, [1, 0, 5, 0, 1, 6, 0, 0, 1]);
    expect(s.images.single.metrics['laplacianVariance'], 33.0);
    // Thứ tự hạt ổn định theo số (i0-10 sau i0-2).
    expect(s.grains.map((g) => g.id), ['i0-1', 'i0-2', 'i0-10']);
    final g = s.grains.first;
    expect(g.contour, [10, 10, 20.3, 10, 20, 15.5, 10, 15]);
    expect(g.meanColorLab, [80, 1.5, 12]);
    expect(g.lengthMm, 1);
    expect(s.results.single.grainCount, 3);
  });

  test('sửa tay: cập nhật hạt, xóa hạt thêm tay, ghi kết quả mới', () async {
    final s = _session('s1');
    await repo.saveSession(s);
    final manual = Grain(
      id: 'i0-m1',
      contour: const [1, 1, 2, 2, 1, 2],
      centroidX: 1,
      centroidY: 1,
      areaPx: 10,
      source: GrainSource.manual,
    );
    final edited = s.copyWith(
      grains: [...s.grains, manual],
      results: const [
        ClassResult(
          classId: ClassResult.allId,
          grainCount: 4,
          countPercent: 100,
          areaPercent: 100,
        ),
      ],
    );
    await repo.saveEdits(edited, upserted: [manual]);
    await repo.saveEdits(
      edited.copyWith(status: SessionStatus.confirmed),
      upserted: [s.grains.first.copyWith(removed: true)],
      deletedIds: ['i0-m1'],
    );
    final loaded = (await repo.getSession('s1'))!;
    expect(loaded.grains.map((g) => g.id), ['i0-1', 'i0-2', 'i0-10']);
    expect(loaded.grains.first.removed, isTrue);
    expect(loaded.status, SessionStatus.confirmed);
    expect(loaded.results.single.grainCount, 4);
  });

  test('danh sách phiên mới nhất trước, kèm kết quả; xóa phiên', () async {
    await repo.saveSession(_session('old', at: DateTime(2026, 10, 1)));
    await repo.saveSession(_session('new', at: DateTime(2026, 10, 7)));
    final list = await repo.listSessions();
    expect(list.map((s) => s.id), ['new', 'old']);
    expect(list.first.resultOf(ClassResult.allId)!.grainCount, 3);
    expect(list.first.poorQuality, isTrue);

    await repo.deleteSession('old');
    expect((await repo.listSessions()).map((s) => s.id), ['new']);
    expect(await repo.getSession('old'), isNull);
    final orphan = await db.query(
      'grains',
      where: 'session_id = ?',
      whereArgs: ['old'],
    );
    expect(orphan, isEmpty);
  });

  test('cài đặt người thực hiện', () async {
    expect(await repo.getSetting(GrainAnalysisRepository.operatorKey), isNull);
    await repo.setSetting(GrainAnalysisRepository.operatorKey, 'Hải');
    await repo.setSetting(GrainAnalysisRepository.operatorKey, 'Hải QC');
    expect(
      await repo.getSetting(GrainAnalysisRepository.operatorKey),
      'Hải QC',
    );
  });

  test('mã hóa đường viền gọn và đọc lại đúng', () {
    const pts = [1.0, 2.0, 3.25, 4.75, 100.04, 0.0];
    final text = GrainAnalysisRepository.encodeContour(pts);
    expect(text, '1,2 3.3,4.8 100,0');
    expect(GrainAnalysisRepository.decodeContour(text), [
      1,
      2,
      3.3,
      4.8,
      100,
      0,
    ]);
    expect(GrainAnalysisRepository.decodeContour(''), isEmpty);
  });
}
