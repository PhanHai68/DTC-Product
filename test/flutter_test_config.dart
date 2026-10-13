import 'dart:async';
import 'dart:io';

import 'package:dtc_product/data/product_data.dart';

/// Chạy trước mọi test trong thư mục test/: nạp thông số máy từ
/// assets/database/ giống như main() làm khi mở app.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ProductData.loadFromStrings({
    for (final path in ProductData.assetPaths)
      path: File(path).readAsStringSync(),
  });
  await testMain();
}
