import 'package:sqflite/sqflite.dart';

import '../data/fault_bank_database.dart';
import '../models/engineer_profile.dart';
import '../models/fault_machine_model.dart';
import '../models/fault_record.dart';
import '../utils/fault_groups.dart';
import '../utils/fault_ids.dart';
import '../utils/vietnamese_fold.dart';

/// Đọc/ghi SQLite của Ngân hàng lỗi. Toàn bộ offline.
///
/// Quy tắc dữ liệu:
/// - Mã bản ghi `<mã kỹ sư>-<uuid>` tạo 1 lần, không đổi.
/// - Mỗi lần sửa (kể cả xóa) cập nhật `updated_at` — để khi gộp file, bản mới
///   hơn thắng và việc xóa cũng lan sang file chung.
/// - Xóa = đặt `is_deleted = 1`, không xóa dòng.
class FaultBankRepository {
  FaultBankRepository({FaultBankDatabase? database, DateTime Function()? clock})
    : _database = database ?? FaultBankDatabase.instance,
      _clock = clock ?? DateTime.now;

  final FaultBankDatabase _database;
  final DateTime Function() _clock;

  String _now() => _clock().toUtc().toIso8601String();

  // ---------------------------------------------------------------- Hồ sơ

  Future<EngineerProfile?> getProfile() async {
    final db = await _database.database;
    final rows = await db.query('profile', where: 'id = 1');
    return rows.isEmpty ? null : EngineerProfile.fromMap(rows.first);
  }

  /// Lưu tên + mã kỹ sư. Không truyền [engineerCode] thì giữ mã đang có,
  /// chưa có thì tự sinh (mã kỹ sư không còn hiện trên giao diện). Đổi mã
  /// về sau KHÔNG đổi mã các bản ghi đã tạo.
  Future<EngineerProfile> saveProfile({
    required String engineerName,
    String? engineerCode,
  }) async {
    final name = engineerName.trim();
    final code = engineerCode != null
        ? FaultIds.normalizeEngineerCode(engineerCode)
        : (await getProfile())?.engineerCode ?? FaultIds.newEngineerCode();
    if (name.isEmpty) throw ArgumentError('Tên kỹ sư không được để trống');
    if (!FaultIds.isValidEngineerCode(code)) {
      throw ArgumentError('Mã kỹ sư không hợp lệ');
    }
    final db = await _database.database;
    final now = _now();
    final updated = await db.update('profile', {
      'engineer_name': name,
      'engineer_code': code,
      'updated_at': now,
    }, where: 'id = 1');
    if (updated == 0) {
      await db.insert('profile', {
        'id': 1,
        'engineer_name': name,
        'engineer_code': code,
        'created_at': now,
        'updated_at': now,
      });
    }
    return (await getProfile())!;
  }

  // ------------------------------------------------------------ Dòng máy

  Future<List<FaultMachineModel>> listMachineModels() async {
    final db = await _database.database;
    final rows = await db.query(
      'machine_models',
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(FaultMachineModel.fromMap).toList();
  }

  /// Dòng máy đã có với tên gần giống (bỏ dấu, bỏ khoảng trắng/ký tự đặc
  /// biệt) — để cảnh báo trước khi thêm trùng ("SC16Pro" ≈ "SC16 Pro").
  Future<FaultMachineModel?> findSimilarMachineModel(
    String name, {
    String? excludeId,
  }) async {
    final key = VietnameseFold.compactKey(name);
    if (key.isEmpty) return null;
    final db = await _database.database;
    final rows = await db.query(
      'machine_models',
      where: excludeId == null ? 'name_key = ?' : 'name_key = ? AND id != ?',
      whereArgs: excludeId == null ? [key] : [key, excludeId],
      limit: 1,
    );
    return rows.isEmpty ? null : FaultMachineModel.fromMap(rows.first);
  }

  Future<FaultMachineModel> addMachineModel({
    required String name,
    required String engineerCode,
    String? manufacturer,
    String? equipmentGroup,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Tên model máy không được để trống');
    }
    final db = await _database.database;
    final now = _now();
    final model = FaultMachineModel(
      id: FaultIds.newMachineModelId(engineerCode),
      name: trimmed,
      manufacturer: _clean(manufacturer),
      equipmentGroup: _clean(equipmentGroup),
    );
    await db.insert('machine_models', {
      'id': model.id,
      'name': model.name,
      'manufacturer': model.manufacturer,
      'equipment_group': model.equipmentGroup,
      'name_key': VietnameseFold.compactKey(model.name),
      'created_at': now,
      'updated_at': now,
    });
    return model;
  }

  /// Sửa dòng máy; tên mới được đánh lại chỉ mục tìm kiếm cho các bản ghi
  /// thuộc dòng máy đó.
  Future<void> updateMachineModel(FaultMachineModel model) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.update(
        'machine_models',
        {
          'name': model.name.trim(),
          'manufacturer': _clean(model.manufacturer),
          'equipment_group': _clean(model.equipmentGroup),
          'name_key': VietnameseFold.compactKey(model.name),
          'updated_at': _now(),
        },
        where: 'id = ?',
        whereArgs: [model.id],
      );
      final ids = await txn.query(
        'fault_records',
        columns: ['id'],
        where: 'machine_model_id = ? AND is_deleted = 0',
        whereArgs: [model.id],
      );
      for (final row in ids) {
        await _reindex(txn, row['id'] as String);
      }
    });
  }

  /// Số bản ghi đang tham chiếu dòng máy (tính cả bản ghi đã xóa bằng cờ, vì
  /// dòng vẫn còn trong bảng) — chỉ xóa được dòng máy khi bằng 0.
  Future<int> countRecordsOfModel(String machineModelId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM fault_records WHERE machine_model_id = ?',
      [machineModelId],
    );
    return result.first['c'] as int;
  }

  Future<void> deleteMachineModel(String machineModelId) async {
    if (await countRecordsOfModel(machineModelId) > 0) {
      throw StateError('Model máy đang có bản ghi, không xóa được.');
    }
    final db = await _database.database;
    await db.delete(
      'machine_models',
      where: 'id = ?',
      whereArgs: [machineModelId],
    );
  }

  // ------------------------------------------------------------- Nhóm lỗi

  /// Nhóm lỗi tự thêm (ngoài danh sách cố định) đã dùng trong bản ghi.
  Future<List<String>> customFaultGroups() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT fault_group FROM fault_records '
      'WHERE is_deleted = 0 AND fault_group IS NOT NULL',
    );
    final groups =
        rows
            .map((r) => r['fault_group'] as String)
            .where(
              (g) => !FaultGroups.fixed.contains(g) && g != FaultGroups.other,
            )
            .toList()
          ..sort();
    return groups;
  }

  // ---------------------------------------------------------------- Ghi

  /// Tạo bản ghi mới. [recordId] cho phép dùng mã đã sinh sẵn (form sinh
  /// trước để đặt tên file ảnh); để trống thì tự tạo.
  Future<String> createRecord(
    FaultRecordDraft draft, {
    required EngineerProfile author,
    String? recordId,
  }) async {
    _validate(draft);
    final id = recordId ?? FaultIds.newRecordId(author.engineerCode);
    final db = await _database.database;
    final now = _now();
    await db.transaction((txn) async {
      await txn.insert('fault_records', {
        'id': id,
        ..._recordColumns(draft),
        'author_code': author.engineerCode,
        'author_name': author.engineerName,
        'source': FaultRecordSource.mine.value,
        'created_at': now,
        'updated_at': now,
        'is_deleted': 0,
      });
      await _writeChildren(txn, id, draft, now);
      await _reindex(txn, id);
    });
    return id;
  }

  /// Sửa bản ghi (chỉ bản ghi "của tôi"). Trả về tên file các ảnh đã bị gỡ
  /// khỏi bản ghi để xóa file.
  Future<List<String>> updateRecord(String id, FaultRecordDraft draft) async {
    _validate(draft);
    final db = await _database.database;
    final removedFiles = <String>[];
    await db.transaction((txn) async {
      final existing = await txn.query(
        'fault_records',
        columns: ['source'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
      );
      if (existing.isEmpty) throw StateError('Không tìm thấy bản ghi $id');
      if (existing.first['source'] != FaultRecordSource.mine.value) {
        throw StateError('Bản ghi nhập vào chỉ được xem, không sửa được.');
      }
      final now = _now();
      await txn.update(
        'fault_records',
        {..._recordColumns(draft), 'updated_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );

      final keepIds = {
        ...draft.photos.map((p) => p.id),
        for (final s in draft.steps)
          if (s.photo != null) s.photo!.id,
      };
      final oldPhotos = await txn.query(
        'attachments',
        where: 'record_id = ?',
        whereArgs: [id],
      );
      for (final row in oldPhotos) {
        if (!keepIds.contains(row['id'])) {
          removedFiles.add(row['file_name'] as String);
        }
      }
      await txn.delete(
        'solution_steps',
        where: 'record_id = ?',
        whereArgs: [id],
      );
      await txn.delete('attachments', where: 'record_id = ?', whereArgs: [id]);
      await _writeChildren(txn, id, draft, now);
      await _reindex(txn, id);
    });
    return removedFiles;
  }

  /// Xóa bằng cờ: giữ dòng, đặt `is_deleted = 1` và cập nhật ngày cập nhật.
  Future<void> softDeleteRecord(String id) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'fault_records',
        columns: ['seq', 'source'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
      );
      if (rows.isEmpty) return;
      if (rows.first['source'] != FaultRecordSource.mine.value) {
        throw StateError('Bản ghi nhập vào chỉ được xem, không xóa được.');
      }
      await txn.update(
        'fault_records',
        {'is_deleted': 1, 'updated_at': _now()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _removeFromIndex(txn, rows.first['seq'] as int);
    });
  }

  // ---------------------------------------------------------------- Đọc

  /// Chi tiết bản ghi; bản ghi đã xóa trả về null.
  Future<FaultRecord?> getRecord(String id) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT r.*, m.name AS machine_name FROM fault_records r '
      'LEFT JOIN machine_models m ON m.id = r.machine_model_id '
      'WHERE r.id = ? AND r.is_deleted = 0',
      [id],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    final attachments = (await db.query(
      'attachments',
      where: 'record_id = ?',
      whereArgs: [id],
      orderBy: 'created_at, id',
    )).map(FaultAttachment.fromMap).toList();
    final stepPhotos = {
      for (final a in attachments)
        if (a.stepId != null) a.stepId!: a,
    };
    final steps =
        (await db.query(
          'solution_steps',
          where: 'record_id = ?',
          whereArgs: [id],
          orderBy: 'step_order',
        )).map((s) {
          final stepId = s['id'] as String;
          return SolutionStep(
            id: stepId,
            order: s['step_order'] as int,
            content: s['content'] as String,
            photo: stepPhotos[stepId],
          );
        }).toList();

    return FaultRecord(
      id: r['id'] as String,
      machineModelId: r['machine_model_id'] as String,
      machineModelName: (r['machine_name'] as String?) ?? '—',
      serialNumber: r['serial_number'] as String?,
      errorCode: r['error_code'] as String?,
      faultGroup: r['fault_group'] as String?,
      symptom: r['symptom'] as String,
      cause: r['cause'] as String,
      steps: steps,
      photos: attachments.where((a) => a.stepId == null).toList(),
      parts: r['parts'] as String?,
      tools: r['tools'] as String?,
      durationMinutes: r['duration_minutes'] as int?,
      safetyWarning: r['safety_warning'] as String?,
      authorCode: r['author_code'] as String,
      authorName: r['author_name'] as String,
      source: FaultRecordSource.parse(r['source'] as String?),
      createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(r['updated_at'] as String).toLocal(),
    );
  }

  /// Tra cứu: mọi từ khóa (đã bỏ dấu) đều phải khớp, mỗi từ khớp theo tiền tố
  /// ("dong co" ra "động cơ"). Không có từ khóa thì liệt kê mới nhất trước.
  Future<List<FaultRecordSummary>> search(
    FaultSearchFilter filter, {
    int limit = 200,
  }) async {
    final where = <String>['r.is_deleted = 0'];
    final args = <Object?>[];
    if (filter.machineModelId != null) {
      where.add('r.machine_model_id = ?');
      args.add(filter.machineModelId);
    }
    if (filter.faultGroup != null) {
      where.add('r.fault_group = ?');
      args.add(filter.faultGroup);
    }
    final code = filter.errorCode?.trim() ?? '';
    if (code.isNotEmpty) {
      where.add('r.error_code LIKE ? COLLATE NOCASE');
      args.add('%$code%');
    }
    final tokens = VietnameseFold.tokens(filter.query);
    if (tokens.isNotEmpty) {
      final (clause, clauseArgs) = await _textClause(tokens, matchAll: true);
      where.add(clause);
      args.addAll(clauseArgs);
    }
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT r.id, r.error_code, r.fault_group, r.symptom, r.updated_at, '
      'r.source, m.name AS machine_name FROM fault_records r '
      'LEFT JOIN machine_models m ON m.id = r.machine_model_id '
      'WHERE ${where.join(' AND ')} '
      'ORDER BY r.updated_at DESC LIMIT ?',
      [...args, limit],
    );
    return rows.map(FaultRecordSummary.fromMap).toList();
  }

  /// Bản ghi đầy đủ (kèm bước xử lý) khớp [filter], không giới hạn số
  /// lượng — dùng để xuất Excel.
  Future<List<FaultRecord>> recordsForExport(FaultSearchFilter filter) async {
    final summaries = await search(filter, limit: -1);
    final records = <FaultRecord>[];
    for (final s in summaries) {
      final record = await getRecord(s.id);
      if (record != null) records.add(record);
    }
    return records;
  }

  /// Bản ghi có triệu chứng tương tự (≥ 1/2 số từ khóa trùng) — hiện khi
  /// đang nhập để tránh ghi trùng. Ưu tiên cùng dòng máy.
  Future<List<FaultRecordSummary>> findSimilar(
    String symptom, {
    String? machineModelId,
    String? excludeId,
    int limit = 5,
  }) async {
    final tokens = VietnameseFold.tokens(symptom)
        .where((t) => t.length >= 2)
        .toSet()
        .toList();
    if (tokens.length < 2) return const [];

    final (clause, clauseArgs) = await _textClause(tokens, matchAll: false);
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT r.id, r.error_code, r.fault_group, r.symptom, r.updated_at, '
      'r.source, r.machine_model_id, m.name AS machine_name '
      'FROM fault_records r '
      'LEFT JOIN machine_models m ON m.id = r.machine_model_id '
      'WHERE r.is_deleted = 0 AND $clause '
      '${excludeId == null ? '' : 'AND r.id != ?'} '
      'ORDER BY r.updated_at DESC LIMIT 50',
      [...clauseArgs, ?excludeId],
    );

    final scored = <(double, bool, FaultRecordSummary)>[];
    for (final row in rows) {
      final words = VietnameseFold.tokens(row['symptom'] as String);
      final hits = tokens
          .where((t) => words.any((w) => w.startsWith(t)))
          .length;
      final ratio = hits / tokens.length;
      if (ratio < 0.5) continue;
      scored.add((
        ratio,
        row['machine_model_id'] == machineModelId,
        FaultRecordSummary.fromMap(row),
      ));
    }
    scored.sort((a, b) {
      if (a.$2 != b.$2) return a.$2 ? -1 : 1;
      final byRatio = b.$1.compareTo(a.$1);
      if (byRatio != 0) return byRatio;
      return b.$3.updatedAt.compareTo(a.$3.updatedAt);
    });
    return scored.take(limit).map((s) => s.$3).toList();
  }

  // ------------------------------------------------------------- Nội bộ

  /// Điều kiện tìm theo chế độ FTS5 / FTS4 / LIKE. Từ khóa chỉ gồm a-z0-9
  /// (đã qua [VietnameseFold.tokens]) nên an toàn khi ghép vào biểu thức
  /// MATCH.
  Future<(String, List<Object?>)> _textClause(
    List<String> tokens, {
    required bool matchAll,
  }) async {
    final mode = await _database.searchMode();
    if (mode == FaultSearchMode.like) {
      final joiner = matchAll ? ' AND ' : ' OR ';
      return (
        '(${tokens.map((_) => 'r.search_text LIKE ?').join(joiner)})',
        tokens.map((t) => '%$t%').toList(),
      );
    }
    final expression = tokens.map((t) => '$t*').join(matchAll ? ' ' : ' OR ');
    return (
      'r.seq IN (SELECT rowid FROM ${FaultBankDatabase.searchTable} '
          'WHERE ${FaultBankDatabase.searchTable} MATCH ?)',
      [expression],
    );
  }

  /// Ghép toàn bộ nội dung bản ghi (đã bỏ dấu) vào `search_text` và chỉ mục
  /// FTS.
  Future<void> _reindex(DatabaseExecutor txn, String id) async {
    final rows = await txn.rawQuery(
      'SELECT r.*, m.name AS machine_name FROM fault_records r '
      'LEFT JOIN machine_models m ON m.id = r.machine_model_id WHERE r.id = ?',
      [id],
    );
    if (rows.isEmpty) return;
    final r = rows.first;
    final steps = await txn.query(
      'solution_steps',
      columns: ['content'],
      where: 'record_id = ?',
      whereArgs: [id],
      orderBy: 'step_order',
    );
    final text = VietnameseFold.fold(
      [
        r['machine_name'],
        r['error_code'],
        r['fault_group'],
        r['serial_number'],
        r['symptom'],
        r['cause'],
        ...steps.map((s) => s['content']),
        r['parts'],
        r['tools'],
        r['safety_warning'],
      ].whereType<String>().join(' \n '),
    );
    await txn.update(
      'fault_records',
      {'search_text': text},
      where: 'id = ?',
      whereArgs: [id],
    );
    final seq = r['seq'] as int;
    if (await _database.searchMode() == FaultSearchMode.like) return;
    await _removeFromIndex(txn, seq);
    await txn.insert(FaultBankDatabase.searchTable, {
      'rowid': seq,
      'search_text': text,
    });
  }

  Future<void> _removeFromIndex(DatabaseExecutor txn, int seq) async {
    if (await _database.searchMode() == FaultSearchMode.like) return;
    await txn.delete(
      FaultBankDatabase.searchTable,
      where: 'rowid = ?',
      whereArgs: [seq],
    );
  }

  Future<void> _writeChildren(
    DatabaseExecutor txn,
    String recordId,
    FaultRecordDraft draft,
    String now,
  ) async {
    final steps = draft.steps
        .where((s) => s.content.trim().isNotEmpty)
        .toList();
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      await txn.insert('solution_steps', {
        'id': step.id,
        'record_id': recordId,
        'step_order': i + 1,
        'content': step.content.trim(),
      });
      if (step.photo case final photo?) {
        await _insertAttachment(txn, recordId, photo, step.id, now);
      }
    }
    for (final photo in draft.photos) {
      await _insertAttachment(txn, recordId, photo, null, now);
    }
  }

  Future<void> _insertAttachment(
    DatabaseExecutor txn,
    String recordId,
    FaultAttachment photo,
    String? stepId,
    String now,
  ) => txn.insert('attachments', {
    'id': photo.id,
    'record_id': recordId,
    'step_id': stepId,
    'file_name': photo.fileName,
    'caption': _clean(photo.caption),
    'created_at': now,
  });

  Map<String, Object?> _recordColumns(FaultRecordDraft d) => {
    'machine_model_id': d.machineModelId,
    'serial_number': _clean(d.serialNumber),
    'error_code': _clean(d.errorCode),
    'fault_group': d.faultGroup == null || d.faultGroup!.trim().isEmpty
        ? null
        : FaultGroups.normalize(d.faultGroup!),
    'symptom': d.symptom.trim(),
    'cause': d.cause.trim(),
    'parts': _clean(d.parts),
    'tools': _clean(d.tools),
    'duration_minutes': d.durationMinutes,
    'safety_warning': _clean(d.safetyWarning),
  };

  static void _validate(FaultRecordDraft d) {
    if (d.machineModelId.isEmpty) throw ArgumentError('Chưa chọn model máy');
    if (d.symptom.trim().isEmpty) throw ArgumentError('Thiếu mô tả lỗi');
    if (d.cause.trim().isEmpty) throw ArgumentError('Thiếu nguyên nhân');
    if (d.steps.where((s) => s.content.trim().isNotEmpty).isEmpty) {
      throw ArgumentError('Cần ít nhất 1 bước xử lý');
    }
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
