import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sample_record.dart';
import 'sample_file_storage.dart'
    if (dart.library.io) 'sample_file_storage_io.dart'
    if (dart.library.js_interop) 'sample_file_storage_web.dart';

/// Boundary kept separate so a cloud-backed sync repository can be added later
/// without changing the form, calculations, or PDF generation.
abstract interface class SampleRecordRepository {
  Future<SampleRecordData?> loadDraft();
  Future<void> saveDraft(SampleRecordData record);
  Future<void> clearDraft();
  Future<String> persistPhoto(
    String sourcePath,
    SampleStreamType type, {
    String? slot,
    List<int>? bytes,
  });
  Future<Uint8List?> readPhoto(String storedPath);
  Future<String> savePdf(List<int> bytes, String fileName);
}

class LocalSampleRecordRepository implements SampleRecordRepository {
  static const _draftKey = 'sample_record_draft_v1';

  @override
  Future<SampleRecordData?> loadDraft() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_draftKey);
    if (value == null || value.isEmpty) return null;
    try {
      return SampleRecordData.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDraft(SampleRecordData record) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_draftKey, jsonEncode(record.toJson()));
  }

  @override
  Future<void> clearDraft() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_draftKey);
  }

  @override
  Future<String> persistPhoto(
    String sourcePath,
    SampleStreamType type, {
    String? slot,
    List<int>? bytes,
  }) async {
    final extension = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final fileName =
        '${type.name}_${slot ?? 'overview'}_'
        '${DateTime.now().millisecondsSinceEpoch}$extension';
    return persistSamplePhoto(
      sourcePath: sourcePath,
      fileName: fileName,
      bytes: bytes,
    );
  }

  @override
  Future<Uint8List?> readPhoto(String storedPath) =>
      readSamplePhoto(storedPath);

  @override
  Future<String> savePdf(List<int> bytes, String fileName) =>
      saveSamplePdf(bytes: bytes, fileName: fileName);
}
