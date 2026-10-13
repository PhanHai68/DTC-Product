import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dtc_product/features/drive_docs/models/drive_item.dart';
import 'package:dtc_product/features/drive_docs/services/drive_doc_cache.dart';
import 'package:dtc_product/features/drive_docs/services/drive_doc_cache_factory_io.dart';
import 'package:dtc_product/features/drive_docs/services/drive_docs_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _root = 'root-folder';

Map<String, dynamic> _folder(String id, String name) => {
  'id': id,
  'name': name,
  'mimeType': DriveItem.folderMimeType,
};

Map<String, dynamic> _pdf(String id, String name, {String? modified}) => {
  'id': id,
  'name': name,
  'mimeType': DriveItem.pdfMimeType,
  'size': '2048',
  'modifiedTime': modified ?? '2026-10-01T08:00:00.000Z',
};

/// Drive giả: [folders] = id thư mục → danh sách file JSON; [files] = id → bytes.
class _FakeDrive {
  _FakeDrive({required this.folders, Map<String, List<int>>? files})
    : files = files ?? {};

  final Map<String, List<Map<String, dynamic>>> folders;
  final Map<String, List<int>> files;
  bool offline = false;
  final requests = <Uri>[];

  late final client = MockClient((request) async {
    requests.add(request.url);
    if (offline) throw http.ClientException('offline');
    expect(request.url.queryParameters['key'], 'test-key');
    final segments = request.url.pathSegments;
    if (segments.length == 3) {
      final q = request.url.queryParameters['q']!;
      final folderId = RegExp(r"'([^']+)' in parents").firstMatch(q)!.group(1)!;
      final listing = folders[folderId];
      if (listing == null) return http.Response('{"error":{}}', 404);
      // Không kèm charset: service vẫn phải đọc đúng tên tiếng Việt.
      return http.Response.bytes(
        utf8.encode(jsonEncode({'files': listing})),
        200,
      );
    }
    final bytes = files[segments.last];
    if (bytes == null) return http.Response('{"error":{}}', 404);
    return http.Response.bytes(bytes, 200);
  });
}

DriveDocsService _service(_FakeDrive drive, {DriveDocCache? cache}) =>
    DriveDocsService(
      client: drive.client,
      cache: cache ?? MemoryDriveDocCache(),
      apiKey: 'test-key',
      rootFolderId: _root,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('liệt kê thư mục: bỏ shortcut, thư mục xếp trước', () async {
    final drive = _FakeDrive(
      folders: {
        _root: [
          _pdf('p2', 'b.pdf'),
          {'id': 'x', 'name': 'ghi chu.docx', 'mimeType': 'application/msword'},
          {
            'id': 's',
            'name': 'lối tắt',
            'mimeType': DriveItem.shortcutMimeType,
          },
          {'id': 'v', 'name': 'chạy thử.mp4', 'mimeType': 'video/mp4'},
          _pdf('p1', 'A.pdf'),
          _folder('f1', 'Bản vẽ'),
        ],
      },
    );

    final items = await _service(drive).listFolder(_root);

    expect(items.map((i) => i.name), [
      'Bản vẽ',
      'A.pdf',
      'b.pdf',
      'chạy thử.mp4',
      'ghi chu.docx',
    ]);
    expect(items[1].size, 2048);
    expect(items[3].isVideo, isTrue);
    expect(items[4].opensInDrive, isTrue);
  });

  test('tìm thư mục theo đường dẫn tên, bỏ qua hoa thường và dấu', () async {
    final drive = _FakeDrive(
      folders: {
        _root: [_folder('p', 'MAY TACH MAU'), _folder('q', 'Cân đóng gói')],
        'p': [_folder('m', 'Video/Hình ảnh'), _folder('c', 'Catalogue')],
        'q': [],
      },
    );
    final service = _service(drive);

    expect(
      await service.findFolderByPath([
        ['Máy tách màu'],
        ['Video - hình ảnh'],
      ]),
      'm',
    );
    expect(
      await service.findFolderByPath([
        ['Cân đóng gói'],
        ['Catalogue'],
      ]),
      isNull,
    );
  });

  test('mất mạng: dùng danh sách thư mục đã lưu lần trước', () async {
    final drive = _FakeDrive(
      folders: {
        _root: [_pdf('p1', 'A.pdf')],
      },
    );
    await _service(drive).listFolder(_root);

    drive.offline = true;
    final items = await _service(drive).listFolder(_root);

    expect(items.single.name, 'A.pdf');
  });

  test('mất mạng và chưa từng tải: báo lỗi thân thiện', () async {
    final drive = _FakeDrive(folders: {})..offline = true;

    expect(
      _service(drive).listFolder(_root),
      throwsA(
        isA<DriveDocsException>().having(
          (e) => e.message,
          'message',
          contains('kết nối mạng'),
        ),
      ),
    );
  });

  test(
    'tìm PDF theo tên trong thư mục con, không phân biệt hoa thường',
    () async {
      final drive = _FakeDrive(
        folders: {
          _root: [_folder('f1', 'Catalog'), _pdf('p0', 'khac.pdf')],
          'f1': [_pdf('p1', 'DTC-Packing-TuiPE-240513.pdf')],
        },
      );

      final item = await _service(drive)
          .findPdfByName('dtc-packing-tuipe-240513.PDF');

      expect(item.id, 'p1');
    },
  );

  test('không có file trùng tên: báo chưa có tài liệu', () async {
    final drive = _FakeDrive(folders: {_root: []});

    expect(
      _service(drive).findPdfByName('x.pdf'),
      throwsA(
        isA<DriveDocsException>().having(
          (e) => e.message,
          'message',
          contains('Chưa có tài liệu "x.pdf"'),
        ),
      ),
    );
  });

  test('tải PDF một lần, lần sau đọc từ bộ đệm', () async {
    final drive = _FakeDrive(
      folders: {
        _root: [_pdf('p1', 'A.pdf')],
      },
      files: {
        'p1': [1, 2, 3],
      },
    );
    final service = _service(drive);
    final item = (await service.listFolder(_root)).single;

    expect(await service.loadFile(item), [1, 2, 3]);
    final downloads = drive.requests.length;
    expect(await service.loadFile(item), [1, 2, 3]);
    expect(drive.requests.length, downloads);
  });

  test(
    'file được cập nhật trên Drive thì tải bản mới; mất mạng dùng bản cũ',
    () async {
      final cache = MemoryDriveDocCache();
      final drive = _FakeDrive(
        folders: {},
        files: {
          'p1': [1],
        },
      );
      final service = _service(drive, cache: cache);
      final v1 = DriveItem.fromJson(_pdf('p1', 'A.pdf'));
      final v2 = DriveItem.fromJson(
        _pdf('p1', 'A.pdf', modified: '2026-10-05T08:00:00.000Z'),
      );
      await service.loadFile(v1);

      drive.files['p1'] = [2];
      expect(await service.loadFile(v2), [2]);

      drive.offline = true;
      final v3 = DriveItem.fromJson(
        _pdf('p1', 'A.pdf', modified: '2026-10-09T08:00:00.000Z'),
      );
      expect(await service.loadFile(v3), [2]);
    },
  );

  test('chưa cấu hình API key/thư mục: báo chưa cấu hình', () {
    final service = DriveDocsService(
      client: MockClient((_) async => http.Response('', 500)),
      cache: MemoryDriveDocCache(),
      apiKey: '',
      rootFolderId: '',
    );

    expect(service.isConfigured, isFalse);
    expect(service.listFolder('any'), throwsA(isA<DriveDocsException>()));
  });

  test('bộ đệm file chỉ giữ một phiên bản mỗi tài liệu', () async {
    final base = await Directory.systemTemp.createTemp('drive_docs_test');
    addTearDown(() => base.delete(recursive: true));
    final cache = FileDriveDocCache(baseDir: () async => base);

    await cache.write('p1', '1', Uint8List.fromList([1]));
    await cache.write('p1', '2', Uint8List.fromList([2]));

    expect(await cache.read('p1', '1'), isNull);
    expect(await cache.read('p1', '2'), [2]);
    expect(await cache.readAny('p1'), [2]);
    expect(Directory('${base.path}/drive_docs').listSync(), hasLength(1));
  });
}
