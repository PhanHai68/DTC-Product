import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/dtc_palette.dart';
import '../providers/fault_bank_provider.dart';
import '../services/fault_excel_export_service.dart';
import '../widgets/fault_profile_form.dart';
import '../widgets/fault_record_card.dart';
import '../widgets/machine_model_dialogs.dart';

/// Màn chính Ngân hàng lỗi: lần đầu yêu cầu hồ sơ kỹ sư, sau đó là Tra cứu.
class FaultBankHomeScreen extends StatelessWidget {
  const FaultBankHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FaultBankProvider>();
    final storageSupported = provider.photoService.storage.isSupported;

    if (!storageSupported) {
      return const _Message(
        title: 'Ngân hàng lỗi',
        icon: Icons.phone_android_rounded,
        text: 'Ngân hàng lỗi chỉ dùng trên ứng dụng Android/iOS.',
      );
    }
    if (provider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ngân hàng lỗi')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.error != null && provider.profile == null) {
      return _Message(
        title: 'Ngân hàng lỗi',
        icon: Icons.error_outline_rounded,
        text: provider.error!,
        action: FilledButton(
          onPressed: provider.init,
          child: const Text('Thử lại'),
        ),
      );
    }
    if (provider.needsProfile) return const _ProfileSetup();
    return const _SearchView();
  }
}

class _ProfileSetup extends StatelessWidget {
  const _ProfileSetup();

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ngân hàng lỗi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Icon(Icons.menu_book_rounded, size: 56, color: palette.cyan),
          const SizedBox(height: 12),
          Text(
            'Hồ sơ kỹ sư',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nhập 1 lần để bắt đầu ghi lại lỗi và cách xử lý. '
            'Sửa được trong Cài đặt của Ngân hàng lỗi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted),
          ),
          const SizedBox(height: 24),
          FaultProfileForm(onSaved: () {}, submitLabel: 'Bắt đầu'),
        ],
      ),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  late final TextEditingController _search;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: context.read<FaultBankProvider>().filter.query,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickMachine(FaultBankProvider provider) async {
    final id = await showMachineModelPicker(
      context,
      selectedId: provider.filter.machineModelId,
      allowAll: true,
    );
    if (id == null) return;
    await provider.setMachineFilter(id.isEmpty ? null : id);
  }

  Future<void> _pickGroup(FaultBankProvider provider) async {
    final palette = DtcPalette.of(context);
    final group = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.select_all_rounded),
              title: const Text('Tất cả nhóm lỗi'),
              selected: provider.filter.faultGroup == null,
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
            for (final g in provider.groupOptions)
              ListTile(
                title: Text(g),
                selected: provider.filter.faultGroup == g,
                trailing: provider.filter.faultGroup == g
                    ? Icon(Icons.check_rounded, color: palette.cyan)
                    : null,
                onTap: () => Navigator.pop(sheetContext, g),
              ),
          ],
        ),
      ),
    );
    if (group == null) return;
    await provider.setGroupFilter(group.isEmpty ? null : group);
  }

  /// Xuất các bản ghi đang khớp từ khóa/bộ lọc ra Excel rồi mở bảng chia sẻ.
  Future<void> _exportExcel(FaultBankProvider provider, Rect? origin) async {
    if (_exporting) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final records = await provider.recordsForExport();
      if (records.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Không có bản ghi nào để xuất.')),
        );
        return;
      }
      final bytes = FaultExcelExportService.buildWorkbook(records);
      final fileName = FaultExcelExportService.fileName(DateTime.now());
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: FaultExcelExportService.mimeType,
              name: fileName,
            ),
          ],
          fileNameOverrides: [fileName],
          title: 'Ngân hàng lỗi',
          subject: 'Ngân hàng lỗi (${records.length} bản ghi)',
          sharePositionOrigin: origin,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không xuất được file Excel: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final provider = context.watch<FaultBankProvider>();
    final filter = provider.filter;
    final results = provider.results;
    final machineName = provider.machineModelById(filter.machineModelId)?.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngân hàng lỗi'),
        actions: [
          Builder(
            builder: (buttonContext) => IconButton(
              key: const Key('fault_bank_export_excel'),
              tooltip: 'Xuất Excel & chia sẻ',
              onPressed: _exporting
                  ? null
                  : () {
                      final box =
                          buttonContext.findRenderObject() as RenderBox?;
                      final origin = box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size;
                      _exportExcel(provider, origin);
                    },
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_rounded),
            ),
          ),
          IconButton(
            key: const Key('fault_bank_settings_button'),
            tooltip: 'Cài đặt',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/fault-bank/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('fault_bank_add'),
        onPressed: () => context.push('/fault-bank/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ghi nhận sự cố'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              key: const Key('fault_bank_search'),
              controller: _search,
              onChanged: provider.setQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm mô tả lỗi, nguyên nhân, vật tư...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: filter.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        onPressed: () {
                          _search.clear();
                          provider.setQuery('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  key: const Key('fault_filter_machine'),
                  label: machineName ?? 'Model máy',
                  active: machineName != null,
                  onTap: () => _pickMachine(provider),
                ),
                _FilterChip(
                  key: const Key('fault_filter_group'),
                  label: filter.faultGroup ?? 'Nhóm lỗi',
                  active: filter.faultGroup != null,
                  onTap: () => _pickGroup(provider),
                ),
                if (filter.hasFilters)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: TextButton.icon(
                      onPressed: provider.clearFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                      label: const Text('Bỏ lọc'),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Row(
              children: [
                Text(
                  '${results.length} bản ghi',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (provider.isSearching) ...[
                  const SizedBox(width: 8),
                  const SizedBox.square(
                    dimension: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _buildResults(context, provider)),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, FaultBankProvider provider) {
    final palette = DtcPalette.of(context);
    final results = provider.results;
    final filter = provider.filter;
    if (results.isEmpty && !provider.isSearching) {
      final searching = filter.query.trim().isNotEmpty || filter.hasFilters;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                searching ? Icons.search_off_rounded : Icons.menu_book_rounded,
                size: 56,
                color: palette.cyan,
              ),
              const SizedBox(height: 12),
              Text(
                searching
                    ? 'Không tìm thấy bản ghi phù hợp.'
                    : 'Chưa có lỗi nào được ghi lại.',
                style: TextStyle(
                  color: palette.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                searching
                    ? 'Thử bỏ bớt từ khóa hoặc bộ lọc.'
                    : 'Nhấn "Ghi nhận sự cố" sau mỗi lần khắc phục để tra '
                          'cứu lại khi cần.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.muted),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      key: const Key('fault_bank_results'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final summary = results[index];
        return FaultRecordCard(
          summary: summary,
          onTap: () => context.push('/fault-bank/record/${summary.id}'),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        avatar: Icon(
          active ? Icons.filter_alt_rounded : Icons.arrow_drop_down_rounded,
          size: 18,
          color: active ? palette.cyan : palette.muted,
        ),
        label: Text(label, overflow: TextOverflow.ellipsis),
        labelStyle: TextStyle(
          color: active ? palette.navy : palette.ink,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
        backgroundColor: active ? palette.cyan.withValues(alpha: 0.10) : null,
        side: BorderSide(color: active ? palette.cyan : palette.border),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.icon,
    required this.text,
    this.action,
  });

  final String title;
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: palette.cyan),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 12), action!],
            ],
          ),
        ),
      ),
    );
  }
}
