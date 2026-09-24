# Database — Máy nghiền

**Version hiện tại: 5** (file `grinding_machines.db`, `GrindingMachineDatabase`, `lib/features/grinding_machine/data/grinding_machine_database.dart`).

Hằng số `GrindingMachineDatabase.currentVersion` là nguồn duy nhất cho số version — không hard-code số `5` ở nơi khác.

## Catalog vs Workflow

| | Catalog máy | Workflow |
|---|---|---|
| Nguồn dữ liệu | Excel/JSON import (`GrindingMachineImporter`) | Người dùng tự tạo trong app |
| Phục hồi | Import lại từ file nguồn | Chỉ qua Backup/Restore (Phase 11) |
| Nằm trong Backup? | **Không** | Có |
| Bị xóa khi `importSnapshot` replace-all? | Có (đó là mục đích) | **Không bao giờ** |

## Bảng Catalog (8 bảng)

`grinding_series`, `grinding_machines`, `grinding_extra_specs`, `grinding_selection_tags`, `grinding_materials`, `grinding_material_series_map`, `grinding_ai_config`, `grinding_db_meta`.

`GrindingMachineRepository.importSnapshot()` xóa và ghi lại TOÀN BỘ 8 bảng này trong 1 transaction khi cập nhật catalog — không đụng 2 domain workflow bên dưới. Dùng cho (1) auto-seed lần đầu mở app từ asset đóng gói (`GrindingMachineProvider.loadHome()`), và (2) quy trình developer cập nhật catalog từ file Excel/JSON mới (xem [DATABASE_UPDATE.md](DATABASE_UPDATE.md)) — **không** còn chức năng cập nhật catalog trên UI người dùng cuối.

## Bảng Engineering Project

```
grinding_selection_projects(
  id, projectName, customerName, contactName, contactInfo,
  materialId, materialName, requiredCapacityKgH, requiredFinenessValue,
  requiredFinenessUnit, feedSizeMm, maxMotorKw, application, notes,
  status,                      -- draft|evaluating|selected|completed
  nextFollowUpAt, followUpNote,-- Phase 10, thêm ở v5
  createdAt, updatedAt
)
grinding_selection_project_machines(
  id, projectId, machineId, role,  -- role: 'primary' (tối đa 1) | 'shortlist'
  addedAt
)
```

## Bảng Technical Proposal

```
grinding_proposals(
  id, projectId, proposalNumber,   -- CHUNG cho mọi revision cùng chain
  status,                          -- draft|final|sent|accepted|rejected
  currency,                        -- 'VND' | 'USD', không tự quy đổi
  machineId, machineUnitPrice, machineQuantity, discount, vatPercent, notes,
  technicalSnapshotJson,           -- JSON, ghi 1 LẦN lúc Finalize, không đổi sau đó
  rootProposalId,                  -- self-reference: R0 trỏ chính nó, R1+ trỏ về R0
  revision,                        -- 0,1,2... — UNIQUE(rootProposalId, revision)
  validityDays, deliveryTime, warranty, paymentTerms,
  sentAt, acceptedAt, rejectedAt, responseNote,
  createdAt, updatedAt, finalizedAt
)
grinding_proposal_line_items(
  id, proposalId, kind,   -- 'accessory' | 'additional_cost'
  name, quantity, unitPrice, note, sortOrder
)
```

Index quan trọng: `UNIQUE INDEX idx_grinding_proposals_chain_revision ON grinding_proposals(rootProposalId, revision)` — lưới an toàn cuối chặn 2 revision trùng số trong cùng chain (Repository vẫn luôn tự tính `MAX(revision)+1` trong transaction, index chỉ là phòng hờ race).

`proposalNumber` **không** có UNIQUE constraint (khác Phase 8 ban đầu) — vì mọi revision cùng 1 chain dùng chung số báo giá.

## Foreign Key

Database này **không khai báo FOREIGN KEY constraint** ở tầng SQL cho bất kỳ quan hệ nào (projectId, proposalId, rootProposalId, machineId...) — quan hệ được đảm bảo ở tầng ứng dụng (Repository). Đây là quyết định có chủ đích: cho phép `machineId` tham chiếu tới 1 máy đã bị xóa khỏi catalog (khi catalog update) mà không làm hỏng project/proposal lịch sử — UI hiển thị "Machine no longer available" thay vì lỗi FK.

## Lịch sử Migration

| Version | Phase | Thay đổi |
|---|---|---|
| 1 | 1-4 | Chỉ catalog máy |
| 2 | 7 | + `grinding_selection_projects`, `grinding_selection_project_machines` |
| 3 | 8 | + `grinding_proposals`, `grinding_proposal_line_items` (chưa có revision chain) |
| 4 | 9 | + revision chain (`rootProposalId`, `revision` cột mở rộng), + 9 cột thương mại/status mới, bỏ UNIQUE trên `proposalNumber`, thêm `UNIQUE(rootProposalId, revision)` |
| 5 | 10 | + `nextFollowUpAt`, `followUpNote` trên `grinding_selection_projects` |

### Chiến lược migration

- `_create(db, version)` luôn dựng **schema đầy đủ hiện tại** (dùng cho cài mới thật VÀ cho test `createSchemaForTesting`).
- `_upgrade(db, oldVersion, newVersion)` chạy các khối `if (oldVersion < N)` độc lập — mỗi khối chỉ áp dụng đúng 1 lần bất kể nhảy từ version nào.
- Khi 1 bảng CHƯA TỪNG tồn tại (`oldVersion` nhỏ hơn version bảng đó ra đời) → tạo bảng mới với schema ĐẦY ĐỦ hiện tại (không cần ALTER thêm).
- Khi bảng ĐÃ tồn tại từ phiên bản cũ hơn → dùng `ALTER TABLE ADD COLUMN`, hoặc nếu cần bỏ constraint (VD UNIQUE trên `proposalNumber` ở v3→v4) → rebuild bảng theo quy trình chuẩn SQLite (rename → tạo bảng mới → copy dữ liệu → xóa bảng cũ).
- Đã test đầy đủ các đường nhảy version thật: v1→v5, v2→v5, v3→v5, v4→v5, và v5 fresh install (`test/grinding_migration_chain_test.dart`).

**Nguyên tắc**: không bump `databaseVersion` nếu không có thay đổi schema thật. Phase 12 giữ nguyên version 5.
