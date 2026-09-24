# Backup / Restore — Máy nghiền

Implement ở `GrindingBackupService` (`lib/features/grinding_machine/services/grinding_backup_service.dart`) + model `GrindingBackupPayload` (`models/grinding_backup.dart`) + UI `GrindingBackupRestoreScreen`.

## Backup format

**`backupFormatVersion = 1`** — độc lập hoàn toàn với `databaseVersion` (hiện là 5). Schema DB có thể đổi mà không bắt buộc đổi format backup, miễn field cần thiết còn đó.

Kiểu **logical backup** (JSON), không phải backup nguyên file SQLite — lý do:
- Validate được từng field trước khi ghi (file SQLite thô không tự mô tả field hợp lệ).
- Version hóa độc lập với schema DB.
- Restore được giữa các bản app khác `databaseVersion`.
- Không kéo theo catalog máy (nặng, có nguồn phục hồi riêng).

```json
{
  "type": "dtc_grinding_backup",
  "formatVersion": 1,
  "createdAt": "2026-09-24T10:00:00.000",
  "appDatabaseVersion": 5,
  "projects": [...],
  "projectMachines": [...],
  "proposals": [...],
  "proposalLineItems": [...]
}
```

## Backup scope

**Có backup**: Saved Projects (kèm follow-up), quan hệ máy đã chọn/shortlist, Proposals (mọi revision), line items, technical snapshot (JSON đã đóng băng), toàn bộ field thương mại và trạng thái (`sentAt`/`acceptedAt`/`rejectedAt`...).

**KHÔNG backup**: catalog máy nghiền (8 bảng catalog — phục hồi qua import Excel/JSON, xem [DATABASE_UPDATE.md](DATABASE_UPDATE.md)), file PDF đã export, dữ liệu derive của Dashboard (luôn tính lại từ nguồn).

## Export

`GrindingBackupService.exportPayload()` → `encode()` → chia sẻ qua `share_plus` (không dependency mới). Tên file: `DTC_Grinding_Backup_YYYYMMDD_HHmm.dtcbackup`.

## Restore — chế độ Replace

Phase 11 chỉ hỗ trợ **Replace workflow data** (không có Merge — tăng rủi ro ID collision không cần thiết):

1. Chọn file (`file_selector`, nhận `.dtcbackup`/`.json`).
2. Parse + validate (`GrindingBackupService.decode()`) — lỗi bất kỳ đều chặn, KHÔNG import một phần.
3. Preview: ngày tạo backup, format version, số project/chain/revision/line item trong backup so với hiện tại, cảnh báo số machine reference không còn trong catalog hiện tại.
4. Confirm dialog bắt buộc, nêu rõ: *"Current project and proposal workflow data will be replaced. It is recommended to export a backup before restoring."*
5. `GrindingBackupService.restore()` — **1 transaction DUY NHẤT**: xóa sạch 4 bảng workflow (`grinding_selection_projects`, `grinding_selection_project_machines`, `grinding_proposals`, `grinding_proposal_line_items`), ghi lại từ backup, **giữ nguyên ID gốc** (không remap — an toàn vì bảng đã xóa sạch trước khi insert nên không collision). Lỗi giữa chừng → rollback toàn bộ, dữ liệu cũ (trước Restore) giữ nguyên.
6. Catalog máy **không bị đụng** trong suốt quá trình Restore.
7. Sau khi restore, các Provider đang cache dữ liệu cũ (`GrindingSelectionProjectProvider`, `GrindingDashboardProvider`) được refresh lại ngay.

## Missing machine reference khi Restore

Nếu backup tham chiếu `machineId` không còn trong catalog hiện tại: Restore **vẫn thành công bình thường** — không map sang máy khác, không fail. UI hiển thị "Machine no longer available in current database" như hành vi sẵn có; Proposal Final vẫn đọc đúng technical snapshot đã đóng băng (không phụ thuộc catalog hiện tại).

## Validation khi Restore (chặn import nếu sai)

- Sai `type`/JSON hỏng/thiếu section bắt buộc/timestamp hỏng/enum status không hợp lệ → **corrupted** → *"Invalid or corrupted backup file"*.
- `formatVersion` > `supportedFormatVersion` hiện tại → **unsupportedVersion** → *"Backup format is newer than this app version."* (không đoán structure, không import).
- ID trùng lặp, revision trùng trong cùng chain, tham chiếu projectId/proposalId không tồn tại trong chính backup → **integrity** → liệt kê rõ từng lỗi.

## Dữ liệu nhạy cảm

Backup có thể chứa tên khách hàng, thông tin liên hệ, giá bán. UI cảnh báo rõ trước khi Share. App **không** tự động upload lên cloud, **không** log nội dung backup ra console.

## Test bắt buộc (đã có)

`test/grinding_backup_service_test.dart` — round-trip serialize, metadata, JSON hỏng, sai type, thiếu section, version tương lai, duplicate ID/revision, enum sai, broken FK, export dữ liệu thật, Restore Replace, **Restore Rollback** (trigger lỗi giữa transaction), missing machine reference, **PDF Snapshot Consistency sau Restore** (PDF trước/sau backup-restore giống hệt).
