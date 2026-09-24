import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/dtc_palette.dart';
import '../data/grinding_machine_database.dart';
import '../models/grinding_backup.dart';
import '../models/grinding_proposal.dart';
import '../providers/grinding_dashboard_provider.dart';
import '../providers/grinding_machine_provider.dart';
import '../providers/grinding_selection_project_provider.dart';
import '../repositories/grinding_proposal_repository.dart';
import '../repositories/grinding_selection_project_repository.dart';
import '../services/grinding_backup_service.dart';

/// Backup/Restore dữ liệu workflow module Máy nghiền (Phase 11, mục 17).
/// KHÔNG backup catalog máy (phục hồi qua Excel/JSON seed). Toàn bộ logic
/// export/parse/validate/restore nằm ở [GrindingBackupService] — màn hình
/// chỉ điều phối file picking (mục 7, reuse `file_selector`/`share_plus`
/// đã có sẵn) + hiển thị.
class GrindingBackupRestoreScreen extends StatefulWidget {
  const GrindingBackupRestoreScreen({super.key});

  @override
  State<GrindingBackupRestoreScreen> createState() => _GrindingBackupRestoreScreenState();
}

class _GrindingBackupRestoreScreenState extends State<GrindingBackupRestoreScreen> {
  final _projectRepository = GrindingSelectionProjectRepository();
  final _proposalRepository = GrindingProposalRepository();

  bool _isExporting = false;
  bool _isPickingFile = false;
  bool _isRestoring = false;

  int _currentProjectCount = 0;
  int _currentProposalChainCount = 0;

  String? _pickedFileName;
  GrindingBackupPayload? _payload;
  GrindingRestorePreview? _preview;
  String? _pickError;
  GrindingRestoreResult? _restoreResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCounts());
  }

  Future<void> _loadCounts() async {
    final projects = await _projectRepository.getAllProjects();
    final proposals = await _proposalRepository.getAllProposals();
    if (!mounted) return;
    setState(() {
      _currentProjectCount = projects.length;
      // Đếm theo chain, không cộng lặp revision — nhất quán rule Dashboard.
      _currentProposalChainCount = GrindingProposal.groupByChain(proposals).length;
    });
  }

  Future<void> _exportBackup() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final payload = await GrindingBackupService.exportPayload(
        projectRepository: _projectRepository,
        proposalRepository: _proposalRepository,
        appDatabaseVersion: GrindingMachineDatabase.currentVersion,
      );
      final json = GrindingBackupService.encode(payload);
      final bytes = Uint8List.fromList(utf8.encode(json));
      final fileName =
          'DTC_Grinding_Backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.dtcbackup';
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/json', name: fileName)],
          title: 'Grinding Machine Data Backup',
          text: 'Backup dữ liệu Máy nghiền — chứa thông tin khách hàng/thương mại, '
              'chỉ chia sẻ cho người bạn tin tưởng.',
          fileNameOverrides: [fileName],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export backup: $error')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickBackupFile() async {
    if (_isPickingFile) return;
    setState(() {
      _isPickingFile = true;
      _pickError = null;
      _payload = null;
      _preview = null;
      _restoreResult = null;
    });
    try {
      final typeGroup = XTypeGroup(
        label: 'DTC Grinding Backup',
        extensions: ['dtcbackup', 'json'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) {
        if (mounted) setState(() => _isPickingFile = false);
        return;
      }
      final raw = utf8.decode(await file.readAsBytes());
      final payload = GrindingBackupService.decode(raw);
      if (!mounted) return;
      final machineProvider = context.read<GrindingMachineProvider>();
      final knownMachineIds = machineProvider.machines.map((m) => m.machineId).toSet();
      final preview = GrindingBackupService.buildPreview(
        payload: payload,
        currentProjectCount: _currentProjectCount,
        currentProposalCount: _currentProposalChainCount,
        knownMachineIds: knownMachineIds,
      );
      if (!mounted) return;
      setState(() {
        _pickedFileName = file.name;
        _payload = payload;
        _preview = preview;
        _isPickingFile = false;
      });
    } on GrindingBackupException catch (error) {
      if (!mounted) return;
      setState(() {
        _pickError = error.message;
        _isPickingFile = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pickError = 'Invalid or corrupted backup file';
        _isPickingFile = false;
      });
    }
  }

  Future<void> _confirmRestore() async {
    if (_isRestoring) return;
    final payload = _payload;
    if (payload == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'Current project and proposal workflow data will be replaced. '
          'It is recommended to export a backup before restoring.\n\n'
          'Machine catalog is NOT affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Replace & Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);
    try {
      final machineProvider = context.read<GrindingMachineProvider>();
      final knownMachineIds = machineProvider.machines.map((m) => m.machineId).toSet();
      final result = await GrindingBackupService.restore(
        payload: payload,
        database: GrindingMachineDatabase.instance,
        knownMachineIds: knownMachineIds,
      );
      if (!mounted) return;
      // Đồng bộ lại các Provider đã cache dữ liệu cũ trong bộ nhớ — lấy
      // reference TRƯỚC khi await tiếp để tránh dùng context sau async gap.
      final projectProvider = context.read<GrindingSelectionProjectProvider>();
      final dashboardProvider = context.read<GrindingDashboardProvider>();
      await projectProvider.loadAll();
      await dashboardProvider.refresh();
      await _loadCounts();
      if (!mounted) return;
      setState(() {
        _restoreResult = result;
        _isRestoring = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isRestoring = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restore backup: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SectionCard(
            title: 'Backup',
            children: [
              Text(
                'Backup file có thể chứa thông tin khách hàng/thương mại — '
                'chỉ chia sẻ cho người bạn tin tưởng.',
                style: TextStyle(color: palette.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('grinding_backup_export_button'),
                onPressed: _isExporting ? null : _exportBackup,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_outlined),
                label: const Text('Export Backup'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Restore',
            children: [
              OutlinedButton.icon(
                key: const Key('grinding_backup_pick_file_button'),
                onPressed: _isPickingFile ? null : _pickBackupFile,
                icon: _isPickingFile
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open_outlined),
                label: const Text('Select Backup File'),
              ),
              if (_pickError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _pickError!,
                  key: const Key('grinding_backup_pick_error_text'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12.5),
                ),
              ],
              if (_preview != null) ...[
                const SizedBox(height: 14),
                _RestorePreviewCard(fileName: _pickedFileName, preview: _preview!),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('grinding_backup_restore_button'),
                  onPressed: _isRestoring ? null : _confirmRestore,
                  icon: _isRestoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore_outlined),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  label: const Text('Restore (Replace workflow data)'),
                ),
              ],
              if (_restoreResult != null) ...[
                const SizedBox(height: 14),
                _RestoreResultCard(result: _restoreResult!),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Database Info',
            children: [
              _infoRow(palette, 'Database version', '${GrindingMachineDatabase.currentVersion}'),
              _infoRow(palette, 'Backup format version', '${GrindingBackupService.supportedFormatVersion}'),
              _infoRow(palette, 'Projects', '$_currentProjectCount'),
              _infoRow(palette, 'Proposal chains', '$_currentProposalChainCount'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(DtcPaletteData palette, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(color: palette.muted, fontSize: 12.5))),
        Text(value, style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: palette.navy, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _RestorePreviewCard extends StatelessWidget {
  const _RestorePreviewCard({required this.fileName, required this.preview});
  final String? fileName;
  final GrindingRestorePreview preview;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Container(
      key: const Key('grinding_backup_preview_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.cyan.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fileName != null)
            Text(fileName!, style: TextStyle(color: palette.navy, fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(height: 6),
          _row(palette, 'Backup created', DateFormat('dd/MM/yyyy HH:mm').format(preview.createdAt)),
          _row(palette, 'Format version', '${preview.formatVersion}'),
          _row(palette, 'Projects in backup', '${preview.projectCount}'),
          _row(palette, 'Proposal chains in backup', '${preview.proposalChainCount}'),
          _row(palette, 'Revisions in backup', '${preview.revisionCount}'),
          _row(palette, 'Line items in backup', '${preview.lineItemCount}'),
          const Divider(height: 16),
          _row(palette, 'Current projects (local)', '${preview.currentProjectCount}'),
          _row(palette, 'Current proposal chains (local)', '${preview.currentProposalCount}'),
          if (preview.missingMachineReferenceCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${preview.missingMachineReferenceCount} machine reference(s) in backup '
              'no longer exist in current catalog — will still restore, shown as unavailable.',
              style: TextStyle(color: palette.muted, fontSize: 11.5, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(DtcPaletteData palette, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(color: palette.muted, fontSize: 12))),
        Text(value, style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700, fontSize: 12.5)),
      ],
    ),
  );
}

class _RestoreResultCard extends StatelessWidget {
  const _RestoreResultCard({required this.result});
  final GrindingRestoreResult result;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Container(
      key: const Key('grinding_backup_restore_result_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restore completed',
            style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text('${result.projectsRestored} projects restored', style: TextStyle(color: palette.ink, fontSize: 12.5)),
          Text(
            '${result.proposalChainsRestored} proposal chains restored',
            style: TextStyle(color: palette.ink, fontSize: 12.5),
          ),
          Text('${result.revisionsRestored} revisions restored', style: TextStyle(color: palette.ink, fontSize: 12.5)),
          Text('${result.lineItemsRestored} line items restored', style: TextStyle(color: palette.ink, fontSize: 12.5)),
          if (result.missingMachineReferenceCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${result.missingMachineReferenceCount} machine reference(s) unavailable in current catalog.',
                style: TextStyle(color: palette.muted, fontSize: 11.5, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }
}
