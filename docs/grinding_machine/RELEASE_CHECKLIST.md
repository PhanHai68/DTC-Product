# Release Checklist — Máy nghiền v1.0 (Phase 12)

Chạy thật lần cuối ngày 2026-09-25, branch `phase5-codex-handoff`, commit `d4caa36` (Phase 5-11 checkpoint) + thay đổi Phase 12 (chỉ thêm test/docs, không sửa `lib/`).

- [x] `git status` xác nhận baseline sạch trước khi bắt đầu Phase 12 (working tree clean).
- [x] `flutter analyze` — 89 issues, toàn bộ ở `scratch/`/file ngoài module, **0 issue mới trong `grinding_machine`**.
- [x] Toàn bộ Grinding Machine tests chạy 1 lần — **262/262 PASS** (260 baseline Phase 11 + 2 test scale mới Phase 12).
- [x] Migration matrix: v1→v5, v2→v5, v3→v5, v4→v5, fresh v5 — PASS (`test/grinding_migration_chain_test.dart`, dựng đúng schema lịch sử thật từng version).
- [x] Backup/Restore: export round-trip, validate (corrupted/unsupported version/integrity), Restore Replace, **Restore Rollback**, missing machine reference, **PDF Snapshot Consistency sau Restore** — PASS (`test/grinding_backup_service_test.dart`).
- [x] Revision immutability + Accepted conflict + Commercial Duplicate (latest-revision-only) — PASS (`test/grinding_proposal_revision_test.dart`, `test/grinding_commercial_dashboard_service_test.dart`).
- [x] Currency separation (VND/USD không cộng gộp) — PASS.
- [x] Double-submit protection — PASS (`test/grinding_double_submit_test.dart`), bao gồm regression test cho bug double-submit đã fix ở Phase 11.
- [x] Small-screen QA 320×568 / 360×640 (Home, Dashboard, Selector, Proposal Editor, Backup/Restore) — PASS (`test/grinding_small_screen_test.dart`), không RenderFlex overflow.
- [x] Scale test 500 project / 1.500 revision — PASS (`test/grinding_scale_test.dart`), Dashboard Service không có hành vi bất thường, thời gian xử lý trong ngưỡng an toàn.
- [x] PDF: null hiển thị "—"/"Not specified" (không `null`/`NaN`/`0` giả), snapshot Final không đổi khi catalog đổi — PASS (đã có test từ Phase 8-11, xác nhận lại qua PDF Snapshot Consistency test Phase 11).
- [x] `flutter build apk --release` — PASS.
- [x] `flutter build appbundle --release` — PASS.
- [x] Dependencies — không dependency mới trong Phase 12.
- [x] TODO/FIXME/HACK/print/debugPrint audit trong `lib/features/grinding_machine/` — không có kết quả nào.
- [x] Dead code audit (route legacy `/grinding_machine/selection`) — phân loại **Legacy compatibility**, giữ nguyên (có test riêng phụ thuộc, không đứt liên kết ngoài).
- [x] TextEditingController dispose audit (file phức tạp nhất, `grinding_proposal_editor_screen.dart`) — không phát hiện leak.
- [x] Android permissions — không có permission mới do module này yêu cầu; 3 permission hiện có (`INTERNET`, `CAMERA`, `RECEIVE_BOOT_COMPLETED`) thuộc các module khác trong app.
- [x] Documentation — `README.md`, `USER_GUIDE.md`, `DATABASE.md`, `DATABASE_UPDATE.md`, `BACKUP_RESTORE.md`, `DEVELOPER.md` (gồm Critical Invariants), `RELEASE_CHECKLIST.md`, `RELEASE_NOTES_v1.0.md` — đã tạo đủ tại `docs/grinding_machine/`.
- [x] Database version giữ nguyên **5** — không bump.
- [x] Backup format version giữ nguyên **1** — không bump.
- [x] `git status` cuối Phase 12 — chỉ thêm file mới (`test/grinding_scale_test.dart`, `docs/grinding_machine/**`), không sửa file `lib/` nào, **không commit, không push**.

- [x] `flutter test` toàn bộ app (432 test) — **430/432 PASS**. 2 lỗi **pre-existing**, thuộc module khác, không liên quan Máy nghiền và Phase 12 không đụng tới:
  - `test/sample_record_preview_generation_test.dart` — thiếu file fixture `build/analysis/sample_workbook_media/.../image1.jpeg` (artifact build, không phải lỗi code).
  - `test/tea_color_sorter_access_test.dart` — assertion icon "Khoáng sản dùng icon khối đá..." sai icon hiện tại (module Máy tách màu, không liên quan Máy nghiền).
  - Toàn bộ `test/grinding_*.dart` bên trong lần chạy full app này **không có lỗi nào**.

## Ghi chú (không chặn release, chỉ ghi nhận)

- [ ] Manual smoke test trên thiết bị/emulator thật — **KHÔNG thực hiện được** trong môi trường này (không có emulator/device kết nối). Xem mục "Release Mode Smoke" trong báo cáo cuối.
