/// Tờ khai (`manifest.json`) nằm trong mỗi file sao lưu dữ liệu.
class BackupManifest {
  const BackupManifest({
    required this.createdAt,
    required this.appVersion,
    required this.appBuild,
    required this.platform,
    required this.documentsPath,
    required this.databaseCount,
    required this.fileCount,
    required this.totalBytes,
    this.accountEmail,
    this.formatVersion = currentFormatVersion,
  });

  static const format = 'dtc-product-backup';
  static const currentFormatVersion = 1;
  static const fileName = 'manifest.json';

  final int formatVersion;
  final DateTime createdAt;
  final String appVersion;

  /// Build number của app tạo file. Không khôi phục vào app có build thấp
  /// hơn vì cơ sở dữ liệu có thể đã ở phiên bản mới hơn app hiểu được.
  final int appBuild;
  final String platform;

  /// Thư mục Documents của máy tạo file — đường dẫn ảnh/tệp lưu trong cơ sở
  /// dữ liệu bắt đầu bằng thư mục này và được đổi sang thư mục của máy mới.
  final String documentsPath;
  final String? accountEmail;
  final int databaseCount;
  final int fileCount;
  final int totalBytes;

  Map<String, Object?> toJson() => {
    'format': format,
    'formatVersion': formatVersion,
    'createdAt': createdAt.toIso8601String(),
    'appVersion': appVersion,
    'appBuild': appBuild,
    'platform': platform,
    'documentsPath': documentsPath,
    'accountEmail': accountEmail,
    'databaseCount': databaseCount,
    'fileCount': fileCount,
    'totalBytes': totalBytes,
  };

  /// Ném [FormatException] nếu không phải tờ khai sao lưu của DTC Product.
  factory BackupManifest.fromJson(Object? json) {
    if (json is! Map || json['format'] != format) {
      throw const FormatException('Không phải file sao lưu của DTC Product.');
    }
    final version = json['formatVersion'];
    if (version is! int || version > currentFormatVersion) {
      throw const FormatException(
        'File sao lưu được tạo bởi phiên bản app mới hơn. Hãy cập nhật app.',
      );
    }
    final createdAt = DateTime.tryParse('${json['createdAt']}');
    final build = json['appBuild'];
    final documentsPath = json['documentsPath'];
    if (createdAt == null || build is! int || documentsPath is! String) {
      throw const FormatException('File sao lưu bị hỏng hoặc thiếu thông tin.');
    }
    int count(String key) => json[key] is int ? json[key] as int : 0;
    return BackupManifest(
      formatVersion: version,
      createdAt: createdAt,
      appVersion: '${json['appVersion'] ?? ''}',
      appBuild: build,
      platform: '${json['platform'] ?? ''}',
      documentsPath: documentsPath,
      accountEmail: json['accountEmail'] as String?,
      databaseCount: count('databaseCount'),
      fileCount: count('fileCount'),
      totalBytes: count('totalBytes'),
    );
  }
}

/// File sao lưu vừa tạo.
class BackupFileInfo {
  const BackupFileInfo({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    required this.manifest,
  });

  final String path;
  final String fileName;
  final int sizeBytes;
  final BackupManifest manifest;
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}
