# Developer Notes — Máy nghiền

Đọc file này trước khi sửa module `lib/features/grinding_machine/`. Mục tiêu: AI/dev sau này không vô tình phá các invariant đã được test kỹ qua 12 phase.

## Directory structure

```
lib/features/grinding_machine/
  models/        # Value object thuần Dart, có fromRow()/toRow()/toJson() khi cần
  data/          # GrindingMachineDatabase — schema + migration, 1 file SQLite duy nhất
  repositories/  # Data access — MỖI repository CHỈ đụng bảng của domain mình
  services/      # Business logic thuần Dart (Calculator, Validation, Workflow, Diff,
                 #   Dashboard, Backup, PDF, Selection Engine...) — KHÔNG import Widget
  providers/     # ChangeNotifier — cache list + loading/error, gọi Repository/Service
  screens/       # UI — KHÔNG tự query DB, KHÔNG tự tính nghiệp vụ
  utils/         # Helper thuần (format số, parse số...)
```

## Quy tắc Provider/Repository

- 1 Repository = 1 domain (catalog / project / proposal). Không cross-write bảng của domain khác.
- Ngoại lệ DUY NHẤT: `GrindingBackupService.restore()` — cần transaction xuyên project+proposal để Restore atomic thật sự. Đây là quyết định có chủ đích, không phải vi phạm quy tắc.
- Provider chỉ: load, cache, gọi Repository/Service, expose `isLoading`/`error`. Không đặt business calculation trong Provider (đặt ở Service).
- Widget chỉ đọc qua Provider (hoặc gọi thẳng Service pure-function khi cần tính hiển thị, KHÔNG query DB trực tiếp).

## Quy tắc test

- Dùng `sqflite_common_ffi` in-memory (`inMemoryDatabasePath`) + `GrindingMachineDatabase.forTesting(db)`.
- `createSchemaForTesting(db)` = schema đầy đủ hiện tại; `upgradeSchemaForTesting(db, old, new)` = chạy đúng `_upgrade` thật.
- Test migration phải dựng ĐÚNG schema lịch sử từng version (không giả lập tùy tiện) — xem `test/grinding_migration_chain_test.dart`.
- Bất kỳ async DB/FFI call nào bên trong `testWidgets` phải bọc `tester.runAsync()` — vi phạm gây hang hoặc lỗi bất đồng bộ sau khi test đã "xong".

---

## CRITICAL INVARIANTS — không được phá

### 1. Missing technical value = UNKNOWN, không phải zero/false

Khi 1 tiêu chí selection (công suất, độ mịn...) không đủ dữ liệu để so khớp, kết quả PHẢI là `UNKNOWN` — không được coi là `NOT_MATCH`, và tuyệt đối không quy về `0`. Áp dụng ở `GrindingMachineSelectionService` và toàn bộ derive từ đó.

### 2. Final Proposal dùng frozen Technical Snapshot

Từ thời điểm `finalizeProposal()`, Proposal đọc `technicalSnapshotJson` đã đóng băng — KHÔNG bao giờ đọc lại catalog máy hiện tại nữa, kể cả khi máy đó sau này bị xóa/sửa trong catalog. Chỉ Draft mới đọc live qua `GrindingMachineProvider`.

### 3. Revision đã Final là immutable

Một khi 1 revision đã Final/Sent/Accepted/Rejected, dữ liệu của NÓ (thương mại, line items, snapshot) không bao giờ bị sửa lại. Muốn thay đổi → `createRevision()` tạo bản mới (R+1), bản cũ giữ nguyên vĩnh viễn. Không có API "un-finalize" hay "edit Final trực tiếp".

### 4. Dashboard/Commercial KPI chỉ tính LATEST REVISION mỗi chain

Mọi tổng hợp theo proposal (đếm status, tổng tiền, expiring...) PHẢI nhóm theo chain (`GrindingProposal.groupByChain`) rồi chỉ lấy `chain.last` (revision cao nhất). Không bao giờ cộng dồn nhiều revision của cùng 1 chain vào cùng 1 KPI.

### 5. VND và USD không cộng chung, không tự quy đổi

Mọi tổng tiền là `Map<String, double>` theo currency. Không có "Total" gộp 2 currency. Không có logic tỷ giá ở bất kỳ đâu trong module.

### 6. Commercial "incomplete" không được tính là tổng hợp lệ

`GrindingProposalCalculator.grandTotal` KHÔNG BAO GIỜ null (thiết kế có chủ đích từ Phase 8 — thiếu field thì coi phần đó là 0 khi cộng nội bộ), nhưng `hasIncompleteData == true` báo hiệu tổng đó KHÔNG đáng tin. Dashboard/Commercial Summary phải LOẠI các proposal `hasIncompleteData == true` khỏi mọi tổng tiền, đếm riêng vào "incomplete count" — không hiển thị số liệu sai lệch như thể đầy đủ.

### 7. Restore là Replace transaction, không có partial state

`GrindingBackupService.restore()` xóa sạch 4 bảng workflow rồi ghi lại từ backup trong 1 transaction. Lỗi bất kỳ ở đâu → rollback toàn bộ. Không bao giờ để trạng thái "project đã restore, proposal chưa" tồn tại.

### 8. Backup không chứa catalog máy

`GrindingBackupService` chỉ export/restore 4 bảng workflow. Catalog máy phục hồi qua import Excel/JSON (xem DATABASE_UPDATE.md), không qua Backup/Restore.

---

## Các quy ước khác cần biết

- **`discount` là SỐ TIỀN, không phải %.** VAT mới là %. Đừng nhầm khi thêm validation/tính toán mới.
- **Null ≠ 0** xuyên suốt module — field thương mại/kỹ thuật chưa nhập giữ `null`, hiển thị "—"/"Not specified", không bao giờ tự điền `0`.
- **`proposalNumber` dùng chung cho cả chain** — không sinh số mới khi Create Revision.
- **Revision mới luôn derive `MAX(revision)+1` bên TRONG transaction ở Repository**, không tính ở UI (tránh race).
- **Accepted conflict**: nếu 1 chain đã có revision Accepted, không cho Accept thêm revision khác trong cùng chain (chặn ở `GrindingProposalRepository.markAccepted`, trả `false` thay vì throw).
- **Double-submit**: mọi action ghi DB quan trọng phải guard bằng kiểm tra field cờ (`if (_isSaving) return;`) NGAY ĐẦU hàm — không chỉ dựa vào `onPressed: flag ? null : action` (rebuild không kịp nếu 2 tap tới rất gần nhau, xem bug đã fix ở Phase 11).
- **Số nhập tay**: dùng `GrindingNumberParser` (chấp nhận dấu `,` như dấu thập phân, loại NaN/Infinity) — không tự viết `double.tryParse` rải rác.
