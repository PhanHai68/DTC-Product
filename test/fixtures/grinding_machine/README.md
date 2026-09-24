Fixture `ai_ready.xlsx` là bản workbook `DTC_Grinding_Machine_Database_AI_Ready.xlsx`
đã dùng để tạo seed Phase 1. Giữ trong Git để test không phụ thuộc thư mục
`docs_database/` bị ignore. Test đối chiếu toàn bộ bảy nhóm dữ liệu được import
với `assets/database/grinding_machine_seed.json`.

Version chính thức lấy từ dòng **Database version** của sheet README (1.1).
Update_Log có mốc 2.0 cho các sheet AI; không dùng lịch sử để ghi đè version.
