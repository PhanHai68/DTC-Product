import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> persistSamplePhoto({
  required String sourcePath,
  required String fileName,
  List<int>? bytes,
}) async {
  if (bytes == null) {
    throw ArgumentError('Thiếu dữ liệu ảnh cần lưu.');
  }
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

Future<Uint8List?> readSamplePhoto(String storedPath) async {
  final separator = storedPath.indexOf(',');
  if (!storedPath.startsWith('data:') || separator < 0) return null;
  return base64Decode(storedPath.substring(separator + 1));
}

Future<String> saveSamplePdf({
  required List<int> bytes,
  required String fileName,
}) async {
  final data = Uint8List.fromList(bytes);
  final blob = web.Blob(
    <JSUint8Array>[data.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return fileName;
}
