class ShortLinkException implements Exception {
  const ShortLinkException(this.message);
  final String message;

  @override
  String toString() => message;
}

Future<String> resolveShortMapsLink(String url) async {
  throw const ShortLinkException(
    'Trình duyệt không hỗ trợ đọc link rút gọn (maps.app.goo.gl). '
    'Hãy mở link, sao chép link đầy đủ trên thanh địa chỉ rồi dán lại, hoặc dùng nút Định vị.',
  );
}
