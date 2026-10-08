# Phân tích mẫu AI — giai đoạn 0 và 1

Tài liệu yêu cầu: `docs_database/05_Cong_Cu_Quan_Ly_Mo_Rong/Yêu cầu kỹ thuật Phân tích mẫu nguyên liệu bằng ảnh.docx`.

Menu trong app: **Công cụ & Tiện ích → Phân tích mẫu AI** (chỉ có trên Android/iOS).

## Cấu trúc mã nguồn

| Thư mục | Nội dung |
|---|---|
| `lib/features/grain_analysis/engine/` | Thuật toán, thuần Dart, không phụ thuộc giao diện (NFR-03). Điểm vào: `GrainAnalyzer.analyze()` |
| `engine/grain_analysis_config.dart` | **Mọi ngưỡng và tham số** (NFR-05) và `grainAlgorithmVersion` (NFR-07) |
| `engine/tray_layout.dart` | Kích thước khay chuẩn A4/A3, dùng chung cho file PDF và bước nắn ảnh |
| `engine/result_calculator.dart` | Công thức mục 8 (giai đoạn 1: % số hạt, % diện tích, làm tròn) |
| `models/`, `data/`, `repositories/` | Phiên, hạt, kết quả; database riêng `grain_analysis.db` |
| `services/` | Chụp ảnh gốc không nén, chạy phân tích trong isolate, sinh PDF tấm nền |
| `screens/`, `widgets/` | Màn hình chính, chụp ảnh, kết quả và sửa tay |
| `tool/grain_count_cli.dart` | Script giai đoạn 0 |
| `test/grain_analysis/` | Unit test thuật toán, công thức, database và luồng màn hình |

Quy trình xử lý ảnh (mục 7, bước 1–5):

1. Tìm 4 mốc vuông đen có ô trắng ở giữa (không dùng ArUco, vì app không dùng OpenCV).
2. Nắn phối cảnh, tính pixelsPerMm, cân bằng trắng theo ô trắng chuẩn.
3. Tách nền theo khoảng màu Lab, ngưỡng chọn bằng Otsu.
4. Làm sạch bằng phép mở/đóng. Tách hạt chạm nhau bằng distance transform + watershed; cụm không tách được thì ước số hạt = diện tích / trung vị.
5. Bỏ bụi và vật thể chạm mép, rồi đo từng hạt.

## Tấm nền khay chuẩn

Trong app: màn **Phân tích mẫu AI → biểu tượng máy in**. Chọn khổ A4/A3 và màu nền, rồi chia sẻ file PDF đi in.

Muốn sinh sẵn đủ 6 file PDF (2 khổ × 3 màu nền) ra một thư mục:

```powershell
$env:GRAIN_TRAY_PDF_OUT = "output/khay_chuan"; flutter test test/grain_analysis/tray_pdf_service_test.dart
```

Khi in:
- Chọn tỉ lệ **100% (Actual size)**.
- In xong, đo thước 80 mm ở mép dưới tờ giấy để kiểm tra.
- Rải hạt gọn trong khung nét đứt.
- Chụp thẳng từ trên xuống, thấy đủ 4 mốc.

## Khay AnySort 21×15 cm, trắng hoặc đen (không cần in mốc)

Trong màn chụp ảnh, chọn **Khay chuẩn → Khay AnySort 21×15 cm**. Khi chạy CLI thì thêm `--tray anysort`. Nếu ô Khay chuẩn còn để tấm nền A4/A3 mà ảnh không có mốc, app tự thử khay AnySort và báo cho người dùng.

App không tìm mốc mà tìm **4 cạnh viền ngoài của khay** (150 × 210 mm), rồi nắn ảnh theo đó. Khay trắng và khay đen dùng chung một lựa chọn; app tự biết khay sáng hay tối.

Chọn khay theo màu hạt:
- **Gạo trắng, hạt màu ngà: dùng khay đen.** Trên khay trắng, gạo trắng chỉ khác nền khoảng ΔE 6–12, ngang với nhiễu do vân nứt của khay và bóng đổ, nên không đếm được.
- Hạt sẫm hoặc có màu (gạo lứt, cà phê, đậu...): dùng khay trắng.
- Chỉ có khay trắng mà cần đếm gạo trắng: lót tờ giấy hoặc nỉ đen vừa đáy khay (khoảng 14×20 cm). App vẫn tìm khay theo viền trắng, và tự nhận ra logo đã bị che.

Khi chụp:
- Khay phải khác màu hẳn mặt bàn: khay trắng trên bàn sẫm, khay đen trên bàn sáng hơn khay.
- Thấy **trọn cả viền khay** trong khung. Vật chạm góc khay (ổ cắm, dây điện) thì vẫn nhận được.
- Chụp thẳng từ trên xuống. Ảnh nghiêng quá 10° bị báo "Góc chụp".
- **Tránh vệt loáng đèn trên khay đen.** Ở chỗ loáng, vân gỗ sáng gần bằng gạo. Đây là nguồn sai số lớn nhất trên ảnh thử: nên dùng ánh sáng tản, hoặc nghiêng nguồn sáng để vệt phản chiếu không rơi vào khay.
- Rải hạt cách thành khay khoảng 1 cm và **không rải lên logo ANYSORT**. Hạt nằm đè hoặc chạm vùng logo không được đếm.
- Lau sạch vết bút, vết bẩn trên đáy khay.

Cách tính:
- **Tỉ lệ mm:** viền khay cao hơn đáy nên trông to hơn đáy. App quy tỉ lệ về mặt đáy theo chiều cao thành khay (`rimHeightMm` trong `tray_layout.dart`: 13,5 mm, người dùng đo được 12–15 mm).
- **Logo:** khay đối xứng, nên app so ảnh ở hai đầu khay với hình logo mẫu (`logoTemplate`, ô 2 mm) để biết logo ở đầu nào. Khi chụp nghiêng, app dò thêm độ lệch ±6 mm. Logo sẫm trên khay trắng và sáng trên khay đen đều nhận được.
- **Khay tối có vân** dùng tham số riêng (`darkTray…` trong `grain_analysis_config.dart`):
  - Ngưỡng tách nền tối đa ΔE 14.
  - Phép mở 0,6 mm để xoá vệt vân mảnh. Hạt phải rộng hơn 1,2 mm.
  - Bỏ vật nhỏ hơn 35% cỡ hạt chuẩn, nên mảnh hạt vỡ nhỏ hơn cũng không được đếm.
  - Bỏ vật đơn lẻ méo mó (độ đặc < 0,85).
- Ảnh đánh dấu của CLI (`--overlay`) vẽ khung xanh dương (vùng phân tích) và khung cam (vùng logo bỏ qua) để kiểm tra.

**Ảnh thử 08/10/2026:**
- Đợt 2 (`docs_database/05_Cong_Cu_Quan_Ly_Mo_Rong/anh_nguyen_lieu`, IMG_6152–6158): 7 ảnh JPG, khay đen, 50 hạt gạo trắng rải thưa, ánh sáng đều. App đếm đúng 50/50 cả 7 ảnh.
- Đợt 1: 7 ảnh HEIC, cùng một mẫu khoảng 130 hạt, hạt dày và có vệt loáng đèn.
- App đếm được 119–137 hạt, chênh ±7% giữa các ảnh. Chưa có số đếm tay nên chưa tính được sai số thật.
- Sai lệch chủ yếu do vệt loáng đèn và hạt chạm thành khay hoặc chạm logo.
- App không đọc được HEIC. Muốn chép ảnh từ iPhone sang máy tính để chạy CLI, hãy đặt **Cài đặt → Camera → Định dạng → Tương thích nhất**, hoặc chuyển sang JPG trước.

## Giai đoạn 0 — thử trên ảnh thật

1. Chụp 20–30 ảnh gạo và hạt điều trên tấm nền chuẩn, chép vào một thư mục, ví dụ `D:\anh_mau\gao`.
2. Tạo file `dem_tay.csv` trong thư mục đó, mỗi dòng `tên_file,số_hạt_đếm_tay`:
   ```
   IMG_0001.jpg,1012
   IMG_0002.jpg,987
   ```
3. Chạy (trong thư mục `DTCproduct`):
   ```powershell
   dart run tool/grain_count_cli.dart D:\anh_mau\gao --manual D:\anh_mau\gao\dem_tay.csv --overlay D:\anh_mau\gao\danh_dau
   ```
   - Khay A3 thì thêm `--tray a3`; khay trắng AnySort thì thêm `--tray anysort`.
   - Kết quả ghi vào `ket_qua_dem.csv`: số đếm, sai số %, lỗi ảnh và số đo của từng phép kiểm tra.
   - Thư mục `danh_dau` chứa ảnh có viền từng hạt: xanh lá là hạt đơn, đỏ có số là cụm ước lượng.
4. Chỉnh tham số:
   - Chạy `dart run tool/grain_count_cli.dart --write-config tham_so.json`, sửa file JSON, rồi chạy lại với `--config tham_so.json`.
   - Khi đã đạt, chép bộ tham số vào `grain_analysis_config.dart` và tăng `grainAlgorithmVersion`.

**Nghiệm thu giai đoạn 0:** trên các ảnh đạt chất lượng, đếm sai không quá 2% so với đếm tay.

Đo tốc độ trên ảnh tổng hợp 12 MP:

```powershell
dart run tool/grain_count_cli.dart --benchmark
```

## Lịch sử thuật toán

- **grain-count-1.3.1** (08/10/2026):
  - Không tách cụm thành nhiều mảnh hơn số hạt mà diện tích cụm cho phép (`splitAreaSlack`).
  - Khay tối dùng ngưỡng độ đều ánh sáng riêng 0,5 (`darkTrayMaxBackgroundUnevenness`).
  - Nghiệm thu thử: 7 ảnh khay đen, 50 hạt gạo trắng đếm tay. App đếm đúng 50/50 cả 7 ảnh (sai số 0%), cả 7 ảnh đạt chất lượng.
- **grain-count-1.3.0** (08/10/2026, sau 7 ảnh khay đen):
  - Nhận cả khay AnySort đen (tối hơn mặt bàn).
  - Nhận logo bằng tương quan với hình logo mẫu.
  - Tham số riêng cho khay tối có vân.
  - Chọn nhầm tấm nền in thì tự thử khay AnySort.
- **grain-count-1.2.0** (08/10/2026):
  - Thêm khay trắng AnySort 21×15 cm không cần mốc: tìm viền ngoài khay bằng RANSAC trên biên vùng sáng.
  - Quy tỉ lệ từ mặt viền về mặt đáy theo chiều cao thành khay.
  - Tự nhận đầu có logo và bỏ qua vùng logo.
  - Tấm nền in A4/A3 xử lý như cũ.
- **grain-count-1.1.0** (07/10/2026, sau ảnh thật đầu tiên):
  - Nền ước cục bộ theo lưới ô, chịu được giấy hoặc khay sáng không đều.
  - Tham số tính theo mm; khi không có mốc thì ước tỉ lệ từ cỡ ảnh, để kết quả không phụ thuộc độ phân giải máy.
  - Cỡ một hạt lấy theo trung vị diện tích; lọc vật thể có độ tương phản thấp (vân giấy, bóng mờ).
  - Vùng lớn hơn 25 hạt không được tính và có cảnh báo.
  - Bản 1.0.0 đếm ra hơn 110.000 hạt trên ảnh giấy trắng chụp bằng điện thoại.

## Giới hạn đã biết

- Chế độ "Đếm hạt" ước số hạt của một vật thể theo cỡ hạt phổ biến nhất trong ảnh. Nếu **trộn nhiều loại hạt khác cỡ** (ví dụ đậu lẫn gạo), hạt to sẽ bị coi là cụm 2–5 hạt. Hãy phân tích từng loại nguyên liệu riêng; giai đoạn 2 (hồ sơ nguyên liệu) sẽ phân biệt từng nhóm hạt.

- Hai hạt nằm **song song sát cạnh nhau suốt chiều dài** không tách được bằng watershed. App coi đó là một cụm và ước số hạt theo diện tích, nên số đếm vẫn đúng, nhưng hạt không có viền riêng.
- Các ngưỡng chất lượng ảnh (độ nét, độ đều ánh sáng 15%, cháy sáng 1%) đang là giá trị khởi đầu. Cần chỉnh theo ảnh thật ở giai đoạn 0.
- Ảnh HEIC từ thư viện ảnh iPhone không đọc được. Hãy chụp bằng nút **Chụp ảnh** trong app, hoặc chọn ảnh JPG/PNG.
