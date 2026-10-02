# Báo cáo kiểm tra trước phát hành — DTC Product

- Ngày kiểm tra: 01/10/2026
- Phiên bản: `1.0.14+15` (pubspec.yaml) — Flutter 3.47.2 stable
- Nhánh: `phase5-codex-handoff` (đang có 94 thay đổi chưa commit)
- Phạm vi: `lib/` (331 file, ~76.700 dòng), `test/`, cấu hình Android/iOS, `pubspec.yaml`
- Giai đoạn 1: **chỉ kiểm tra, chưa sửa code.**

## Tóm tắt nhanh

| Mức độ | Số lượng |
|---|---|
| Nghiêm trọng | 2 |
| Cao | 6 |
| Trung bình | 9 |
| Thấp | 15 |

## Trạng thái sửa (cập nhật 01/10/2026)

| Mục | Trạng thái |
|---|---|
| C1, C2 | ⏳ Chờ ID chính thức từ chủ app |
| H1 | ✅ Đã gỡ `FOREGROUND_SERVICE_LOCATION` (`tools:node="remove"`). **Giữ** `GeolocatorLocationService` vì plugin luôn gọi `bindService`/`unbindService` (`GeolocatorPlugin.java:148-158`); gỡ service sẽ ném `IllegalArgumentException` khi đóng app. Đã xác nhận manifest gộp không còn quyền này. |
| H2 | ⏳ Việc của chủ app (giấy phép Syncfusion) |
| H3 | ✅ Đổi `Row` thành `Wrap` để nhãn nút tự xuống dòng |
| H4 | ✅ Cỡ chữ = cỡ chữ hệ thống × hệ số của app, giới hạn trong 0,85–2,0 |
| H5 | ⏳ Việc của chủ app (chính sách quyền riêng tư, Data safety, App Privacy) |
| H6 | ✅ Đạt: `zipalign -c -P 16` thành công; `llvm-readelf` cho thấy mọi `.so` (arm64, x86_64) có LOAD align ≥ 0x4000 |
| M1 | ✅ Thêm `runSalesGoalAction` (`lib/features/sales_goal/utils/sales_goal_action.dart`) cho mọi thao tác lưu/xóa trong "Mục tiêu doanh số"; danh sách doanh số có trạng thái lỗi kèm nút "Thử lại"; vuốt xóa việc cần làm chuyển sang `confirmDismiss` |
| M7 | ✅ `flutter test`: 528 đạt, 1 bỏ qua (test tạo preview PDF tự bỏ qua khi thiếu ảnh mẫu cục bộ), 0 thất bại |
| Commit/tag | ⏳ Chưa thực hiện, chờ chủ app xác nhận |

**Kết quả công cụ**

- `flutter analyze` (toàn dự án): 89 vấn đề, **chỉ 3 vấn đề nằm trong `lib/`**:
  - 2 cảnh báo `unused_element` ở `lib/features/projects/services/project_report_pdf_service.dart:718` và `:754`.
  - 1 info `curly_braces_in_flow_control_structures` ở `lib/screens/color_sorter/color_sorter_screen.dart:95`.
  - 86 vấn đề còn lại nằm trong các script ngoài app (`bin/`, `scratch/`, các file `*.dart` ở thư mục gốc).
- `flutter test`: **525 đạt / 4 thất bại** (xem mục H3, M7).

**Những điểm đã đạt (không cần sửa)**

- Không có API key, token hay mật khẩu viết cứng trong code. `key.properties` và `upload-keystore.jks` đã được `.gitignore` và **chưa từng bị commit** (đã kiểm tra lịch sử git).
- Không có `print()` trong `lib/`. 9 lệnh `debugPrint` chỉ in thông báo lỗi, không in dữ liệu người dùng.
- Lint `use_build_context_synchronously` không báo lỗi nào, tức là không dùng `context` sau `await` mà thiếu kiểm tra `mounted`.
- `minSdk 24`, `targetSdk 36`: đáp ứng yêu cầu hiện hành của Google Play (tối thiểu API 35).
- Bản release được ký bằng keystore thật; Gradle chặn build release nếu thiếu `key.properties`.
- Chặn HTTP không mã hóa (`usesCleartextTraffic=false` và `network_security_config`).
- Hỗ trợ chế độ tối (`darkTheme`, `themeMode`). Có `ErrorWidget` thân thiện bằng tiếng Việt ở bản release.
- Đã có test chống tràn giao diện ở màn hình rộng 320/360 px cho module grinding.
- Không có code phụ thuộc `runtimeType.toString()`, nên bật `--obfuscate` an toàn.

---

## 1. Nghiêm trọng

### C1. Android dùng applicationId mặc định `com.example.dtc_product`
- **Vị trí:** `android/app/build.gradle.kts:29` (`namespace`), `:41` (`applicationId`)
- **Mô tả:** Google Play từ chối package bắt đầu bằng `com.example`. ApplicationId **không thể đổi sau khi đã phát hành**.
- **Cách sửa:**
  - Chọn ID chính thức, ví dụ `vn.dtcgroup.product`, và đặt cho cả `namespace` lẫn `applicationId`.
  - Chuyển `MainActivity.kt` sang thư mục package mới (`android/app/src/main/kotlin/vn/dtcgroup/product/`) và sửa dòng `package`.
  - Lưu ý: người đang cài bản APK cũ sẽ thấy đây là một app khác; dữ liệu cục bộ không tự chuyển sang.

### C2. iOS dùng Bundle Identifier mặc định `com.example.dtcProduct`
- **Vị trí:** `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`, cả target `RunnerTests`)
- **Mô tả:** Không đăng ký được App ID `com.example.*` trên Apple Developer. Bundle ID cũng không thể đổi sau khi phát hành.
- **Cách sửa:** Đặt cùng ID với Android (ví dụ `vn.dtcgroup.product`), đăng ký trên Apple Developer và tạo app trên App Store Connect với ID này.

---

## 2. Cao

### H1. Plugin geolocator tự thêm quyền và service chạy nền loại "location"
- **Vị trí:** manifest đã gộp (`build/app/intermediates/merged_manifest/release/.../AndroidManifest.xml`): có `FOREGROUND_SERVICE_LOCATION` và `<service android:foregroundServiceType="location">`, được thêm từ `geolocator_android`.
- **Mô tả:** App chỉ lấy vị trí khi đang mở màn hình, không chạy nền. Nhưng khi manifest có quyền này, Google Play Console bắt buộc khai báo "Foreground service" (kèm video minh họa) và dễ bị từ chối khi xét duyệt.
- **Cách sửa:** Trong `android/app/src/main/AndroidManifest.xml`, thêm `xmlns:tools` và gỡ hai mục này:
  ```xml
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" tools:node="remove"/>
  <service android:name="com.baseflow.geolocator.GeolocatorLocationService" tools:node="remove"/>
  ```
  Sau đó build lại và kiểm tra manifest đã gộp không còn hai mục trên.

### H2. Giấy phép Syncfusion
- **Vị trí:** `pubspec.yaml:47` (`syncfusion_flutter_pdfviewer`), `:57` (`syncfusion_flutter_pdf`)
- **Mô tả:** Các package Syncfusion là **phần mềm thương mại**. Phát hành app có dùng chúng cần một trong hai: Community License (miễn phí cho doanh nghiệp doanh thu dưới 1 triệu USD và tối đa 5 lập trình viên) hoặc giấy phép trả phí. Đây là rủi ro pháp lý, không phải lỗi code.
- **Cách sửa:** Xác nhận DTC Group đủ điều kiện và đã đăng ký giấy phép phù hợp. Nếu không, thay bằng thư viện mã nguồn mở (ví dụ `pdfrx` để xem PDF, `pdf` để tạo PDF).

### H3. Tràn giao diện ở màn "Chi tiết hồ sơ chọn máy nghiền" trên điện thoại
- **Vị trí:** `lib/features/grinding_machine/screens/grinding_selection_project_detail_screen.dart:923-942`
- **Mô tả:** Hàng gồm tiêu đề "Chi phí lắp đặt" và nút "Tính toán chi phí lắp đặt" bị tràn 79 px ở màn rộng 390 px. Tiêu đề trong `Expanded` bị ép về gần 0 px nên xuống dòng từng ký tự (hàng cao 240 px). Đây là nguyên nhân 2 test thất bại:
  - `test/grinding_selection_missing_machine_test.dart`
  - `test/grinding_selection_selector_integration_test.dart`
- **Cách sửa:** Đổi `Row` thành `Wrap` (hoặc đặt nút xuống dòng riêng), hoặc rút gọn nhãn nút thành "Tính chi phí". Có thể bọc nhãn bằng `Flexible` với `overflow: TextOverflow.ellipsis`.

### H4. Cỡ chữ của app bỏ qua cài đặt cỡ chữ của hệ điều hành
- **Vị trí:** `lib/main.dart:231-234`
- **Mô tả:** `textScaler: TextScaler.linear(settings.textScale.scale)` **ghi đè** cỡ chữ hệ thống. Người dùng đã tăng cỡ chữ trong Cài đặt của Android/iOS (hỗ trợ tiếp cận) sẽ không thấy app thay đổi.
- **Cách sửa:** Nhân hệ số của app với hệ số hệ thống, kèm giới hạn trên để tránh vỡ bố cục:
  ```dart
  final system = MediaQuery.textScalerOf(context);
  textScaler: system.clamp(maxScaleFactor: 1.6) * settings.textScale.scale
  ```
  (hoặc `TextScaler.linear(system.scale(1) * settings.textScale.scale)`). Cần kiểm tra lại các màn chính ở cỡ chữ lớn nhất.

### H5. Chưa có Chính sách quyền riêng tư và biểu mẫu dữ liệu cho cửa hàng
- **Vị trí:** cấu hình cửa hàng, không nằm trong code
- **Mô tả:** App xin quyền vị trí, camera, thư viện ảnh và thông báo. Cả Google Play (Data safety) lẫn App Store (App Privacy) bắt buộc có **URL chính sách quyền riêng tư** và khai báo dữ liệu thu thập. App chỉ lưu dữ liệu trên máy và không gửi lên server, nên có thể khai báo "không thu thập", nhưng phải mô tả đúng sự thật.
- **Cách sửa:**
  - Soạn trang chính sách quyền riêng tư bằng tiếng Việt và tiếng Anh, đặt trên website DTC.
  - Điền Data safety: vị trí chính xác chỉ lưu trên thiết bị và chỉ được chia sẻ khi người dùng chủ động bấm "Chia sẻ"; ảnh do người dùng chọn.
  - Điền App Privacy tương tự.

### H6. Chưa xác minh yêu cầu căn chỉnh trang bộ nhớ 16 KB của Google Play
- **Vị trí:** thư viện native trong APK: `libsqlite3.so` (từ `sqflite_common_ffi`/`sqlite3`), `libdartjni.so`, `libdatastore_shared_counter.so`, `libflutter.so`, `libapp.so`
- **Mô tả:** Google Play yêu cầu app có target Android 15 trở lên phải hỗ trợ trang 16 KB. Máy này không có `zipalign` trong Android SDK nên chưa kiểm tra được.
- **Cách sửa:** Sau khi build AAB, mở App bundle explorer trong Play Console và xem mục "16 KB page size". Hoặc chạy:
  ```
  zipalign -c -P 16 -v 4 build/app/outputs/flutter-apk/app-release.apk
  ```
  Nếu thư viện nào không đạt, nâng plugin tương ứng lên bản mới.

---

## 3. Trung bình

### M1. Lưu/xóa trong "Mục tiêu doanh số" không xử lý lỗi
- **Vị trí:**
  - `lib/features/sales_goal/screens/sales_target_form_screen.dart:138` và `:151-156`
  - `lib/features/sales_goal/screens/sales_entry_form_screen.dart:126`
  - `lib/features/sales_goal/screens/sales_opportunity_form_screen.dart:170`
  - `lib/features/sales_goal/screens/sales_entry_list_screen.dart:36` và `:122`
  - Các hàm ghi dữ liệu trong `lib/features/sales_goal/providers/sales_goal_provider.dart` (`saveTargets`, `saveEntry`, `deleteEntry`, `saveOpportunity`…)
- **Mô tả:** Các màn này bật `_saving = true` rồi `await` mà không có `try/catch`. Nếu ghi SQLite lỗi (bộ nhớ đầy, DB bị khóa), nút lưu xoay mãi, lỗi không được bắt và người dùng không nhận thông báo. Riêng `sales_entry_list_screen.dart:36`, nếu `_load()` lỗi thì màn hình kẹt ở trạng thái loading.
- **Cách sửa:** Bọc trong `try/catch/finally`; ở nhánh lỗi tắt `_saving` và hiện SnackBar "Không thể lưu dữ liệu. Vui lòng thử lại." (giống cách đã làm ở `factory_location_form_screen.dart`).

### M2. Không bắt lỗi bất đồng bộ toàn cục và không có báo cáo crash
- **Vị trí:** `lib/main.dart:53`
- **Mô tả:** Chỉ có `FlutterError.onError = FlutterError.presentError`. Thiếu `PlatformDispatcher.instance.onError` nên lỗi trong `Future` không được bắt và không ghi lại ở đâu. Sau khi phát hành sẽ không biết người dùng gặp crash gì.
- **Cách sửa:** Thêm `PlatformDispatcher.instance.onError`. Cân nhắc tích hợp Firebase Crashlytics hoặc Sentry; nếu tích hợp thì phải khai báo thêm trong Data safety/App Privacy (H5).

### M3. Router ép kiểu `state.extra` bắt buộc khác null
- **Vị trí:** `lib/routes/app_routes.dart`:
  - `:204`, `:209`, `:214` (`state.extra! as StoredFile`)
  - `:326` (`state.extra as String`)
  - `:405-408` (`state.extra as Map<String, dynamic>` cùng các phần tử bên trong)
- **Mô tả:** Nếu mở route mà không truyền `extra` thì app crash ngay (màn hình lỗi). Các trường hợp gặp phải: tải lại trang trên bản web, khôi phục sau khi hệ điều hành đóng app, hoặc mở bằng deep link sau này. Trên mobile hiện tại khó xảy ra vì không có deep link.
- **Cách sửa:** Kiểm tra `state.extra is StoredFile` (hoặc kiểu tương ứng); nếu không đúng thì chuyển về màn danh sách hoặc hiện màn "Không tìm thấy nội dung".

### M4. Ảnh mặt bằng được lưu nguyên kích thước gốc và xử lý trên luồng giao diện
- **Vị trí:** `lib/features/site_layout/services/site_photo_service.dart:18-23` và `:37` (`_thumbnail`)
- **Mô tả:** `pickImage` và `pickMultiImage` không giới hạn `maxWidth` hay `imageQuality`. Ảnh 12–50 MP được lưu nguyên bản, rồi tạo thumbnail bằng package `image` ngay trên luồng giao diện. Chọn nhiều ảnh cùng lúc dễ làm giật, thậm chí tràn bộ nhớ trên máy yếu.
- **Cách sửa:** Truyền `maxWidth: 2400, imageQuality: 85` như `project_photo_service.dart`, và tạo thumbnail trong `Isolate.run(...)`.

### M5. Lưới ảnh giải mã ảnh ở độ phân giải đầy đủ
- **Vị trí:**
  - `lib/widgets/stored_image_io.dart:15` (`Image.file` không có `cacheWidth`)
  - `lib/features/site_layout/screens/site_photo_gallery_screen.dart:255` (`Image.memory`)
  - Nơi dùng: `project_photo_gallery_page.dart:264`, `sample_record_screen.dart:1105`, `maintenance_before_after_view.dart:171`
- **Mô tả:** Mỗi ô thumbnail giải mã ảnh 2000–2400 px, tốn khoảng 15–20 MB RAM mỗi ảnh. Lưới vài chục ảnh dễ gây giật hoặc app bị hệ điều hành đóng.
- **Cách sửa:** Thêm tham số `cacheWidth` vào `StoredImage` và truyền `(kích thước ô × devicePixelRatio)` ở các màn lưới. Cách này đã được áp dụng đúng ở `machine_card.dart` và `home_screen.dart`.

### M6. Vị trí nhà máy: chưa xử lý khi người dùng chỉ cấp vị trí gần đúng
- **Vị trí:** `lib/features/factory_location/services/location_service.dart`, `screens/factory_location_form_screen.dart` (`_CoordinateSummary`)
- **Mô tả:**
  - Android 12+ cho phép chọn "Vị trí gần đúng" (chỉ quyền COARSE), độ chính xác khoảng 1–3 km.
  - iOS 14+ cho phép tắt "Vị trí chính xác".
  - Hiện app chỉ tô màu cam và gợi ý "Định vị lại". Định vị lại vẫn không cải thiện, vì nguyên nhân là quyền chứ không phải tín hiệu.
- **Cách sửa:**
  - Android: khi sai số trên 1000 m, hiện thông báo "Bạn đang cấp vị trí gần đúng. Hãy bật 'Vị trí chính xác' cho DTC Product" kèm nút Mở Cài đặt.
  - iOS: kiểm tra `Geolocator.getLocationAccuracy()`. Nếu là `reduced`, gọi `requestTemporaryFullAccuracy(purposeKey: ...)` và thêm `NSLocationTemporaryUsageDescriptionDictionary` (tiếng Việt) vào `Info.plist`.

### M7. 4 test đang thất bại
- **Vị trí và nguyên nhân:**
  - 2 test grinding: do lỗi tràn giao diện thật, xem H3.
  - `test/sample_record_preview_generation_test.dart`: phụ thuộc file cục bộ `build/analysis/sample_workbook_media/FORM LUU MAU GAO/image1.jpeg` không tồn tại, nên chỉ chạy được trên một máy cụ thể.
  - `test/tea_color_sorter_access_test.dart` ("Khoáng sản dùng icon khối đá"): giao diện thẻ đã chuyển sang hiển thị ảnh (`imagePath`), nhưng test vẫn tìm `Icons.terrain_rounded`. Test đã lỗi thời.
- **Cách sửa:**
  - Sửa H3.
  - Chuyển ảnh mẫu vào `test/fixtures/`, hoặc đánh dấu `skip` khi không có file.
  - Cập nhật test icon khoáng sản theo giao diện mới.
  - Mục tiêu: `flutter test` đạt 100% trước khi phát hành.

### M8. Kích thước app lớn
- **Vị trí:** `pubspec.yaml:97-106` (assets), APK release 144,9 MB
- **Mô tả:**
  - Assets khoảng 64 MB: mô hình 3D 15,8 MB (`sx8.glb` 8,1 MB), PDF catalog/tài liệu 20 MB, video 3,1 MB, nhiều PNG trên 1 MB (`verified_dtc_product.png` 1,4 MB, `home_packing_v2.png` 1,3 MB…).
  - `libapp.so` khoảng 16,7 MB cho mỗi kiến trúc CPU.
- **Cách sửa:**
  - Phát hành bằng **App Bundle**: Play tự tách theo kiến trúc CPU, mỗi lượt tải giảm khoảng 40 MB.
  - Chuyển PNG ảnh chụp/minh họa sang WebP (thường giảm 60–80%).
  - Cân nhắc tải mô hình 3D và catalog PDF khi cần, thay vì đóng gói sẵn.

### M9. iOS chưa có tệp kê khai quyền riêng tư (Privacy Manifest) ở cấp app
- **Vị trí:** `ios/Runner/` (không có `PrivacyInfo.xcprivacy`)
- **Mô tả:** Apple yêu cầu khai báo lý do sử dụng các "required reason API" (UserDefaults, thời gian tạo/sửa file, dung lượng ổ đĩa…). Plugin bản mới tự kèm manifest riêng, nhưng App Store Connect vẫn có thể gửi cảnh báo `ITMS-91053` khi tải bản build lên.
- **Cách sửa:** Thêm `ios/Runner/PrivacyInfo.xcprivacy` vào target Runner:
  - `NSPrivacyTracking = false`
  - Không thu thập dữ liệu
  - Khai báo `NSPrivacyAccessedAPICategoryUserDefaults` (CA92.1) và `NSPrivacyAccessedAPICategoryFileTimestamp` (C617.1) nếu cần.

---

## 4. Thấp

| # | Vị trí | Mô tả | Cách sửa đề xuất |
|---|---|---|---|
| L1 | `android/app/src/main/AndroidManifest.xml:3` | Quyền `CAMERA` không cần thiết: `image_picker` chụp ảnh qua app Camera của hệ thống. Khi khai báo quyền này, app buộc phải xin quyền lúc chạy. | Gỡ quyền `CAMERA` để giảm số quyền khai báo với Play, **sau đó thử lại chức năng chụp ảnh ở cả 4 module** (mẫu, dự án, bảo trì, mặt bằng). |
| L2 | `AndroidManifest.xml:5` (`<application>`) | Không khai báo `allowBackup`, nên mặc định là `true`: DB khách hàng, ghi chú, báo cáo được sao lưu lên Google Drive của người dùng. | Quyết định chính sách. Nếu muốn giữ sao lưu thì khai báo rõ `android:allowBackup="true"` và thêm `dataExtractionRules`; nếu không thì đặt `false`. |
| L3 | `android/app/src/main/res/` | Không có `mipmap-anydpi-v26`: thiếu adaptive icon, nên Android 8+ hiển thị icon trong khung trắng. | Khai báo `adaptive_icon_background` và `adaptive_icon_foreground` trong cấu hình `flutter_launcher_icons`. |
| L4 | `ios/Runner/Info.plist:10, :18` | Tên hiển thị iOS là "Dtc Product", Android là "DTC Product"; `CFBundleName` = `dtc_product`. | Đổi `CFBundleDisplayName` thành "DTC Product" và `CFBundleName` thành "DTC Product". |
| L5 | `ios/Runner/Info.plist` | Thiếu `ITSAppUsesNonExemptEncryption`, nên App Store Connect hỏi về mã hóa ở mỗi lần tải bản build. | Thêm `<key>ITSAppUsesNonExemptEncryption</key><false/>` (app chỉ dùng HTTPS của hệ thống và hàm băm). |
| L6 | `ios/Runner/Info.plist:35-36` | `NSPhotoLibraryAddUsageDescription` có thể không dùng: chưa thấy code lưu ảnh vào thư viện. | Kiểm tra lại; nếu không dùng thì gỡ để tránh bị hỏi khi xét duyệt. |
| L7 | `pubspec.yaml:38` | `cupertino_icons` không được dùng ở đâu trong `lib/`. | Gỡ khỏi dependencies. |
| L8 | `pubspec.yaml` | 48 package có bản mới không tương thích với ràng buộc hiện tại: `share_plus` 13, `package_info_plus` 10 (đang chặn `geolocator` 14.1.x), Syncfusion 35, `archive` 4, `xml` 7, `flutter_launcher_icons` 0.14. Build còn cảnh báo một số plugin chưa hỗ trợ "Built-in Kotlin". | Không chặn phát hành. Lên kế hoạch nâng cấp sau release, mỗi lần một nhóm, kèm chạy test. |
| L9 | `lib/screens/payback/electricity_bill_screen.dart:29-35` | 3 `TextEditingController` tạo cho hộp thoại không được dispose (rò bộ nhớ nhỏ mỗi lần mở). | Gọi `dispose()` sau khi `showDialog` kết thúc (`await showDialog(...)` rồi dispose). |
| L10 | `lib/features/factory_location/screens/factory_location_form_screen.dart:266` | `Clipboard.getData` có thể ném lỗi (web chặn quyền clipboard). | Bọc `try/catch`, báo "Không đọc được bộ nhớ tạm, hãy dán thủ công". |
| L11 | `lib/features/factory_location/services/location_service.dart` | Hết thời gian chờ thì báo lỗi ngay, không dùng vị trí gần nhất đã biết. | Khi `timeout`, thử `Geolocator.getLastKnownPosition()` (chỉ dùng nếu cách đây dưới 2 phút) kèm cảnh báo về độ chính xác. |
| L12 | `lib/features/factory_location/services/short_link_resolver_io.dart` | Link rút gọn chia sẻ một *địa điểm có tên* thường chuyển hướng tới `?q=<tên>` không có tọa độ, nên báo "Không đọc được tọa độ". | Chấp nhận được; nêu trong hướng dẫn. Có thể đọc thêm tọa độ trong HTML trả về (không khuyến nghị vì cấu trúc trang hay thay đổi). |
| L13 | `lib/routes/app_routes.dart:379-392` | `int.parse(state.pathParameters[...])` sẽ crash nếu id không phải số. | Dùng `int.tryParse` và chuyển về màn lỗi. Chỉ cần thiết nếu sau này thêm deep link. |
| L14 | `lib/features/projects/services/project_report_pdf_service.dart:718, :754`; `lib/screens/color_sorter/color_sorter_screen.dart:95` | 3 vấn đề analyzer trong `lib/` (2 hàm không dùng, 1 `if` thiếu ngoặc). | Xóa hàm không dùng và thêm `{}`. |
| L15 | Thư mục gốc, `bin/`, `scratch/` | Script phụ (`extract_pdf.dart`, `read_excel_*.dart`, `scratch/scrape_h7.dart` import `http` không có trong dependencies…) tạo 86/89 vấn đề analyzer. | Chuyển sang `tool/` hoặc thêm vào `analyzer.exclude`; xóa các script không còn dùng. |

---

## 5. Tính năng "Vị trí nhà máy": kết quả rà soát chi tiết

| Hạng mục | Kết quả |
|---|---|
| Luồng xin quyền | Đạt. Kiểm tra dịch vụ vị trí, rồi `checkPermission`, rồi `requestPermission`; phân biệt từ chối tạm thời và từ chối vĩnh viễn. |
| Từ chối vĩnh viễn | Đạt. Có giải thích bằng tiếng Việt và nút "Mở Cài đặt" (ẩn trên web vì không mở được). |
| GPS tắt | Đạt. Nhắc bật vị trí, nút "Bật vị trí" mở `openLocationSettings`. |
| Hết thời gian chờ (30 giây) | Đạt. Báo lỗi rõ ràng và có "Thử lại". Đề xuất thêm phương án dự phòng (L11). |
| Không có mạng | Đạt về logic: định vị bằng GPS và lưu SQLite không cần mạng. Cần thử trên máy thật (lần định vị đầu có thể chậm). |
| Độ chính xác | Hiển thị ±m, tô cam khi trên 50 m. **Chưa xử lý vị trí gần đúng** (M6). |
| Tạo link | Đạt. Link `https://www.google.com/maps/search/?api=1&query=lat,lng` với 6 chữ số thập phân (sai số khoảng 0,1 m); có test. |
| Dán link | Đạt với các dạng `?q=`, `?query=`, `ll=`, `@lat,lng`, `!3d!4d` và tọa độ thô; link rút gọn có thể không đọc được (L12). |
| Mở Google Maps | `launchUrl(externalApplication)`; nếu thất bại thì thử `platformDefault`, cuối cùng báo lỗi. Manifest đã có `<queries>`. Cần thử trên máy thật. |
| Chia sẻ | Đạt. Dùng `SharePlus.instance.share(ShareParams)` (API hiện hành); có `sharePositionOrigin` cho iPad. |
| Lưu/sửa/xóa | Đạt. Xóa có hộp xác nhận, trùng tên có cảnh báo, có test CRUD. |
| Quyền khai báo | Đạt cho FINE/COARSE và `NSLocationWhenInUseUsageDescription`. **Cần gỡ quyền dịch vụ chạy nền mà plugin tự thêm** (H1). |

---

## 6. Danh sách PHẢI sửa trước khi phát hành

1. **C1**: Đổi `applicationId` và `namespace` Android sang ID chính thức.
2. **C2**: Đổi Bundle ID iOS; trong Xcode đặt Team ký (`DEVELOPMENT_TEAM` hiện đang trống) và tạo app trên App Store Connect.
3. **H1**: Gỡ `FOREGROUND_SERVICE_LOCATION` và service của geolocator khỏi manifest.
4. **H2**: Xác nhận giấy phép Syncfusion.
5. **H3**: Sửa lỗi tràn ở màn chi tiết hồ sơ máy nghiền.
6. **H4**: Tôn trọng cỡ chữ hệ thống.
7. **H5**: Có URL chính sách quyền riêng tư; điền Data safety (Play) và App Privacy (Apple).
8. **H6**: Xác minh căn chỉnh 16 KB trên bản AAB.
9. **M1**: Bọc `try/catch` cho các thao tác lưu/xóa ở "Mục tiêu doanh số".
10. **M7**: Đưa `flutter test` về 100% đạt.
11. Commit toàn bộ 94 thay đổi đang dở, gộp vào nhánh chính và gắn tag `v1.0.14` trước khi build bản phát hành.

**Nên sửa trong lần phát hành này nếu kịp:** M2, M4, M5, M6, M9, L1, L4, L5.

---

## 7. Cần tự kiểm tra trên thiết bị thật

**Chung (Android, gồm 1 máy cấu hình yếu hoặc màn nhỏ khoảng 5", và iPhone)**
- [ ] Cài bản release (không phải debug), mở lần đầu: không màn đen hoặc crash; icon và tên app đúng.
- [ ] Chế độ tối: duyệt các màn chính, chữ và nền đủ tương phản (màu cứng kiểu `Color(0xFF102F46)` có thể khó đọc trên nền tối).
- [ ] Cỡ chữ hệ thống lớn nhất và cỡ chữ "Rất lớn" trong app: không tràn chữ hay nút bị che (đặc biệt Home, menu lưới, form, bảng so sánh máy).
- [ ] Xoay ngang (app cho phép xoay ngang trên iPhone và iPad).
- [ ] Android 15+: nội dung không bị thanh trạng thái hoặc thanh điều hướng che (chế độ edge-to-edge bắt buộc).
- [ ] Thông báo nhắc hẹn: xin quyền thông báo trên Android 13+ và iOS; nhắc đúng giờ; vẫn nhắc sau khi khởi động lại máy.
- [ ] Chụp ảnh và chọn ảnh ở 4 module (lưu mẫu, dự án, báo cáo bảo trì, mặt bằng); từ chối quyền camera hoặc ảnh thì có thông báo dễ hiểu.
- [ ] Tạo, xuất và chia sẻ PDF (báo cáo bảo trì, lưu mẫu, mặt bằng) qua Zalo, Email; mở PDF catalog.
- [ ] Mô hình 3D và video: tải được, không giật nặng hay crash trên máy yếu.
- [ ] Bật chế độ máy bay rồi dùng toàn app: các chức năng offline hoạt động; chức năng cần mạng báo lỗi bằng tiếng Việt.
- [ ] Đóng app khi đang ở màn sâu (hoặc bật "Không giữ hoạt động" trong Tùy chọn nhà phát triển) rồi mở lại: không crash (liên quan M3).
- [ ] Cập nhật từ bản cũ lên bản mới: dữ liệu ghi chú, báo cáo, dự án còn nguyên (chỉ đúng khi ID không đổi; xem C1).

**Vị trí nhà máy**
- [ ] Lần đầu bấm "Định vị": hộp thoại xin quyền hiện chuỗi mô tả tiếng Việt (iOS).
- [ ] Chọn "Vị trí gần đúng" (Android 12+) hoặc tắt "Vị trí chính xác" (iOS): xem sai số và thông báo hiển thị (M6).
- [ ] Từ chối 2 lần (Android) hoặc "Don't Allow" (iOS): nút "Mở Cài đặt" mở đúng trang quyền của app; cấp quyền xong quay lại định vị được.
- [ ] Tắt GPS: thông báo hiện và nút "Bật vị trí" mở đúng trang.
- [ ] Trong nhà máy, cạnh mái tôn hoặc tầng hầm: đo thời gian lấy vị trí và sai số; thử "Định vị lại" ngoài trời.
- [ ] Chế độ máy bay (GPS bật): vẫn định vị và lưu được.
- [ ] "Mở Google Maps": máy có app Google Maps thì mở trong app; máy không có (hoặc iPhone chưa cài) thì mở bằng Safari hoặc Chrome, ghim đúng vị trí.
- [ ] "Chia sẻ" qua Zalo/Messenger: người nhận bấm link ra đúng vị trí; trên iPad bảng chia sẻ hiện cạnh nút.
- [ ] Dán link `maps.app.goo.gl` khi có mạng và khi mất mạng.

---

## 8. Lệnh build release đề xuất

Trước khi build: tăng `version` trong `pubspec.yaml` (ví dụ `1.0.15+16`). `versionCode` phải luôn tăng cho mỗi lần tải lên Play, và build number cho mỗi lần tải lên App Store Connect.

**Android: App Bundle cho Google Play**
```bash
flutter clean
flutter pub get
flutter test
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols/android/1.0.15+16
# Kết quả: build/app/outputs/bundle/release/app-release.aab
```

**iOS: IPA cho App Store Connect** (chạy trên macOS có Xcode và đã đặt Team ký)
```bash
flutter clean
flutter pub get
cd ios && pod install --repo-update && cd ..
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/symbols/ios/1.0.15+16 \
  --export-method app-store-connect
# Kết quả: build/ios/ipa/*.ipa (tải lên bằng Transporter hoặc `xcrun altool`)
```

**Lưu ý về symbols:**
- **Lưu trữ thư mục `build/symbols/...` của từng phiên bản** ở nơi an toàn, ngoài thư mục `build/` vì `flutter clean` sẽ xóa nó. Thiếu thư mục này thì không đọc được stack trace của bản đã obfuscate:
  ```
  flutter symbolize -i <stacktrace.txt> -d build/symbols/android/1.0.15+16/app.android-arm64.symbols
  ```
- Nếu dùng Crashlytics (M2), tải thư mục symbols lên bằng `firebase crashlytics:symbols:upload`.
