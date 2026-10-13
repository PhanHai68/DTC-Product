import 'package:dtc_product/features/drive_docs/document_library_catalog.dart';
import 'package:dtc_product/features/drive_docs/screens/document_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeDriveName', () {
    test('bỏ dấu, hoa thường và ký tự phân cách', () {
      expect(normalizeDriveName('Video/Hình ảnh'), 'videohinhanh');
      expect(normalizeDriveName('video - hinh anh'), 'videohinhanh');
      expect(normalizeDriveName('XAY XÁT LÚA-GẠO'), 'xayxatluagao');
      expect(
        normalizeDriveName('Bảng thông số kỹ thuật'),
        'bangthongsokythuat',
      );
      expect(normalizeDriveName('Đường ống'), 'duongong');
    });

    test('dấu tách rời (NFD, thường gặp khi tải từ macOS) vẫn khớp', () {
      // "Máy" viết bằng a + dấu sắc tách rời (U+0301).
      expect(
        normalizeDriveName('Ma\u0301y ta\u0301ch ma\u0300u'),
        'maytachmau',
      );
    });
  });

  test('tên thư mục viết hoa chữ đầu, tiếng Việt có dấu', () {
    expect(docProducts.map((p) => p.folderName), [
      'Máy tách màu',
      'Cân đóng gói',
      'Máy nén khí',
      'Máy nghiền',
      'Xay xát lúa gạo',
    ]);
    expect(docTypes.map((t) => t.folderName), [
      'Catalogue',
      'Bảng thông số kỹ thuật',
      'Bản vẽ lắp đặt',
      'Video - hình ảnh',
      'Hướng dẫn vận hành',
    ]);
  });

  testWidgets('thư viện hiện 5 sản phẩm và mục tất cả tài liệu', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DocumentLibraryScreen()));
    await tester.pumpAndSettle();

    for (final product in docProducts) {
      expect(find.text(product.title), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('Tất cả tài liệu'), 200);
    expect(find.text('Tất cả tài liệu'), findsOneWidget);
  });

  testWidgets('mỗi sản phẩm có 5 loại tài liệu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: DocumentProductScreen(product: docProducts.first)),
    );
    await tester.pumpAndSettle();

    for (final type in docTypes) {
      await tester.scrollUntilVisible(find.text(type.title), 200);
      expect(find.text(type.title), findsOneWidget);
    }
  });
}
