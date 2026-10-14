# Database sản phẩm (assets/database)

Thông số máy của app nằm trong các file JSON ở thư mục này. Muốn thêm hoặc
sửa model: sửa file JSON tương ứng, chạy `flutter test`, rồi build bản mới.
Không cần sửa code Dart.

## Danh sách file

| File | Nội dung | Màn hình trong app |
|---|---|---|
| `color_sorter/sc_rice.json` | Máy tách màu gạo SC4 → SC16 Pro, S+80D | Máy tách màu → Gạo |
| `color_sorter/sf7_paddy.json` | Máy tách màu thóc dòng SF Pro (SF3D → SF12D) | Máy tách màu → Thóc và gạo xô |
| `color_sorter/df_tea.json` | Máy tách màu trà DF12 → DF53 Pro | Máy tách màu → Trà |
| `color_sorter/sx8_mineral.json` | Máy tách quang khoáng sản SX8 | Máy tách màu → Khoáng sản |
| `color_sorter/h7_agro.json` | Máy tách màu hạt dòng H (H1 → H12) | Máy tách màu → Nông sản |
| `color_sorter/aux_equipment.json` | Thiết bị phụ trợ theo model (SC4…SC16, SF7D Pro) | Thiết bị phụ trợ |
| `color_sorter/tea_aux_equipment.json` | Thiết bị phụ trợ dây chuyền trà | Trà → Thiết bị phụ trợ |
| `color_sorter/power_consumption.json` | Điện năng tiêu thụ cả dây chuyền theo model SC | Phân tích hoàn vốn → Điện năng, hoá đơn điện, lợi nhuận |
| `color_sorter/common_errors.json` | Tra cứu lỗi máy tách màu (dùng chung mọi dòng máy): `common` lỗi thường gặp, `detailed` nguyên nhân – khắc phục, `poorSorting` tách màu kém, `blocks` nguồn cấp – kết nối, `etmOutputs` ngõ ra ETM. Nguồn: `docs_database/01_May_Tach_Mau/00_Du_Lieu_Chung/CAC_LOI_THUONG_GAP_MAY_TACH_MAU.xlsx` | Máy tách màu (mọi dòng) → Tra cứu lỗi |
| `air_compressor/specs.json` | Thông số máy nén khí ACOMP (PM VSD, Fixed Speed) | Máy nén khí → Thông số; cũng là nguồn lưu lượng cho màn tính ống khí nén và thời gian nạp bình |
| `air_compressor/mccb_cable.json` | MCCB và cáp điện theo model | Máy nén khí → Chọn MCCB và cáp điện |
| `air_compressor/pipe_standard.json` | Bảng ống tiêu chuẩn DN ↔ mm | Máy nén khí → Tính ống khí nén |
| `air_compressor/common_errors.json` | Lỗi thường gặp: `general`, `controller`, `oilLoss` | Máy nén khí → Tra cứu lỗi |
| `air_compressor/ds8011.json` | Tham số cài đặt bộ điều khiển DS8011 | Máy nén khí → Cài đặt DS8011 |
| `air_compressor/materials.json` | Nguyên liệu và hệ số khí (`cm`, `optimalPressure`) | Máy nén khí → Chọn máy nén khí phù hợp máy tách màu |
| `packing_scale/machines.json` | 46 máy cân đóng gói (PE, PP, định lượng) | Cân đóng gói → Danh mục, tìm kiếm, chọn máy, so sánh |
| `packing_scale/features.json` | Các bộ đặc điểm nổi bật, mỗi máy chọn một bộ qua `feature_set` | Cân đóng gói → Chi tiết máy |
| `grinding_machine_seed.json` | Máy nghiền | Máy nghiền |
| `mixer_machine_catalog.json` | Máy trộn | Máy trộn |
| `sifter_machine_catalog.json` | Máy sàng | Máy sàng |
| `packing_machine_catalog.json` | Máy đóng gói | Máy đóng gói |
| `rice_milling_catalog.json` | Dây chuyền xay xát | Dây chuyền xay xát |

## Quy tắc khi sửa file máy tách màu

- **Mọi giá trị đều đặt trong ngoặc kép**, kể cả số: `"Trọng lượng (kg)": "2800"`.
  Riêng `components` trong `tea_aux_equipment.json` là danh sách `[ "...", "..." ]`.
- **Không đổi tên trường** (phần bên trái dấu `:`, ví dụ `"Năng suất (tấn/giờ)"`):
  app tìm dữ liệu theo đúng tên này. Trường mới thêm vào sẽ không hiện lên
  màn hình nếu code chưa dùng tới nó.
- Thứ tự máy trong file là thứ tự hiển thị trong app.
- Thêm model mới: chép nguyên một khối `{ ... }` của model gần giống, dán ngay
  sau nó (nhớ dấu phẩy `,` giữa hai khối), rồi sửa giá trị.
- Các file `df_tea.json`, `sx8_mineral.json`, `h7_agro.json` có trường `id`
  — mỗi máy phải có `id` riêng, không trùng.
- `h7_agro.json` không ghi máy nén khí và bình tích khí: app tự tính từ
  `ejector_qty` theo nguyên liệu "Các loại đậu" (`materials.json`), giống
  màn "Lựa chọn công suất máy nén" và "Tính thể tích bình chứa".
- `sf7_paddy.json` không ghi áp suất, lưu lượng khí, máy nén khí và bình
  tích khí: app lấy từ máy gạo (`sc_rice.json`) cùng "Số máng"; không có máy
  gạo cùng số máng thì lấy máy gần nhất (cách đều thì lấy máy ít máng hơn).
- Máy thóc không có trong `power_consumption.json`: phân tích hoàn vốn dùng
  bảng của máy gạo **cùng đúng số máng** (không có thì model đó không có hoàn
  vốn), thay "Năng suất" bằng trung bình mức thấp – cao của máy thóc và
  "Máy tách màu (kW)" bằng "Công suất điện (kW)" của máy thóc; tối đa = tổng
  các thiết bị, trung bình = 80% tối đa. Thiết bị phụ trợ cũng theo máy gạo
  cùng số máng (trừ model đã có danh sách riêng trong `aux_equipment.json`).
- Máy trà: phân tích hoàn vốn chỉ có cho model máy tách màu nằm trong
  `tea_aux_equipment.json` (hiện là DF53 Pro). App cộng công suất × số lượng
  các thiết bị trong danh sách thành "Công suất lớn nhất (kW)" và dùng số này
  để tính tiền điện (máy trà không có công suất trung bình); năng suất lấy từ
  `capacity_max_kg_h`.

## Quy tắc khi sửa file máy nén khí

- `specs.json` là **ngoại lệ**: các cột số (`powerKW`, `powerHP`, `flow7Bar`,
  `flow8Bar`, `lubricant`, `weight`) ghi **số không có ngoặc kép**, ví dụ
  `"weight": 185.0` hoặc `"weight": 185`. Các cột chữ (`modelCode`, `series`,
  `airOutlet`, `dimensions`) vẫn có ngoặc kép.
- `series` chỉ được là `"PM VSD"` hoặc `"Fixed Speed"`.
- Lưu lượng `flow7Bar`/`flow8Bar` trong `specs.json` dùng chung cho màn tính
  ống khí nén và thời gian nạp bình — chỉ sửa ở một chỗ này.
- `pipe_standard.json`: giữ các dòng theo thứ tự đường kính `mm` tăng dần;
  `mm` là số không có ngoặc kép.

## Quy tắc khi sửa file cân đóng gói

- `machines.json`: tên trường viết kiểu `snake_case` (`weight_min_kg`,
  `capacity_max`...). Cột số ghi số không có ngoặc kép (`"power_kw": 0.1`);
  ô không có dữ liệu ghi `null` (không có ngoặc kép).
- `stt` quyết định thứ tự hiển thị và không được trùng; `model` cũng không
  được trùng.
- Máy không ghi `bag_material` (để `null` hoặc `""`) được coi là dùng được
  cho mọi loại túi khi chọn máy; `weight_min_kg`/`weight_max_kg` để `null`
  nghĩa là không giới hạn.
- `feature_set` là tên một bộ trong `features.json` (ví dụ `"rice_mixer"`,
  `"pe_2_edge_auto"`, `"pp_semi"`). Nhiều máy dùng chung một bộ: sửa bộ đó
  là đổi cho tất cả các máy ấy.
- `features.json`: `icon` là tên icon Material đã khai báo trong
  `packingFeatureIcons` (`lib/models/packing_feature.dart`). Muốn dùng icon
  mới phải thêm vào bảng đó trước.
- Ảnh (`image_main_path`, `image_2_path`) phải trỏ tới file có thật trong
  `assets/images/packing/`; catalog PDF được tìm trên Google Drive theo tên
  file ở cuối `catalog_asset_path`.
- Trường tùy chọn cho model hãng khác (VD `R-APF-18` của APACK), máy DTC bỏ
  trống: `brand` (hãng, hiện nhãn "Hãng …"), `capacity_text` (năng suất ghi
  sẵn, VD "18 tấn/h", thay cho dải min – max), `weight_text` (dải khối lượng
  ghi sẵn, VD "5 - 50 kg (gạo)\n5 - 40 kg (lúa)"; vẫn ghi `weight_min_kg`/
  `weight_max_kg` để lọc khi chọn máy), `batch_weight_max_kg` (cân mẻ:
  thay dòng "Trọng lượng/túi" bằng "Khối lượng mẻ"), `accuracy` (sai số, dạng
  chữ), `components` (danh sách `{ "name", "origin", "note" }` — mục "Xuất xứ
  thiết bị").

## Kiểm tra sau khi sửa

```sh
flutter test test/product_data_test.dart test/packing/packing_scale_data_test.dart
```

Test báo rõ file nào sai cú pháp JSON (thiếu dấu phẩy, thừa dấu phẩy cuối,
thiếu ngoặc kép), model nào bị thiếu tên hoặc trùng tên, series sai, bảng ống
sai thứ tự, icon không tồn tại. VS Code cũng gạch đỏ
ngay chỗ sai cú pháp khi mở file JSON.

## Thêm một file JSON mới

Thư mục con phải được khai báo trong `pubspec.yaml` (mục `flutter: assets:`),
và đường dẫn file phải được thêm vào `ProductData.assetPaths` trong
`lib/data/product_data.dart`.
