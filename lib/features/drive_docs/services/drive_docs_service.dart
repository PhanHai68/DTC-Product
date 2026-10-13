import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../document_library_catalog.dart';
import '../drive_docs_config.dart';
import '../models/drive_item.dart';
import 'drive_doc_cache.dart';

class DriveDocsException implements Exception {
  const DriveDocsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Đọc thư viện tài liệu trên Google Drive (thư mục chia sẻ công khai + API
/// key).
///
/// Danh sách thư mục được lưu vào SharedPreferences và nội dung PDF/ảnh vào
/// [DriveDocCache], nên tài liệu đã mở một lần vẫn xem được khi mất mạng.
class DriveDocsService {
  DriveDocsService({
    http.Client? client,
    DriveDocCache? cache,
    String apiKey = driveDocsApiKey,
    this.rootFolderId = driveDocsRootFolderId,
  }) : _client = client ?? http.Client(),
       _cache = cache ?? DriveDocCache(),
       _apiKey = apiKey;

  static final DriveDocsService instance = DriveDocsService();

  static const _host = 'www.googleapis.com';
  static const _prefsPrefix = 'drive_docs_folder_';
  static const _timeout = Duration(seconds: 20);
  static const _downloadTimeout = Duration(minutes: 3);

  /// Giới hạn số thư mục duyệt khi tìm file theo tên.
  static const _maxFoldersToSearch = 200;

  final http.Client _client;
  final DriveDocCache _cache;
  final String _apiKey;
  final String rootFolderId;
  final _folders = <String, List<DriveItem>>{};

  bool get isConfigured => _apiKey.isNotEmpty && rootFolderId.isNotEmpty;

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const DriveDocsException(
        'Thư viện tài liệu Google Drive chưa được cấu hình.',
      );
    }
  }

  /// Thư mục con + file trong [folderId], thư mục xếp trước.
  /// Lỗi mạng → trả danh sách đã lưu lần trước (nếu có).
  Future<List<DriveItem>> listFolder(
    String folderId, {
    bool refresh = false,
  }) async {
    _ensureConfigured();
    if (!refresh && _folders[folderId] != null) return _folders[folderId]!;
    final prefs = await SharedPreferences.getInstance();
    try {
      final items = await _fetchFolder(folderId);
      _folders[folderId] = items;
      await prefs.setString(
        '$_prefsPrefix$folderId',
        jsonEncode([for (final item in items) item.toJson()]),
      );
      return items;
    } on Object catch (error) {
      final saved = prefs.getString('$_prefsPrefix$folderId');
      if (saved == null) throw _friendlyError(error, 'danh sách tài liệu');
      debugPrint('DriveDocs: dùng danh sách đã lưu cho $folderId ($error)');
      final items = [
        for (final json in jsonDecode(saved) as List)
          DriveItem.fromJson(json as Map<String, dynamic>),
      ];
      return _folders[folderId] = items;
    }
  }

  Future<List<DriveItem>> _fetchFolder(String folderId) async {
    final items = <DriveItem>[];
    String? pageToken;
    do {
      final uri = Uri.https(_host, '/drive/v3/files', {
        'q': "'$folderId' in parents and trashed = false",
        'fields':
            'nextPageToken, files(id, name, mimeType, size, modifiedTime)',
        'pageSize': '1000',
        'key': _apiKey,
        'pageToken': ?pageToken,
      });
      final response = await _client.get(uri).timeout(_timeout);
      _checkStatus(response);
      // Giải mã UTF-8 trực tiếp: tên tiếng Việt sẽ lỗi nếu thiếu charset.
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      for (final json in body['files'] as List? ?? const []) {
        final item = DriveItem.fromJson(json as Map<String, dynamic>);
        if (item.mimeType != DriveItem.shortcutMimeType) items.add(item);
      }
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null);
    items.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  /// Đi lần lượt từ thư mục gốc theo [path]; mỗi cấp là danh sách tên chấp
  /// nhận được, so khớp bằng [normalizeDriveName]. Trả null nếu thư mục chưa
  /// được tạo trên Drive.
  Future<String?> findFolderByPath(
    List<List<String>> path, {
    bool refresh = false,
  }) async {
    _ensureConfigured();
    var folderId = rootFolderId;
    for (final names in path) {
      final wanted = names.map(normalizeDriveName).toSet();
      final items = await listFolder(folderId, refresh: refresh);
      final match = items.where(
        (item) =>
            item.isFolder && wanted.contains(normalizeDriveName(item.name)),
      );
      if (match.isEmpty) return null;
      folderId = match.first.id;
    }
    return folderId;
  }

  /// Tìm file PDF theo đúng tên (không phân biệt hoa thường) trong toàn bộ
  /// cây thư mục gốc — dùng cho tài liệu cố định mà các màn hình trỏ tới.
  Future<DriveItem> findPdfByName(String name) async {
    _ensureConfigured();
    final target = name.toLowerCase();
    final queue = [rootFolderId];
    final visited = <String>{};
    Object? firstError;
    while (queue.isNotEmpty && visited.length < _maxFoldersToSearch) {
      final folderId = queue.removeAt(0);
      if (!visited.add(folderId)) continue;
      final List<DriveItem> items;
      try {
        items = await listFolder(folderId);
      } on Object catch (error) {
        // Thư mục gốc lỗi thì không tìm tiếp được; thư mục con lỗi thì bỏ qua.
        if (folderId == rootFolderId) rethrow;
        firstError ??= error;
        continue;
      }
      for (final item in items) {
        if (item.isPdf && item.name.toLowerCase() == target) return item;
        if (item.isFolder) queue.add(item.id);
      }
    }
    if (firstError != null) throw firstError;
    throw DriveDocsException('Chưa có tài liệu "$name" trên Google Drive.');
  }

  /// Link tải trực tiếp nội dung file — dùng để phát video dạng stream.
  Uri mediaUri(DriveItem item) => Uri.https(
    _host,
    '/drive/v3/files/${item.id}',
    {'alt': 'media', 'key': _apiKey},
  );

  /// Nội dung file (PDF, ảnh): lấy từ bộ đệm nếu đúng phiên bản, nếu không
  /// thì tải về. Lỗi mạng → dùng bản đã lưu trước đó (có thể cũ hơn).
  Future<Uint8List> loadFile(DriveItem item) async {
    _ensureConfigured();
    final cached = await _cache.read(item.id, item.version);
    if (cached != null) return cached;
    try {
      final response = await _client
          .get(mediaUri(item))
          .timeout(_downloadTimeout);
      _checkStatus(response);
      final bytes = response.bodyBytes;
      try {
        await _cache.write(item.id, item.version, bytes);
      } on Object catch (error) {
        // Không lưu được bộ đệm vẫn mở được tài liệu lần này.
        debugPrint('DriveDocs: không lưu được bộ đệm ${item.name}: $error');
      }
      return bytes;
    } on Object catch (error) {
      final stale = await _cache.readAny(item.id);
      if (stale != null) return stale;
      throw _friendlyError(error, 'tài liệu "${item.name}"');
    }
  }

  Future<Uint8List> loadPdfByName(String name) async =>
      loadFile(await findPdfByName(name));

  void _checkStatus(http.Response response) {
    if (response.statusCode == 200) return;
    throw _DriveHttpException(response.statusCode, response.body);
  }

  DriveDocsException _friendlyError(Object error, String what) {
    if (error is DriveDocsException) return error;
    if (error is _DriveHttpException) {
      debugPrint('DriveDocs HTTP ${error.statusCode}: ${error.body}');
      if (error.statusCode == 404) {
        return DriveDocsException(
          'Không tìm thấy $what trên Google Drive. '
          'Kiểm tra thư mục đã chia sẻ "Bất kỳ ai có đường liên kết".',
        );
      }
      if (error.statusCode == 400 || error.statusCode == 403) {
        return const DriveDocsException(
          'Google Drive từ chối truy cập. Kiểm tra API key và quyền chia sẻ '
          'thư mục tài liệu.',
        );
      }
      return DriveDocsException(
        'Google Drive đang lỗi (mã ${error.statusCode}). Vui lòng thử lại sau.',
      );
    }
    return DriveDocsException(
      'Không tải được $what. Kiểm tra kết nối mạng rồi thử lại.',
    );
  }
}

class _DriveHttpException implements Exception {
  const _DriveHttpException(this.statusCode, this.body);
  final int statusCode;
  final String body;
  @override
  String toString() => 'HTTP $statusCode';
}
