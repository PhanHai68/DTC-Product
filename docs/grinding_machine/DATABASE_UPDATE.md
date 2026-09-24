# Cập nhật Catalog Máy (Database Update) — Máy nghiền

> **Thay đổi quan trọng**: kể từ sau Phase 12, module **không còn** chức năng cập nhật catalog máy nghiền ngay trên điện thoại. Catalog được quản lý hoàn toàn ở **development/build time** — người dùng cuối chỉ ĐỌC catalog đã đóng gói sẵn trong app, không có cách nào ghi/thay thế catalog từ trong ứng dụng đang chạy.

## Vì sao thay đổi

Trước đây (Phase 5) có màn hình `Database Update` cho phép người dùng chọn file Excel/JSON để thay thế catalog ngay trên điện thoại. Theo yêu cầu sản phẩm mới, catalog máy nghiền sẽ do đội phát triển kiểm soát chặt chẽ hơn — mọi thay đổi catalog đi qua quy trình source → validate → test → build release, tránh rủi ro người dùng vô tình nạp file sai/thiếu kiểm soát vào catalog đang dùng thật.

## Catalog Maintenance (quy trình hiện tại)

Machine catalog is maintained by the developer. Catalog updates require:

1. Cập nhật file Excel/JSON master (nguồn thật do đội vận hành/DTC cung cấp).
2. Validate cấu trúc + dữ liệu (`GrindingExcelParser`/`GrindingMachineImporter` + `GrindingDatabaseValidator`).
3. Cập nhật/regenerate seed đóng gói trong app: `assets/database/grinding_machine_seed.json`.
4. Chạy lại toàn bộ Grinding Machine tests + `flutter analyze`.
5. Build bản release mới (APK/AAB) và phát hành cho người dùng.

**End users cannot update the machine catalog directly from the mobile application.**

## Workflow thực tế khi có file mới

Người dùng (chủ dự án) cung cấp file Excel/JSON mới, ví dụ:

```
D:\DTC\Database\GrindingMachine\ai_ready.xlsx
```

kèm yêu cầu dạng: *"Hãy cập nhật database máy nghiền của DTC Product từ file này."*

AI/developer khi đó:

1. Đọc file được cung cấp.
2. Validate cấu trúc bằng `GrindingExcelParser.parse()` (đọc `.xlsx`) hoặc `GrindingMachineImporter.inspect()` (đọc `.json` đã convert) — trả về `GrindingImportReport` (`canImport` + danh sách lỗi/cảnh báo, KHÔNG tự suy đoán field thiếu, KHÔNG đổi `null` thành `0`).
3. So sánh với catalog hiện tại (đang đóng gói trong seed) — dùng đúng logic diff sẵn có ở `GrindingMachineProvider.previewImport()` (model thêm/xóa/đổi thông số, so sánh `databaseVersion`).
4. Báo cáo rõ: bao nhiêu model thêm, xóa, đổi thông số, và các thông số cụ thể nào thay đổi.
5. Nếu hợp lệ — cập nhật `assets/database/grinding_machine_seed.json` (nguồn seed đóng gói trong app) cho khớp dữ liệu mới.
6. Chạy `flutter test $(ls test/grinding*.dart)` — đặc biệt `test/grinding_catalog_developer_update_test.dart` (xem bên dưới) và `test/grinding_machine_excel_parser_test.dart`/`grinding_machine_importer_test.dart`.
7. Chạy `flutter analyze`.
8. Build `flutter build apk --release` / `flutter build appbundle --release`.
9. Báo cáo kết quả đầy đủ cho người yêu cầu.
10. **Không commit/push** trừ khi được yêu cầu rõ ràng.

**Không sửa file Excel/JSON nguồn để ép qua validation hoặc để test pass** — nếu dữ liệu nguồn sai, sửa ở nguồn thật, không vá trong code.

## Code/tooling vẫn được giữ (developer-only, không lộ ra UI)

| File | Vai trò | Trạng thái |
|---|---|---|
| `services/grinding_excel_parser.dart` | Đọc/validate file `.xlsx` thật (18 sheet), convert sang cấu trúc chuẩn | **Giữ nguyên** — developer tooling, có test riêng với fixture Excel thật |
| `services/grinding_machine_importer.dart` | Validate/parse JSON, xây `GrindingDatabaseSnapshot` | **Giữ nguyên** — CŨNG là core runtime (seed lần đầu mở app dùng chính API này, xem bên dưới) |
| `services/grinding_database_validator.dart` | Validate cấu trúc/số liệu chi tiết | **Giữ nguyên** |
| `repositories/grinding_machine_repository.dart` (`importSnapshot`) | Ghi catalog vào SQLite (replace-all, 1 transaction) | **Giữ nguyên** — dùng cho seed lần đầu VÀ cho developer update qua test |
| `providers/grinding_machine_provider.dart` (`previewImport`/`applyImport`/`getImportMetadata`) | Diff + version compare + orchestrate import | **Giữ nguyên** — không còn Screen nào gọi trên production UI, nhưng vẫn là API developer/test dùng trực tiếp (xem `test/grinding_catalog_developer_update_test.dart`) |
| `screens/grinding_database_update_screen.dart` | Màn hình chọn file cho người dùng cuối | **Đã xóa** |
| `services/grinding_database_file_picker.dart` | File picker CHỈ phục vụ screen trên | **Đã xóa** (không còn caller nào khác) |

## Quan trọng: auto-seed lần đầu mở app KHÔNG bị ảnh hưởng

`GrindingMachineProvider.loadHome()` tự động nạp catalog từ asset đóng gói sẵn (`assets/database/grinding_machine_seed.json`) qua `GrindingMachineImporter.parse()` + `GrindingMachineRepository.importSnapshot()` **mỗi khi app cài mới hoặc seed đóng gói có `databaseVersion` mới hơn bản đã import trước đó** — đây là phần lõi runtime, hoàn toàn tách biệt với màn hình Update Database đã xóa, và **không hề bị ảnh hưởng** bởi thay đổi này.

## Test liên quan

- **Giữ nguyên** (test parser/validate/repository, không đụng UI): `grinding_machine_excel_parser_test.dart`, `grinding_machine_importer_test.dart`, `grinding_machine_repository_test.dart`, `grinding_machine_validation_test.dart`, `grinding_selection_engine_test.dart`, và phần import trong `grinding_machine_provider_test.dart`.
- **Đã xóa**: `grinding_database_update_screen_test.dart` (test màn hình UI đã không còn tồn tại).
- **Thay thế bằng**: `grinding_catalog_developer_update_test.dart` — gọi thẳng `GrindingMachineProvider.previewImport()`/`applyImport()` với file Excel fixture thật + JSON có thay đổi thật, KHÔNG pump bất kỳ Widget nào — đúng API developer/AI sẽ dùng khi cập nhật catalog theo yêu cầu người dùng trong tương lai.

## Database version của catalog vs Database version của schema SQLite

Không nhầm lẫn 2 khái niệm:
- `databaseVersion` của **dữ liệu catalog** (VD `"1.1"`, lưu ở bảng `grinding_db_meta`) — theo dõi lần cập nhật Excel/JSON gần nhất, đổi theo dữ liệu.
- `GrindingMachineDatabase.currentVersion` (hiện là **5**) — version **schema SQLite**, chỉ đổi khi có thay đổi cấu trúc bảng thật, không liên quan tới việc cập nhật catalog.
