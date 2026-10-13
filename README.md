# DTC Product

Ứng dụng Flutter hỗ trợ tra cứu sản phẩm và các công cụ kỹ thuật của DTC Group.

## Chức năng chính

- Tra cứu, so sánh và chọn máy tách màu, máy nén khí, cân đóng gói.
- Xem thông số kỹ thuật, catalog PDF, hướng dẫn vận hành và mô hình 3D.
- Tính năng suất, quy đổi kỹ thuật và phân tích hoàn vốn.
- Lập form lưu mẫu, chụp ảnh, xuất/chia sẻ PDF có dấu xác nhận.
- Quản lý lịch bảo trì bằng cơ sở dữ liệu cục bộ.

Ứng dụng hoạt động phía client. Dữ liệu nghiệp vụ và dữ liệu người dùng không được gửi lên máy chủ bởi mã nguồn hiện tại.

## Môi trường

- Flutter/Dart theo phiên bản ghi trong `.metadata` và `pubspec.yaml`.
- Java 17 cho Android.
- Xcode trên macOS khi build iOS.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

## Cấu trúc thư mục

```
lib/             mã nguồn app (features/ là cấu trúc mới theo tính năng)
assets/          ảnh, font, mô hình 3D, video và database sản phẩm (assets/database/)
test/            unit test và widget test
tool/data/       script sinh database sản phẩm từ tài liệu gốc
                 (dart run tool/data/<tên_script>.dart)
tool/presentation/ script PowerShell tạo báo cáo/slide giới thiệu app
docs/            tài liệu kỹ thuật dạng Markdown (máy nghiền, nội dung thuyết trình, RELEASE_AUDIT)
docs_database/   kho tài liệu gốc Excel/PDF/ảnh — chỉ lưu local, không đưa lên Git
                 (xem docs_database/README.md)
```

## Nền tảng

- Android, iOS: nền tảng phát hành chính.
- Web, Windows, Linux, macOS: mã nguồn có cấu hình hỗ trợ; cần chạy checklist nghiệm thu riêng trước mỗi lần phát hành.
- Web cần phục vụ `sqlite3.wasm`, `sqflite_sw.js` và các file trong thư mục `web/` cùng bản build.

## Dữ liệu cục bộ

- Thông số sản phẩm (máy tách màu, máy nén khí, cân đóng gói, máy nghiền...): file JSON trong `assets/database/`, nạp một lần khi mở app. Cách sửa: xem `assets/database/README.md`.
- Database bảo trì: `user_data.db`, được tạo trong vùng dữ liệu riêng của ứng dụng.
- Ảnh và PDF lưu mẫu trên native: thư mục tài liệu ứng dụng `DTCProduct/LuuMau`.
- Trên Web, ảnh bản nháp được giữ ở phía trình duyệt và PDF được tải trực tiếp xuống máy.

Khi thay đổi schema database bảo trì, phải tăng version và bổ sung migration; không xóa database người dùng trong quá trình nâng cấp.

## Ký bản Android release

1. Tạo upload keystore và lưu ngoài repository.
2. Sao chép `android/key.properties.example` thành `android/key.properties`.
3. Điền đường dẫn và thông tin khóa thật.
4. Chạy `flutter build appbundle --release`.

`key.properties`, `*.jks` và `*.keystore` đã được bỏ qua bởi Git. Nếu chưa có cấu hình khóa, bản release không được tự động ký bằng debug key.

## Việc cần chốt trước lần phát hành đầu tiên

- Thay Android application ID và iOS bundle ID `com.example...` bằng định danh chính thức. Nếu ứng dụng đã phát hành, phải giữ nguyên định danh cũ để tiếp tục cập nhật cho người dùng.
- Cấu hình Apple Development Team và signing certificate trên máy macOS.
- Xác nhận version/build number, privacy policy và quyền sử dụng tài liệu, hình ảnh, font, Syncfusion.
- Kiểm thử camera, chia sẻ PDF, lưu dữ liệu và mô hình 3D trên thiết bị Android/iOS thật.

## Kiểm tra trước khi bàn giao

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build web
```

Với bản phát hành, bổ sung build App Bundle Android và archive iOS trên môi trường có khóa ký hợp lệ.
