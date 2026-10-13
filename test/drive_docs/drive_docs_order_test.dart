import 'package:dtc_product/features/drive_docs/drive_docs_config.dart';
import 'package:dtc_product/features/drive_docs/models/drive_item.dart';
import 'package:dtc_product/features/drive_docs/screens/drive_docs_screen.dart';
import 'package:flutter_test/flutter_test.dart';

DriveItem _folder(String name) =>
    DriveItem(id: name, name: name, mimeType: DriveItem.folderMimeType);

void main() {
  test('thư mục gốc xếp theo thứ tự màn hình chính, mục khác xếp sau', () {
    // Thứ tự Drive trả về: bảng chữ cái.
    final items = [
      _folder('Cân đóng gói'),
      _folder('Khác'),
      _folder('Máy nghiền'),
      _folder('Máy nén khí'),
      _folder('MÁY TÁCH MÀU'),
      _folder('Xay xát lúa gạo'),
    ];

    expect(orderByNames(items, driveDocsRootOrder).map((i) => i.name), [
      'MÁY TÁCH MÀU',
      'Cân đóng gói',
      'Máy nén khí',
      'Máy nghiền',
      'Xay xát lúa gạo',
      'Khác',
    ]);
  });
}
