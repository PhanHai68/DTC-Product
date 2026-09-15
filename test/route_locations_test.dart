import 'package:dtc_product/routes/route_locations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('đường dẫn chi tiết máy giữ được model sau khi tải lại trang', () {
    final location = packingDetailLocation('LZB-600 R10', showCatalog: false);
    final uri = Uri.parse(location);

    expect(uri.path, '/packing_detail');
    expect(uri.queryParameters['model'], 'LZB-600 R10');
    expect(uri.queryParameters['catalog'], 'false');
  });

  test('đường dẫn catalog giữ đủ file, trang và model', () {
    final location = packingCatalogLocation(
      assetPath: 'assets/catalogs/Cân đóng gói.pdf',
      initialPage: 12,
      modelName: 'LCS-100',
    );
    final uri = Uri.parse(location);

    expect(uri.queryParameters['path'], 'assets/catalogs/Cân đóng gói.pdf');
    expect(uri.queryParameters['page'], '12');
    expect(uri.queryParameters['model'], 'LCS-100');
  });
}
