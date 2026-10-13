import 'package:dtc_product/features/drive_docs/models/drive_item.dart';
import 'package:dtc_product/features/drive_docs/widgets/drive_share_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DriveItem _file(String name, String mimeType, {int? size}) =>
    DriveItem(id: name, name: name, mimeType: mimeType, size: size);

Future<void> _openSheet(WidgetTester tester, DriveItem item) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: DriveShareButton(item: item)),
      ),
    ),
  );
  await tester.tap(find.byTooltip('Chia sẻ'));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<ListTile>(find.byKey(Key(key))).enabled;

void main() {
  group('DriveItem.canShareAsFile', () {
    test('PDF, ảnh, video dưới 100 MB gửi được dạng file', () {
      expect(
        _file('a.pdf', DriveItem.pdfMimeType, size: 2048).canShareAsFile,
        isTrue,
      );
      expect(
        _file('a.jpg', 'image/jpeg', size: 5 << 20).canShareAsFile,
        isTrue,
      );
      expect(
        _file('a.mp4', 'video/mp4', size: 99 << 20).canShareAsFile,
        isTrue,
      );
    });

    test('file quá 100 MB hoặc Google Docs chỉ gửi link', () {
      expect(
        _file('a.mp4', 'video/mp4', size: 150 << 20).canShareAsFile,
        isFalse,
      );
      expect(
        _file('a', 'application/vnd.google-apps.document').canShareAsFile,
        isFalse,
      );
    });
  });

  testWidgets('bảng chia sẻ PDF có cả gửi file và gửi link', (tester) async {
    await _openSheet(
      tester,
      _file('Catalog SC16.pdf', DriveItem.pdfMimeType, size: 3 << 20),
    );

    expect(find.text('Catalog SC16.pdf'), findsOneWidget);
    expect(find.text('Gửi file'), findsOneWidget);
    expect(find.textContaining('3.0 MB'), findsOneWidget);
    expect(_enabled(tester, 'drive_share_file'), isTrue);
    expect(_enabled(tester, 'drive_share_link'), isTrue);
  });

  testWidgets('video quá lớn: tắt gửi file, vẫn gửi được link', (tester) async {
    await _openSheet(tester, _file('Video.mp4', 'video/mp4', size: 300 << 20));

    expect(_enabled(tester, 'drive_share_file'), isFalse);
    expect(find.textContaining('lớn hơn 100 MB'), findsOneWidget);
    expect(_enabled(tester, 'drive_share_link'), isTrue);
  });
}
