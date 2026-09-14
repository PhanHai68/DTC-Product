import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sample_record.dart';

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
  });
  Future<String> savePdf(List<int> bytes, String fileName);
}

class LocalSampleRecordRepository implements SampleRecordRepository {
  static const _draftKey = 'sample_record_draft_v1';

  Future<Directory> _featureDirectory(String child) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(root.path, 'DTCProduct', 'LuuMau', child),
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

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
  }) async {
    final directory = await _featureDirectory('Photos');
    final extension = p.extension(sourcePath).isEmpty
        ? '.jpg'
        : p.extension(sourcePath);
    final target = p.join(
      directory.path,
      '${type.name}_${slot ?? 'overview'}_'
      '${DateTime.now().millisecondsSinceEpoch}$extension',
    );
    return (await File(sourcePath).copy(target)).path;
  }

  @override
  Future<String> savePdf(List<int> bytes, String fileName) async {
    final directory = await _featureDirectory('Exports');
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
