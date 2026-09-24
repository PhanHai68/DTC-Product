# Module "Máy nghiền" (Grinding Machine) — v1.0

## Mục tiêu

Module hỗ trợ kỹ sư/sales của DTC Group trong toàn bộ vòng đời tư vấn bán máy nghiền:

1. Tra cứu catalog máy nghiền (dòng máy, thông số kỹ thuật) từ dữ liệu Excel/JSON nội bộ.
2. Chọn máy phù hợp với yêu cầu khách hàng (công suất, độ mịn, kích thước liệu, công suất motor...), minh bạch giữa "đạt", "không đạt" và "chưa đủ dữ liệu để xác định".
3. Lưu lại hồ sơ dự án khách hàng (Saved Project) — vật liệu, yêu cầu, máy đã chọn, shortlist so sánh, lịch follow-up.
4. Tạo báo giá kỹ thuật (Proposal) gắn với dự án — phụ kiện, chi phí phát sinh, thương mại (giá/số lượng/giảm giá/VAT), snapshot thông số kỹ thuật đóng băng tại thời điểm chốt.
5. Theo dõi vòng đời báo giá qua các revision (R0, R1, R2...) và trạng thái thương mại (Draft → Final → Sent → Accepted/Rejected).
6. Tổng quan (Dashboard) tình trạng dự án/báo giá, giá trị thương mại theo currency, báo giá sắp/đã hết hạn, việc cần follow-up.
7. Backup/Restore dữ liệu workflow (không gồm catalog máy) để phòng mất dữ liệu.

## Architecture

Toàn bộ module nằm trong `lib/features/grinding_machine/`, theo 1 luồng phụ thuộc DUY NHẤT:

```
Screens (UI)
   │  đọc/ghi qua
   ▼
Providers (ChangeNotifier — cache list, loading/error state, gọi Repository/Service)
   │
   ▼
Services (business logic thuần Dart — Calculator, Validation, Workflow, Diff, Dashboard, Backup)
   │
   ▼
Repositories (data access — CHỈ đụng bảng của domain mình)
   │
   ▼
GrindingMachineDatabase (1 file SQLite duy nhất `grinding_machines.db`, nhiều domain dùng chung)
```

Widget **không bao giờ** query SQLite trực tiếp hay tự tính toán nghiệp vụ (VD tổng tiền, MATCH/NOT_MATCH/UNKNOWN, KPI Dashboard) — luôn qua Service.

### 3 domain trong cùng 1 database

| Domain | Bảng | Repository | Ghi chú |
|---|---|---|---|
| Catalog máy | `grinding_series`, `grinding_machines`, `grinding_extra_specs`, `grinding_selection_tags`, `grinding_materials`, `grinding_material_series_map`, `grinding_ai_config`, `grinding_db_meta` | `GrindingMachineRepository` | Nguồn từ Excel/JSON import, replace-all khi cập nhật |
| Engineering Project | `grinding_selection_projects`, `grinding_selection_project_machines` | `GrindingSelectionProjectRepository` | Hồ sơ khách hàng + máy đã chọn/shortlist + follow-up |
| Technical Proposal | `grinding_proposals`, `grinding_proposal_line_items` | `GrindingProposalRepository` | Báo giá + revision chain + line items + snapshot |

Mỗi Repository CHỈ ghi/đọc bảng của domain mình — ngoại lệ duy nhất là `GrindingBackupService.restore()`, cần transaction xuyên 2 domain (Project + Proposal) để Restore atomic (xem [BACKUP_RESTORE.md](BACKUP_RESTORE.md)).

## Lịch sử phase

| Phase | Nội dung |
|---|---|
| 1-4 | Data Foundation, Browse, Filter/Compare, Machine Selection (engine cũ) |
| 5 | Database Update (Excel/JSON import + preview/validate/confirm — **đã gỡ khỏi UI production sau Phase 12**, xem [DATABASE_UPDATE.md](DATABASE_UPDATE.md)) |
| 6 | Machine Selector 3-trạng thái (MATCH/NOT_MATCH/UNKNOWN), Saved Projects nền tảng |
| 7 | Engineering Workflow đầy đủ (CRUD, primary/shortlist, re-evaluate, Project PDF) |
| 8 | Technical Proposal (Draft/Final, Calculator, Technical Snapshot, PDF) |
| 9 | Proposal Revision (R0/R1/R2...), Status (Sent/Accepted/Rejected), Validity/Expiry, Diff |
| 10 | Project Dashboard & Commercial Tracking, Follow-up |
| 11 | UX Polish, Validation, Backup/Restore, Migration chain, Double-submit fix |
| 12 | Final QA, Release Readiness — v1.0 |

## Tài liệu liên quan

- [USER_GUIDE.md](USER_GUIDE.md) — hướng dẫn sử dụng cho người dùng cuối.
- [DATABASE.md](DATABASE.md) — schema, migration, version hiện tại.
- [DATABASE_UPDATE.md](DATABASE_UPDATE.md) — quy trình developer cập nhật catalog máy từ Excel/JSON (KHÔNG còn chức năng này trên UI người dùng cuối).
- [BACKUP_RESTORE.md](BACKUP_RESTORE.md) — backup/restore dữ liệu workflow.
- [DEVELOPER.md](DEVELOPER.md) — quy ước code, invariant bắt buộc giữ.
- [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) — checklist trước khi phát hành.
- [RELEASE_NOTES_v1.0.md](RELEASE_NOTES_v1.0.md) — tóm tắt tính năng v1.0 + giới hạn đã biết.

## Test

Toàn bộ test nằm ở `test/grinding_*.dart` (không có thư mục con riêng — theo đúng convention hiện tại của repo). Chạy:

```
flutter test $(ls test/grinding*.dart)
```

Tính đến v1.0: **260+ test PASS** (xem RELEASE_CHECKLIST.md cho số liệu chính xác của lần chạy release gần nhất).
