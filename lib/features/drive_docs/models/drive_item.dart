/// Một thư mục hoặc file trong thư viện tài liệu Google Drive.
class DriveItem {
  const DriveItem({
    required this.id,
    required this.name,
    required this.mimeType,
    this.size,
    this.modifiedTime,
  });

  static const folderMimeType = 'application/vnd.google-apps.folder';
  static const pdfMimeType = 'application/pdf';
  static const shortcutMimeType = 'application/vnd.google-apps.shortcut';

  final String id;
  final String name;
  final String mimeType;
  final int? size;
  final DateTime? modifiedTime;

  bool get isFolder => mimeType == folderMimeType;
  bool get isPdf => mimeType == pdfMimeType;
  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');

  /// File khác (bản vẽ DWG, Word, Excel, Google Docs…): mở bằng Google Drive.
  bool get opensInDrive => !isFolder && !isPdf && !isImage && !isVideo;

  /// Trang xem file của Google Drive (file đã chia sẻ công khai).
  Uri get driveViewUri => Uri.https('drive.google.com', '/open', {'id': id});

  /// Đổi khi file được thay bản mới trên Drive → bộ đệm tải lại.
  String get version => (modifiedTime?.millisecondsSinceEpoch ?? 0).toString();

  factory DriveItem.fromJson(Map<String, dynamic> json) => DriveItem(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    mimeType: json['mimeType'] as String? ?? '',
    size: int.tryParse('${json['size'] ?? ''}'),
    modifiedTime: DateTime.tryParse(json['modifiedTime'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mimeType': mimeType,
    if (size != null) 'size': '$size',
    if (modifiedTime != null) 'modifiedTime': modifiedTime!.toIso8601String(),
  };
}
