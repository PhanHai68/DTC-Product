import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> saveSiteLayoutPhoto({
  required String projectId,
  required String fileName,
  required Uint8List bytes,
  bool thumbnail = false,
}) async => 'data:image/jpeg;base64,${base64Encode(bytes)}';

Future<String> saveSiteLayoutExport({
  required String projectId,
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
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

Future<Uint8List?> readSiteLayoutFile(String path) async {
  final separator = path.indexOf(',');
  if (!path.startsWith('data:') || separator < 0) return null;
  return base64Decode(path.substring(separator + 1));
}

Future<void> deleteSiteLayoutFile(String path) async {}
