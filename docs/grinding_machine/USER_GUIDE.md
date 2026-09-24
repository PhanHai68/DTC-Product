# Hướng dẫn sử dụng — Máy nghiền

Mở module từ Home app → **Máy nghiền**.

## 1. Tra cứu máy

Từ màn hình chính, chạm ô tìm kiếm hoặc chọn 1 dòng máy để xem danh sách model. Chạm 1 model để xem chi tiết thông số kỹ thuật đầy đủ.

## 2. Lọc máy

Chạm icon **Bộ lọc** (góc trên) để lọc theo công suất, độ mịn, công suất motor, dòng máy... Kết quả cập nhật ngay khi nhập, không cần bấm nút tìm.

## 3. So sánh

Chạm icon **So sánh model** để chọn 2 model trở lên xem song song. Thông số nào 1 model có mà model khác không có vẫn hiển thị đủ (không bị cắt).

## 4. Chọn máy phù hợp

Từ Home, chạm **"Chọn máy phù hợp"**. Nhập yêu cầu khách hàng (nguyên liệu, công suất, độ mịn...). Kết quả trả về mỗi model kèm nhãn:

- **MATCH** — đạt yêu cầu.
- **NOT_MATCH** — không đạt.
- **UNKNOWN** — máy chưa có đủ dữ liệu để xác định (không phải "không đạt").

Chọn 1 model làm máy chính, có thể thêm vào shortlist để so sánh.

## 5. Tạo Project (lưu hồ sơ)

Sau khi chọn máy, bấm **Save Project** để lưu hồ sơ (tên dự án, khách hàng, yêu cầu, máy đã chọn). Xem lại qua **Saved Projects** ở Home.

Trong Project Detail có thể:
- **Edit Project** — sửa yêu cầu, chạy lại đề xuất.
- **Compare** — so sánh các máy trong shortlist.
- **Export PDF** — xuất báo cáo lựa chọn máy.
- **Delete** — xóa hồ sơ (không thể hoàn tác).

## 6. Tạo Proposal (báo giá)

Từ Project Detail, chạm **Create Proposal**. Nhập:
- Đơn giá/số lượng máy.
- Phụ kiện (Accessories) và chi phí phát sinh (Additional Costs — vận chuyển, lắp đặt...).
- Giảm giá (số tiền, không phải %), VAT (%).
- Điều khoản: thời gian giao hàng, bảo hành, thanh toán, số ngày hiệu lực báo giá.

Bấm **Save Draft** để lưu nháp (sửa được tự do), hoặc **Finalize** để chốt — lúc này thông số kỹ thuật của máy được **đóng băng** vào báo giá, sau đó dù catalog máy có cập nhật, báo giá đã Final KHÔNG đổi.

## 7. Revision (sửa báo giá đã chốt)

Báo giá Final không sửa trực tiếp được. Muốn thay đổi (khách yêu cầu giảm giá, đổi máy...), bấm **Create Revision** — tạo bản mới (R1, R2...) kế thừa dữ liệu bản trước, sửa tự do ở bản mới, bản cũ giữ nguyên vĩnh viễn.

Trạng thái báo giá:

```
Draft → Final → Sent → Accepted
                     ↘ Rejected
```

- **Mark as Sent** — đánh dấu đã gửi khách hàng.
- **Mark Accepted / Mark Rejected** — ghi nhận phản hồi khách hàng.
- Xem toàn bộ lịch sử revision ở mục **Revision History** trong Proposal.

## 8. Dashboard

Từ Home, chạm **Dashboard** để xem tổng quan: số dự án theo trạng thái, số báo giá theo trạng thái, tổng giá trị Accepted/Sent/Open Pipeline (tách riêng VND/USD), báo giá sắp hết hạn, báo giá cần follow-up, hoạt động gần đây. Chạm vào 1 số liệu để xem danh sách chi tiết.

## 9. Follow-up

Trong Project Detail, bấm **Set Follow-up** để đặt ngày cần liên hệ lại khách hàng + ghi chú. Dashboard sẽ tự nhóm các dự án cần follow-up vào **Overdue** (quá hạn), **Due Today** (hôm nay), **Upcoming** (sắp tới).

## 10. Backup

Từ Home, chạm icon **Backup & Restore** → **Export Backup**. File chứa toàn bộ dự án/báo giá/follow-up (KHÔNG chứa catalog máy). Chia sẻ/lưu file qua hộp thoại chia sẻ của điện thoại.

> ⚠️ File backup có thể chứa thông tin khách hàng và giá — chỉ chia sẻ cho người tin tưởng.

## 11. Restore

Ở màn **Backup & Restore**, chạm **Select Backup File**, chọn file `.dtcbackup`/`.json` đã export trước đó. Xem trước số liệu (created date, số dự án/báo giá trong file so với hiện tại), sau đó bấm **Restore**.

> ⚠️ Restore sẽ **thay thế toàn bộ** dự án/báo giá hiện tại bằng dữ liệu trong file backup. Nên Export Backup dữ liệu hiện tại trước khi Restore, phòng trường hợp cần quay lại.

Catalog máy (dòng máy, thông số kỹ thuật) không bị ảnh hưởng khi Restore.
