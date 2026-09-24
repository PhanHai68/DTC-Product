# Release Notes — Máy nghiền v1.0

## Tổng quan

Bản v1.0 hoàn thiện toàn bộ vòng đời tư vấn bán máy nghiền trong 1 module: tra cứu catalog, chọn máy theo yêu cầu khách hàng, quản lý hồ sơ dự án, tạo và theo dõi báo giá kỹ thuật qua nhiều lần chỉnh sửa (revision), tổng quan thương mại, và backup/restore dữ liệu.

## Tính năng chính

- **Machine database**: tra cứu, tìm kiếm, lọc theo công suất/độ mịn/công suất motor/dòng máy, xem chi tiết đầy đủ thông số kỹ thuật. Catalog được đóng gói sẵn trong app và do đội phát triển cập nhật/kiểm soát (xem [DATABASE_UPDATE.md](DATABASE_UPDATE.md)) — người dùng cuối không tự cập nhật catalog trên điện thoại.
- **Search/Filter**: tìm kiếm và lọc chạy tức thời trên dữ liệu đã tải, không cần chờ.
- **So sánh (Compare)**: so sánh nhiều model song song, giữ đủ thông số dù model khác thiếu dữ liệu đó.
- **Machine Selector**: đề xuất máy theo yêu cầu khách hàng, minh bạch 3 trạng thái MATCH/NOT_MATCH/UNKNOWN cho từng tiêu chí — không đánh đồng "thiếu dữ liệu" với "không đạt".
- **Saved Projects**: lưu hồ sơ khách hàng, máy chính + shortlist so sánh, chạy lại đề xuất khi yêu cầu thay đổi, xuất PDF báo cáo lựa chọn.
- **Follow-up**: đặt ngày + ghi chú cần liên hệ lại khách hàng, theo dõi qua Dashboard (Overdue/Due Today/Upcoming).
- **Technical Proposal**: báo giá gắn với dự án — phụ kiện, chi phí phát sinh, giảm giá, VAT, điều khoản thương mại; Draft sửa tự do, Finalize đóng băng thông số kỹ thuật vào snapshot.
- **Revision**: sửa báo giá đã chốt bằng cách tạo bản mới (R0, R1, R2...) kế thừa dữ liệu bản trước — bản cũ không bao giờ bị ghi đè.
- **Trạng thái thương mại**: Draft → Final → Sent → Accepted/Rejected, có validity/expiry theo ngày, lịch sử revision đầy đủ, so sánh thay đổi giữa 2 revision (Diff).
- **Dashboard**: tổng quan số dự án/báo giá theo trạng thái, giá trị Accepted/Sent/Open Pipeline tách riêng VND/USD, báo giá sắp/đã hết hạn, việc cần follow-up, hoạt động gần đây — tất cả tính theo revision mới nhất mỗi chuỗi báo giá, không đếm trùng.
- **Backup/Restore**: xuất/nhập toàn bộ dữ liệu dự án + báo giá (không gồm catalog máy) dưới dạng file JSON có version hóa, restore theo chế độ thay thế (Replace) trong 1 giao dịch an toàn, có rollback khi lỗi.

## Known Limitations

Các mục sau **cố tình chưa làm** ở v1.0, không phải lỗi:

- **Không có chức năng cập nhật catalog máy trên điện thoại** (đã gỡ có chủ đích khỏi UI — trước đó có ở Phase 5, nay catalog chỉ cập nhật qua build release mới do developer thực hiện, xem [DATABASE_UPDATE.md](DATABASE_UPDATE.md)).
- Không có Cloud Sync / đồng bộ nhiều thiết bị.
- Không có tài khoản người dùng / phân quyền nhiều người dùng.
- Không có CRM (quản lý pipeline khách hàng nâng cao, lịch sử liên hệ chi tiết).
- Không tự động gửi email báo giá.
- Không có push notification/nhắc nhở hệ thống (follow-up chỉ hiển thị trong app khi mở Dashboard).
- Không tự động quy đổi tỷ giá VND/USD.
- Restore chỉ hỗ trợ **Replace** (thay thế toàn bộ), chưa có chế độ **Merge**.
- Chưa có xuất báo giá ra Excel (chỉ có PDF).
- Chưa có quy trình duyệt (approval workflow) nhiều cấp cho revision — chuyển trạng thái hiện chỉ theo luồng Draft→Final→Sent→Accepted/Rejected đơn giản.
- Chưa có AI recommendation nâng cao ngoài Selection Engine dựa trên luật hiện tại.

## Future Improvements

Ý tưởng cho các bản sau — **chưa implement**, chỉ ghi nhận:

- Cloud Sync / đồng bộ đa thiết bị.
- Xác thực người dùng, phân quyền theo vai trò (sales/quản lý).
- Tích hợp CRM đầy đủ.
- Gửi báo giá qua email trực tiếp từ app.
- Push notification cho follow-up/báo giá sắp hết hạn.
- Đồng bộ dữ liệu qua server database thay vì chỉ local SQLite.
- Restore chế độ Merge (xử lý ID collision).
- Xuất báo giá ra Excel.
- Quy trình duyệt báo giá nhiều cấp.
- Gợi ý máy có hỗ trợ AI nâng cao hơn.
