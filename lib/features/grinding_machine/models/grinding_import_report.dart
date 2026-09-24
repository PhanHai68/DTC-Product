import 'grinding_database_snapshot.dart';

class GrindingImportIssue {
  const GrindingImportIssue(this.location, this.message, {this.isError = true});
  final String location;
  final String message;
  final bool isError;

  @override
  String toString() => '$location: $message';
}

class GrindingImportReport {
  GrindingImportReport({
    this.snapshot,
    Iterable<GrindingImportIssue> issues = const [],
  }) : issues = List.unmodifiable(issues);

  final GrindingDatabaseSnapshot? snapshot;
  final List<GrindingImportIssue> issues;
  bool get hasErrors => issues.any((v) => v.isError);
  bool get canImport => snapshot != null && !hasErrors;
}

/// Bản xem trước gắn với revision đang lưu, tránh ghi đè một lần import khác.
class GrindingImportPreview {
  const GrindingImportPreview({
    required this.fileName,
    required this.report,
    required this.revision,
    required this.currentVersion,
    required this.added,
    required this.updated,
    required this.removed,
  });

  final String fileName;
  final GrindingImportReport report;
  final String? revision;
  final String? currentVersion;
  final List<String> added;
  final List<String> updated;
  final List<String> removed;
}
