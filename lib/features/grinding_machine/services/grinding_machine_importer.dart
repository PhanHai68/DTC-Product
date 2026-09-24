import 'dart:convert';

import '../models/grinding_database_snapshot.dart';
import '../models/grinding_import_report.dart';
import 'grinding_database_validator.dart';

/// Parse dữ liệu database Máy nghiền từ JSON (đã convert 1 lần từ
/// DTC_Grinding_Machine_Database_AI_Ready.xlsx) thành [GrindingDatabaseSnapshot]
/// để `GrindingMachineRepository.importSnapshot` nạp vào SQLite.
///
/// Chỉ nhận input dạng JSON string (không tự đọc `rootBundle`/file) để có
/// thể unit test thuần Dart, không cần Flutter binding.
abstract final class GrindingMachineImporter {
  static GrindingImportReport inspect(String jsonSource) {
    try {
      final root = jsonDecode(jsonSource.replaceFirst(RegExp('^\uFEFF'), ''));
      if (root is! Map<String, dynamic>) {
        throw const FormatException('Nội dung gốc phải là một đối tượng JSON.');
      }
      return GrindingDatabaseValidator.validate(root);
    } on FormatException catch (error) {
      return GrindingImportReport(
        issues: [
          GrindingImportIssue(
            'JSON',
            'Không đọc được dữ liệu: ${error.message}',
          ),
        ],
      );
    }
  }

  static GrindingDatabaseSnapshot parse(String jsonSource) {
    final report = inspect(jsonSource);
    if (!report.canImport) {
      throw FormatException(report.issues.where((i) => i.isError).join('\n'));
    }
    return report.snapshot!;
  }
}
