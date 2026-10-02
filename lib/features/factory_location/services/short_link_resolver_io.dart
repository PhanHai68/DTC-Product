import 'dart:async';
import 'dart:io';

export 'short_link_resolver.dart' show ShortLinkException;
import 'short_link_resolver.dart' show ShortLinkException;

const _maxRedirects = 6;

Future<String> resolveShortMapsLink(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    var current = Uri.parse(url.trim());
    for (var hop = 0; hop < _maxRedirects; hop++) {
      final request = await client.getUrl(current);
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      await response.drain<void>();
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (!response.isRedirect || location == null) break;
      current = current.resolve(location);
    }
    return current.toString();
  } on SocketException {
    throw const ShortLinkException(
      'Không có kết nối mạng nên chưa đọc được link rút gọn. '
      'Hãy dùng nút Định vị hoặc dán link Google Maps đầy đủ.',
    );
  } on TimeoutException {
    throw const ShortLinkException(
      'Hết thời gian chờ khi đọc link rút gọn. Vui lòng thử lại.',
    );
  } on HttpException {
    throw const ShortLinkException('Không đọc được link rút gọn này.');
  } finally {
    client.close(force: true);
  }
}
