import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/site_layout_models.dart';
import '../providers/site_layout_provider.dart';
import '../services/layout_geometry_service.dart';
import '../widgets/layout_canvas.dart';

class SiteLayoutEditorScreen extends StatefulWidget {
  const SiteLayoutEditorScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<SiteLayoutEditorScreen> createState() => _SiteLayoutEditorScreenState();
}

class _SiteLayoutEditorScreenState extends State<SiteLayoutEditorScreen>
    with WidgetsBindingObserver {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final provider = context.read<SiteLayoutProvider>();
    if (provider.catalog.isEmpty) await provider.initialize();
    final loaded = await provider.loadProject(widget.projectId);
    if (mounted) setState(() => _loaded = loaded);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<SiteLayoutProvider>().saveNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<SiteLayoutProvider>().saveNow();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SiteLayoutProvider>();
    final bundle = provider.bundle;
    if (!_loaded || bundle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bố trí mặt bằng')),
        body: Center(
          child: provider.error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(provider.error!, textAlign: TextAlign.center),
                ),
        ),
      );
    }

    return PopScope(
      onPopInvokedWithResult: (_, _) => provider.saveNow(),
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bundle.project.name),
              Text(
                provider.isSaving
                    ? 'Đang lưu…'
                    : provider.isDirty
                    ? 'Chưa lưu'
                    : 'Đã lưu tự động',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Thông tin dự án',
              onPressed: () => _editProject(provider),
              icon: const Icon(Icons.edit_note_rounded),
            ),
            IconButton(
              tooltip: 'Ảnh khảo sát',
              onPressed: () => context.push(
                '/site-layout/project/${bundle.project.id}/photos',
              ),
              icon: const Icon(Icons.photo_camera_outlined),
            ),
            IconButton(
              tooltip: 'Xuất báo cáo',
              onPressed: () async {
                await provider.saveNow();
                if (context.mounted) {
                  context.push(
                    '/site-layout/project/${bundle.project.id}/export',
                  );
                }
              },
              icon: const Icon(Icons.ios_share_rounded),
            ),
            PopupMenuButton<String>(
              tooltip: 'Phương án',
              onSelected: (value) => _handleLayoutMenu(value, provider),
              itemBuilder: (_) => [
                ...provider.layouts.map(
                  (layout) => PopupMenuItem(
                    value: 'open:${layout.id}',
                    child: Row(
                      children: [
                        Icon(
                          layout.id == bundle.layout.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(layout.name)),
                        if (layout.isPreferred)
                          const Icon(Icons.star_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'new',
                  child: ListTile(
                    leading: Icon(Icons.add_box_outlined),
                    title: Text('Tạo phương án mới'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: ListTile(
                    leading: Icon(Icons.copy_all_outlined),
                    title: Text('Nhân bản phương án'),
                  ),
                ),
                if (!bundle.layout.isPreferred)
                  const PopupMenuItem(
                    value: 'preferred',
                    child: ListTile(
                      leading: Icon(Icons.star_outline),
                      title: Text('Chọn làm phương án ưu tiên'),
                    ),
                  ),
                if (provider.layouts.length > 1)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Xóa phương án'),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            SiteLayoutEditorToolbar(
              provider: provider,
              onAddMachine: () => _showMachineLibrary(provider),
              onEditSelected:
                  provider.selectedMachine == null &&
                      provider.selectedObject == null &&
                      provider.selectedMeasurement == null
                  ? null
                  : () => _editSelected(provider),
              onWarnings: () => _showWarnings(provider),
            ),
            Expanded(
              child: LayoutCanvas(
                bundle: bundle,
                tool: provider.tool,
                gridMm: provider.gridMm,
                snapToGrid: provider.snapToGrid,
                showClearance: provider.showClearance,
                selectedId: provider.selectedId,
                activeSnapPoint: provider.activeSnapPoint,
                warnings: provider.warnings,
                onSelect: provider.select,
                onAddObject: provider.addObject,
                onAddLine: provider.addLine,
                onTransformStart: provider.beginTransform,
                onMoveUpdate: provider.updateTransformMove,
                onResizeUpdate: provider.updateTransformResize,
                onRotateUpdate: provider.updateTransformRotation,
                onTransformEnd: provider.endTransform,
                onTrimObject: provider.trimLinearObject,
                onAddMeasurement: provider.addMeasurement,
                onAddNote: (x, y) => _addNote(provider, x, y),
                onAddPhotoMarker: (x, y) => _addPhotoMarker(provider, x, y),
                onEditSelected:
                    provider.selectedMachine == null &&
                        provider.selectedObject == null &&
                        provider.selectedMeasurement == null
                    ? null
                    : () => _editSelected(provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLayoutMenu(
    String value,
    SiteLayoutProvider provider,
  ) async {
    if (value.startsWith('open:')) {
      await provider.switchLayout(value.substring(5));
    } else if (value == 'new') {
      await provider.createLayout();
    } else if (value == 'duplicate') {
      await provider.createLayout(duplicateCurrent: true);
    } else if (value == 'preferred') {
      await provider.setPreferredLayout();
    } else if (value == 'delete') {
      final accepted = await _confirm(
        'Xóa phương án?',
        'Toàn bộ đối tượng trên phương án hiện tại sẽ bị xóa.',
      );
      if (accepted) await provider.deleteCurrentLayout();
    }
  }

  Future<bool> _confirm(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _showMachineLibrary(SiteLayoutProvider provider) async {
    final unit = provider.bundle!.project.dimensionUnit;
    var query = '';
    String category = 'Tất cả';
    final categories = <String>{
      'Tất cả',
      ...provider.catalog.map((machine) => machine.category),
    }.toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final normalized = query.toLowerCase();
          final results = provider.catalog.where((machine) {
            final categoryMatches =
                category == 'Tất cả' || machine.category == category;
            final textMatches =
                normalized.isEmpty ||
                machine.model.toLowerCase().contains(normalized) ||
                machine.displayName.toLowerCase().contains(normalized);
            return categoryMatches && textMatches;
          }).toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.88,
            minChildSize: 0.55,
            maxChildSize: 0.96,
            builder: (_, controller) => Column(
              children: [
                const SizedBox(height: 8),
                Text(
                  'Thư viện thiết bị',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Tìm model hoặc tên máy…',
                    ),
                    onChanged: (value) => setSheetState(() => query = value),
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => ChoiceChip(
                      label: Text(categories[index]),
                      selected: category == categories[index],
                      onSelected: (_) =>
                          setSheetState(() => category = categories[index]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final machine = results[index];
                      return ListTile(
                        enabled: machine.canPlace,
                        leading: CircleAvatar(
                          child: Text(
                            machine.model.length > 3
                                ? machine.model.substring(0, 3)
                                : machine.model,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        title: Text(machine.model),
                        subtitle: Text(
                          machine.canPlace
                              ? '${machine.category} · ${unit.formatValue(machine.lengthMm!)} × ${unit.formatValue(machine.widthMm!)} × ${unit.formatValue(machine.heightMm!)} ${unit.symbol}'
                              : '${machine.category} · ${machine.invalidReason}',
                        ),
                        trailing: machine.canPlace
                            ? const Icon(Icons.add_circle_outline)
                            : const Icon(Icons.error_outline),
                        onTap: machine.canPlace
                            ? () async {
                                Navigator.pop(sheetContext);
                                await _addMachineWithClearance(
                                  provider,
                                  machine,
                                );
                              }
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addMachineWithClearance(
    SiteLayoutProvider provider,
    CatalogMachineLayoutData machine,
  ) async {
    final unit = provider.bundle!.project.dimensionUnit;
    final controllers = [1000.0, 600.0, 600.0, 600.0]
        .map((value) => TextEditingController(text: unit.formatValue(value)))
        .toList();
    final values = await showModalBottomSheet<List<double>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Khoảng hở lắp đặt · ${machine.model}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Kích thước máy cố định: ${unit.formatValue(machine.widthMm!)} × ${unit.formatValue(machine.lengthMm!)} ${unit.symbol}',
              ),
              const SizedBox(height: 14),
              ...List.generate(4, (index) {
                const labels = [
                  'Phía trước',
                  'Phía sau',
                  'Bên trái',
                  'Bên phải',
                ];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: controllers[index],
                    autofocus: index == 0,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: labels[index],
                      suffixText: unit.symbol,
                    ),
                  ),
                );
              }),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.factory_outlined),
                  label: const Text('Thêm máy vào mặt bằng'),
                  onPressed: () {
                    final parsed = controllers
                        .map(
                          (controller) =>
                              unit.parseToMillimeters(controller.text),
                        )
                        .toList();
                    if (parsed.any((value) => value == null || value < 0)) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text('Khoảng hở phải là số không âm.'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(sheetContext, parsed.cast<double>());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    if (values == null || !mounted) return;
    provider.addMachine(
      machine,
      clearanceFrontMm: values[0],
      clearanceRearMm: values[1],
      clearanceLeftMm: values[2],
      clearanceRightMm: values[3],
      clearanceVerified: true,
    );
  }

  Future<void> _editSelected(SiteLayoutProvider provider) async {
    final machine = provider.selectedMachine;
    final object = provider.selectedObject;
    final measurement = provider.selectedMeasurement;
    if (machine != null) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _MachineProperties(
          machine: machine,
          unit: provider.bundle!.project.dimensionUnit,
          onSave: provider.updateSelectedMachine,
        ),
      );
    } else if (object != null) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ObjectProperties(
          object: object,
          unit: provider.bundle!.project.dimensionUnit,
          onSave: provider.updateSelectedObject,
        ),
      );
    } else if (measurement != null) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _MeasurementProperties(
          measurement: measurement,
          unit: provider.bundle!.project.dimensionUnit,
          onSave: provider.updateSelectedMeasurement,
        ),
      );
    }
  }

  Future<void> _editProject(SiteLayoutProvider provider) async {
    final project = provider.bundle?.project;
    if (project == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProjectProperties(
        project: project,
        onSave: provider.updateProjectInEditor,
      ),
    );
  }

  Future<void> _addNote(
    SiteLayoutProvider provider,
    double xMm,
    double yMm,
  ) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm ghi chú vị trí'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Nội dung ghi chú'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) provider.addAnnotation(xMm, yMm, value);
  }

  Future<void> _addPhotoMarker(
    SiteLayoutProvider provider,
    double xMm,
    double yMm,
  ) async {
    final photos = provider.bundle?.photos ?? const <SitePhoto>[];
    if (photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy thêm ảnh khảo sát trước khi đặt marker.'),
        ),
      );
      return;
    }
    final selected = await showModalBottomSheet<SitePhoto>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Chọn ảnh cho vị trí')),
            ...photos.map(
              (photo) => ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(
                  photo.caption.isEmpty ? 'Ảnh khảo sát' : photo.caption,
                ),
                subtitle: Text(photo.note),
                onTap: () => Navigator.pop(context, photo),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) provider.addPhotoMarker(xMm, yMm, selected);
  }

  void _showWarnings(SiteLayoutProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        final warnings = provider.warnings;
        final unit = provider.bundle!.project.dimensionUnit;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            ListTile(
              title: Text(
                'Kiểm tra kỹ thuật (${warnings.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (warnings.isEmpty)
              const ListTile(
                leading: Icon(Icons.check_circle_outline, color: Colors.green),
                title: Text('Không phát hiện cảnh báo'),
              ),
            ...warnings.map(
              (warning) => ListTile(
                leading: Icon(
                  warning.type == LayoutWarningType.missingData
                      ? Icons.help_outline
                      : Icons.warning_amber_rounded,
                  color: warning.type == LayoutWarningType.missingData
                      ? Colors.orange
                      : Colors.red,
                ),
                title: Text(warning.title),
                subtitle: Text(
                  warning.shortageMm == null
                      ? warning.message
                      : '${warning.message} Thiếu ${unit.format(warning.shortageMm!)}.',
                ),
                onTap: () {
                  provider.select(warning.subjectId);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class SiteLayoutEditorToolbar extends StatelessWidget {
  const SiteLayoutEditorToolbar({
    super.key,
    required this.provider,
    required this.onAddMachine,
    required this.onEditSelected,
    required this.onWarnings,
  });

  final SiteLayoutProvider provider;
  final VoidCallback onAddMachine;
  final VoidCallback? onEditSelected;
  final VoidCallback onWarnings;

  @override
  Widget build(BuildContext context) {
    final unit = provider.bundle!.project.dimensionUnit;
    Widget row(Key key, List<Widget> children) => SizedBox(
      key: key,
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        children: children,
      ),
    );

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(const Key('site_layout_toolbar_primary'), [
            _ToolButton(
              icon: Icons.near_me_outlined,
              label: 'Chọn',
              selected: provider.tool == EditorTool.select,
              onTap: () => provider.setTool(EditorTool.select),
            ),
            _ToolButton(
              icon: Icons.pan_tool_alt_outlined,
              label: 'Di chuyển',
              selected: provider.tool == EditorTool.pan,
              onTap: () => provider.setTool(EditorTool.pan),
            ),
            PopupMenuButton<EditorTool>(
              tooltip: 'Thêm đối tượng',
              onSelected: provider.setTool,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: EditorTool.wall,
                  child: Text('Thêm tường'),
                ),
                PopupMenuItem(
                  value: EditorTool.column,
                  child: Text('Thêm cột'),
                ),
                PopupMenuItem(value: EditorTool.door, child: Text('Thêm cửa')),
                PopupMenuItem(
                  value: EditorTool.bucketElevator,
                  child: Text('Thêm gàu tải'),
                ),
                PopupMenuItem(
                  value: EditorTool.walkway,
                  child: Text('Thêm lối đi'),
                ),
                PopupMenuItem(
                  value: EditorTool.line,
                  child: Text('Vẽ đường thẳng'),
                ),
                PopupMenuItem(
                  value: EditorTool.restrictedArea,
                  child: Text('Thêm vùng cấm'),
                ),
                PopupMenuItem(
                  value: EditorTool.obstacle,
                  child: Text('Thêm chướng ngại'),
                ),
                PopupMenuItem(
                  value: EditorTool.existingMachine,
                  child: Text('Thêm máy hiện hữu'),
                ),
              ],
              child: const _ToolMenuVisual(
                icon: Icons.add_box_outlined,
                label: 'Mặt bằng',
              ),
            ),
            _ToolButton(
              icon: Icons.add_rounded,
              label: 'Thêm máy',
              onTap: onAddMachine,
            ),
            _ToolButton(
              icon: Icons.straighten_rounded,
              label: 'Kích thước',
              onTap: onEditSelected,
            ),
            _ToolButton(
              icon: Icons.content_cut_rounded,
              label: 'Cắt',
              selected: provider.tool == EditorTool.trim,
              onTap: () => provider.setTool(EditorTool.trim),
            ),
            _ToolButton(
              icon: provider.snapToGrid ? Icons.grid_on : Icons.grid_off,
              label: 'Bắt điểm',
              selected: provider.snapToGrid,
              onTap: provider.toggleSnap,
            ),
            _ToolButton(
              icon: Icons.sticky_note_2_outlined,
              label: 'Ghi chú',
              selected: provider.tool == EditorTool.note,
              onTap: () => provider.setTool(EditorTool.note),
            ),
            PopupMenuButton<double>(
              tooltip: 'Cỡ chữ kích thước',
              onSelected: provider.setDimensionTextScale,
              itemBuilder: (_) =>
                  const [0.3, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5]
                      .map(
                        (value) => PopupMenuItem(
                          value: value,
                          child: Text('Cỡ chữ ${(value * 100).round()}%'),
                        ),
                      )
                      .toList(),
              child: _ToolMenuVisual(
                icon: Icons.text_fields_rounded,
                label:
                    'Aa ${(provider.bundle!.project.dimensionTextScale * 100).round()}%',
              ),
            ),
            _ToolButton(
              icon: provider.selectedIsLocked
                  ? Icons.lock_rounded
                  : Icons.lock_open_rounded,
              label: provider.selectedIsLocked ? 'Mở khóa' : 'Khóa',
              onTap:
                  provider.selectedMachine == null &&
                      provider.selectedObject == null
                  ? null
                  : provider.toggleLockSelected,
            ),
            _ToolButton(
              icon: Icons.copy_outlined,
              label: 'Sao chép',
              onTap: provider.selectedId == null
                  ? null
                  : provider.duplicateSelected,
            ),
            _ToolButton(
              icon: Icons.padding_outlined,
              label: 'Khoảng hở',
              selected: provider.showClearance,
              onTap: provider.toggleClearance,
            ),
            Badge(
              label: Text('${provider.warnings.length}'),
              isLabelVisible: provider.warnings.isNotEmpty,
              child: _ToolButton(
                icon: Icons.rule_folder_outlined,
                label: 'Kiểm tra',
                onTap: onWarnings,
              ),
            ),
          ]),
          const Divider(height: 1),
          row(const Key('site_layout_toolbar_secondary'), [
            _ToolButton(
              icon: Icons.undo_rounded,
              label: 'Hoàn tác',
              onTap: provider.canUndo ? provider.undo : null,
            ),
            _ToolButton(
              icon: Icons.redo_rounded,
              label: 'Làm lại',
              onTap: provider.canRedo ? provider.redo : null,
            ),
            _ToolButton(
              icon: Icons.straighten_rounded,
              label: 'Đo',
              selected: provider.tool == EditorTool.measure,
              onTap: () => provider.setTool(EditorTool.measure),
            ),
            _ToolButton(
              icon: Icons.delete_outline,
              label: 'Xóa',
              onTap: provider.selectedId == null
                  ? null
                  : provider.deleteSelected,
            ),
            _ToolButton(
              icon: Icons.add_a_photo_outlined,
              label: 'Marker ảnh',
              selected: provider.tool == EditorTool.photoMarker,
              onTap: () => provider.setTool(EditorTool.photoMarker),
            ),
            _ToolButton(
              icon: Icons.rotate_90_degrees_ccw,
              label: '+90°',
              onTap:
                  (provider.selectedMachine == null &&
                          provider.selectedObject == null) ||
                      provider.selectedIsLocked
                  ? null
                  : provider.rotateSelected,
            ),
            PopupMenuButton<double>(
              tooltip: 'Cỡ lưới',
              onSelected: provider.setGrid,
              itemBuilder: (_) => [100, 250, 500, 1000]
                  .map(
                    (value) => PopupMenuItem(
                      value: value.toDouble(),
                      child: Text('Lưới ${unit.format(value.toDouble())}'),
                    ),
                  )
                  .toList(),
              child: _ToolMenuVisual(
                icon: Icons.grid_4x4_rounded,
                label: unit.format(provider.gridMm),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ToolMenuVisual extends StatelessWidget {
  const _ToolMenuVisual({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9),
        ),
      ],
    ),
  );
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 64,
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 9,
                color: onTap == null ? Theme.of(context).disabledColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Kept temporarily to preserve the established tool visuals while the editor
// uses the new two-row horizontal toolbar.
// ignore: unused_element
class _EditorSideToolbar extends StatelessWidget {
  const _EditorSideToolbar({
    required this.provider,
    required this.onAddMachine,
    required this.onEditSelected,
  });

  final SiteLayoutProvider provider;
  final VoidCallback onAddMachine;
  final VoidCallback? onEditSelected;

  @override
  Widget build(BuildContext context) {
    Widget button(
      IconData icon,
      String label,
      VoidCallback? onTap, {
      bool selected = false,
    }) => _SideToolButton(
      icon: icon,
      label: label,
      onTap: onTap,
      selected: selected,
    );

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      child: SizedBox(
        width: 66,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 4),
          children: [
            button(
              Icons.near_me_outlined,
              'Chọn',
              () => provider.setTool(EditorTool.select),
              selected: provider.tool == EditorTool.select,
            ),
            button(
              Icons.pan_tool_alt_outlined,
              'Khung',
              () => provider.setTool(EditorTool.pan),
              selected: provider.tool == EditorTool.pan,
            ),
            PopupMenuButton<EditorTool>(
              tooltip: 'Thêm đối tượng',
              onSelected: provider.setTool,
              itemBuilder: (_) => const [
                PopupMenuItem(value: EditorTool.wall, child: Text('Tường')),
                PopupMenuItem(value: EditorTool.column, child: Text('Cột')),
                PopupMenuItem(value: EditorTool.door, child: Text('Cửa')),
                PopupMenuItem(
                  value: EditorTool.bucketElevator,
                  child: Text('Gàu tải'),
                ),
                PopupMenuItem(value: EditorTool.walkway, child: Text('Lối đi')),
                PopupMenuItem(
                  value: EditorTool.restrictedArea,
                  child: Text('Vùng cấm'),
                ),
                PopupMenuItem(
                  value: EditorTool.obstacle,
                  child: Text('Chướng ngại'),
                ),
                PopupMenuItem(
                  value: EditorTool.existingMachine,
                  child: Text('Máy hiện hữu'),
                ),
              ],
              child: const _SideToolVisual(
                icon: Icons.add_box_outlined,
                label: 'Thêm',
              ),
            ),
            button(Icons.factory_outlined, 'Máy', onAddMachine),
            button(Icons.straighten_rounded, 'Kích thước', onEditSelected),
            button(
              Icons.content_cut_rounded,
              'Cắt',
              () => provider.setTool(EditorTool.trim),
              selected: provider.tool == EditorTool.trim,
            ),
            button(
              Icons.rotate_90_degrees_ccw,
              '+90°',
              provider.selectedId == null || provider.selectedIsLocked
                  ? null
                  : provider.rotateSelected,
            ),
            button(
              provider.selectedIsLocked
                  ? Icons.lock_rounded
                  : Icons.lock_open_rounded,
              provider.selectedIsLocked ? 'Mở khóa' : 'Khóa',
              provider.selectedId == null ? null : provider.toggleLockSelected,
            ),
            button(
              Icons.straighten_outlined,
              'Đo',
              () => provider.setTool(EditorTool.measure),
              selected: provider.tool == EditorTool.measure,
            ),
            button(
              Icons.sticky_note_2_outlined,
              'Ghi chú',
              () => provider.setTool(EditorTool.note),
              selected: provider.tool == EditorTool.note,
            ),
            button(
              Icons.add_a_photo_outlined,
              'Ảnh',
              () => provider.setTool(EditorTool.photoMarker),
              selected: provider.tool == EditorTool.photoMarker,
            ),
            button(
              Icons.copy_outlined,
              'Sao chép',
              provider.selectedId == null ? null : provider.duplicateSelected,
            ),
            button(
              Icons.delete_outline,
              'Xóa',
              provider.selectedId == null ? null : provider.deleteSelected,
            ),
            button(
              Icons.undo_rounded,
              'Undo',
              provider.canUndo ? provider.undo : null,
            ),
            button(
              Icons.redo_rounded,
              'Redo',
              provider.canRedo ? provider.redo : null,
            ),
            button(
              provider.snapToGrid ? Icons.grid_on : Icons.grid_off,
              'Bắt điểm',
              provider.toggleSnap,
              selected: provider.snapToGrid,
            ),
            button(
              Icons.padding_outlined,
              'Khoảng hở',
              provider.toggleClearance,
              selected: provider.showClearance,
            ),
            PopupMenuButton<double>(
              tooltip: 'Cỡ chữ kích thước',
              onSelected: provider.setDimensionTextScale,
              itemBuilder: (_) =>
                  const [0.3, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5]
                      .map(
                        (value) => PopupMenuItem(
                          value: value,
                          child: Text('Cỡ chữ ${(value * 100).round()}%'),
                        ),
                      )
                      .toList(),
              child: _SideToolVisual(
                icon: Icons.text_fields_rounded,
                label:
                    '${(provider.bundle!.project.dimensionTextScale * 100).round()}%',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideToolButton extends StatelessWidget {
  const _SideToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null ? 0.38 : 1,
      child: _SideToolVisual(icon: icon, label: label, selected: selected),
    ),
  );
}

class _SideToolVisual extends StatelessWidget {
  const _SideToolVisual({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 8.5),
        ),
      ],
    ),
  );
}

class _MachineProperties extends StatefulWidget {
  const _MachineProperties({
    required this.machine,
    required this.unit,
    required this.onSave,
  });
  final MachinePlacement machine;
  final SiteDimensionUnit unit;
  final ValueChanged<MachinePlacement> onSave;

  @override
  State<_MachineProperties> createState() => _MachinePropertiesState();
}

class _MachinePropertiesState extends State<_MachineProperties> {
  late final _angle = TextEditingController(
    text: widget.machine.rotationDeg.toStringAsFixed(0),
  );
  late bool _isLocked = widget.machine.isLocked;
  late final List<TextEditingController> _controllers =
      [
            widget.machine.clearanceFrontMm,
            widget.machine.clearanceRearMm,
            widget.machine.clearanceLeftMm,
            widget.machine.clearanceRightMm,
            widget.machine.clearanceTopMm,
            widget.machine.floorToBaseMm,
          ]
          .asMap()
          .entries
          .map(
            (entry) => TextEditingController(
              text: entry.key < 5 && !widget.machine.clearanceVerified
                  ? ''
                  : widget.unit.formatValue(entry.value),
            ),
          )
          .toList();

  @override
  void dispose() {
    _angle.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double _value(int index) =>
      widget.unit.parseToMillimeters(_controllers[index].text) ?? 0;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Khoảng hở phía trước',
      'Khoảng hở phía sau',
      'Khoảng hở bên trái',
      'Khoảng hở bên phải',
      'Khoảng hở phía trên',
      'Khoảng cách sàn đến đế',
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.machine.displayName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '🔒 Kích thước máy cố định: ${widget.unit.formatValue(widget.machine.widthMm)} × ${widget.unit.formatValue(widget.machine.lengthMm)} × ${widget.unit.formatValue(widget.machine.heightMm)} ${widget.unit.symbol}',
            ),
            const SizedBox(height: 16),
            _placementField(
              _angle,
              'Góc xoay',
              '°',
              signed: true,
              enabled: !_isLocked,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: -90, label: Text('-90°')),
                ButtonSegment(value: 0, label: Text('0°')),
                ButtonSegment(value: 90, label: Text('+90°')),
              ],
              emptySelectionAllowed: true,
              selected: const {},
              onSelectionChanged: _isLocked
                  ? null
                  : (values) {
                      final value = values.first;
                      final current =
                          _fieldValue(_angle) ?? widget.machine.rotationDeg;
                      _angle.text = value == 0
                          ? '0'
                          : (current + value).toStringAsFixed(0);
                    },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Khóa vị trí máy'),
              value: _isLocked,
              onChanged: (value) => setState(() => _isLocked = value ?? false),
            ),
            ...List.generate(
              labels.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _controllers[index],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: labels[index],
                    suffixText: widget.unit.symbol,
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                widget.onSave(
                  widget.machine.copyWith(
                    clearanceFrontMm: 0,
                    clearanceRearMm: 0,
                    clearanceLeftMm: 0,
                    clearanceRightMm: 0,
                    clearanceTopMm: 0,
                    clearanceVerified: false,
                  ),
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Khôi phục mặc định catalog'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                final provider = context.read<SiteLayoutProvider>();
                final bundle = provider.bundle;
                if (bundle == null) return;
                Navigator.pop(context);
                context.push(
                  '/site-layout/project/${bundle.project.id}/layout/${bundle.layout.id}/elevation/${widget.machine.id}',
                );
              },
              icon: const Icon(Icons.view_agenda_outlined),
              label: const Text('Xem mặt đứng và kiểm tra chiều cao'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                final angle = _fieldValue(_angle);
                if (angle == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Góc xoay không hợp lệ.')),
                  );
                  return;
                }
                if (_controllers.any((controller) {
                  final value = widget.unit.parseToMillimeters(controller.text);
                  return value == null || value < 0;
                })) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Khoảng hở phải là số không âm và cần nhập đủ.',
                      ),
                    ),
                  );
                  return;
                }
                final normalizedAngle = LayoutGeometryService.normalizedAngle(
                  angle,
                );
                final center = LayoutGeometryService.machineCenter(
                  widget.machine,
                );
                final bounds = LayoutGeometryService.rotatedBounds(
                  center: center,
                  width: widget.machine.widthMm,
                  height: widget.machine.lengthMm,
                  rotationDeg: normalizedAngle,
                );
                widget.onSave(
                  widget.machine.copyWith(
                    clearanceFrontMm: _value(0),
                    clearanceRearMm: _value(1),
                    clearanceLeftMm: _value(2),
                    clearanceRightMm: _value(3),
                    clearanceTopMm: _value(4),
                    clearanceVerified: true,
                    floorToBaseMm: _value(5),
                    xMm: bounds.left,
                    yMm: bounds.top,
                    rotationDeg: normalizedAngle,
                    isLocked: _isLocked,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Lưu thông số lắp đặt'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.read<SiteLayoutProvider>().duplicateSelected();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Sao chép'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.read<SiteLayoutProvider>().deleteSelected();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xóa'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placementField(
    TextEditingController controller,
    String label,
    String suffix, {
    bool signed = false,
    bool enabled = true,
  }) => TextField(
    controller: controller,
    enabled: enabled,
    keyboardType: TextInputType.numberWithOptions(
      decimal: true,
      signed: signed,
    ),
    decoration: InputDecoration(labelText: label, suffixText: suffix),
  );

  double? _fieldValue(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));
}

class _ObjectProperties extends StatefulWidget {
  const _ObjectProperties({
    required this.object,
    required this.unit,
    required this.onSave,
  });
  final SiteLayoutObject object;
  final SiteDimensionUnit unit;
  final ValueChanged<SiteLayoutObject> onSave;

  @override
  State<_ObjectProperties> createState() => _ObjectPropertiesState();
}

class _ObjectPropertiesState extends State<_ObjectProperties> {
  late final _width = TextEditingController(
    text: widget.unit.formatValue(widget.object.widthMm),
  );
  late final _length = TextEditingController(
    text: widget.unit.formatValue(widget.object.lengthMm),
  );
  late final _angle = _controller(widget.object.rotationDeg);
  late bool _isLocked = widget.object.isLocked;

  static TextEditingController _controller(double value) =>
      TextEditingController(text: value.toStringAsFixed(0));

  @override
  void dispose() {
    for (final controller in [_width, _length, _angle]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLinear = widget.object.type.isLinear;
    final widthLabel = widget.object.type == SiteObjectType.wall
        ? 'Chiều dài'
        : widget.object.type == SiteObjectType.line
        ? 'Chiều dài đường'
        : widget.object.type == SiteObjectType.door
        ? 'Chiều rộng cửa'
        : widget.object.type == SiteObjectType.walkway
        ? 'Chiều dài lối đi'
        : 'Rộng';
    final lengthLabel = widget.object.type == SiteObjectType.walkway
        ? 'Độ rộng lối đi'
        : widget.object.type == SiteObjectType.line
        ? 'Độ dày đường'
        : isLinear
        ? 'Độ dày'
        : 'Dài';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.object.type.label.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _numberField(
                    _width,
                    widthLabel,
                    widget.unit.symbol,
                    enabled: !_isLocked,
                    autofocus: !_isLocked,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _numberField(
                    _length,
                    lengthLabel,
                    widget.unit.symbol,
                    enabled: !_isLocked,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _numberField(
              _angle,
              'Góc xoay',
              '°',
              signed: true,
              enabled: !_isLocked,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: -90, label: Text('-90°')),
                ButtonSegment(value: 0, label: Text('0°')),
                ButtonSegment(value: 90, label: Text('+90°')),
              ],
              emptySelectionAllowed: true,
              selected: const {},
              onSelectionChanged: _isLocked
                  ? null
                  : (values) {
                      final value = values.first;
                      final current =
                          _number(_angle) ?? widget.object.rotationDeg;
                      _angle.text = value == 0
                          ? '0'
                          : (current + value).toStringAsFixed(0);
                    },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Khóa đối tượng'),
              value: _isLocked,
              onChanged: (value) => setState(() => _isLocked = value ?? false),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('Xong')),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.read<SiteLayoutProvider>().duplicateSelected();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Sao chép'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.read<SiteLayoutProvider>().deleteSelected();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xóa'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    String suffix, {
    bool signed = false,
    bool enabled = true,
    bool autofocus = false,
  }) => TextField(
    controller: controller,
    enabled: enabled,
    autofocus: autofocus,
    keyboardType: TextInputType.numberWithOptions(
      decimal: true,
      signed: signed,
    ),
    decoration: InputDecoration(labelText: label, suffixText: suffix),
  );

  double? _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  void _save() {
    final width = widget.unit.parseToMillimeters(_width.text);
    final length = widget.unit.parseToMillimeters(_length.text);
    final angle = _number(_angle);
    final minimumThickness = widget.object.type == SiteObjectType.line
        ? 1.0
        : 100.0;
    if (width == null ||
        width < 100 ||
        length == null ||
        length < minimumThickness ||
        angle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Chiều dài tối thiểu ${widget.unit.format(100)}, độ dày tối thiểu ${widget.unit.format(minimumThickness)}.',
          ),
        ),
      );
      return;
    }
    final updated = LayoutGeometryService.updateObjectDimensions(
      widget.object,
      widthMm: width,
      lengthMm: length,
      rotationDeg: angle,
    );
    widget.onSave(updated.copyWith(isLocked: _isLocked));
    Navigator.pop(context);
  }
}

class _MeasurementProperties extends StatefulWidget {
  const _MeasurementProperties({
    required this.measurement,
    required this.unit,
    required this.onSave,
  });

  final LayoutMeasurement measurement;
  final SiteDimensionUnit unit;
  final ValueChanged<LayoutMeasurement> onSave;

  @override
  State<_MeasurementProperties> createState() => _MeasurementPropertiesState();
}

class _MeasurementPropertiesState extends State<_MeasurementProperties> {
  late final _startX = TextEditingController(
    text: widget.unit.formatValue(widget.measurement.x1Mm),
  );
  late final _startY = TextEditingController(
    text: widget.unit.formatValue(widget.measurement.y1Mm),
  );
  late final _distance = TextEditingController(
    text: widget.unit.formatValue(widget.measurement.distanceMm),
  );
  late final _angle = TextEditingController(
    text: _initialAngle.toStringAsFixed(1),
  );

  double get _initialAngle =>
      math.atan2(
        widget.measurement.y2Mm - widget.measurement.y1Mm,
        widget.measurement.x2Mm - widget.measurement.x1Mm,
      ) *
      180 /
      math.pi;

  @override
  void dispose() {
    for (final controller in [_startX, _startY, _distance, _angle]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Chỉnh sửa kích thước đo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _dimensionField(_startX, 'Vị trí đầu X')),
                const SizedBox(width: 10),
                Expanded(child: _dimensionField(_startY, 'Vị trí đầu Y')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _dimensionField(_distance, 'Khoảng cách')),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _angle,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Góc',
                      suffixText: '°',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Lưu phép đo')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                context.read<SiteLayoutProvider>().deleteSelected();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xóa phép đo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dimensionField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: InputDecoration(
          labelText: label,
          suffixText: widget.unit.symbol,
        ),
      );

  void _save() {
    final startX = widget.unit.parseToMillimeters(_startX.text);
    final startY = widget.unit.parseToMillimeters(_startY.text);
    final distance = widget.unit.parseToMillimeters(_distance.text);
    final angle = double.tryParse(_angle.text.trim().replaceAll(',', '.'));
    if (startX == null ||
        startY == null ||
        distance == null ||
        distance <= 0 ||
        angle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thông số phép đo không hợp lệ.')),
      );
      return;
    }
    final radians = angle * math.pi / 180;
    widget.onSave(
      widget.measurement.copyWith(
        x1Mm: startX,
        y1Mm: startY,
        x2Mm: startX + distance * math.cos(radians),
        y2Mm: startY + distance * math.sin(radians),
      ),
    );
    Navigator.pop(context);
  }
}

class _ProjectProperties extends StatefulWidget {
  const _ProjectProperties({required this.project, required this.onSave});
  final SiteLayoutProject project;
  final ValueChanged<SiteLayoutProject> onSave;

  @override
  State<_ProjectProperties> createState() => _ProjectPropertiesState();
}

class _ProjectPropertiesState extends State<_ProjectProperties> {
  late SiteDimensionUnit _unit = widget.project.dimensionUnit;
  late final _name = TextEditingController(text: widget.project.name);
  late final _customer = TextEditingController(text: widget.project.customer);
  late final _location = TextEditingController(text: widget.project.location);
  late final _surveyor = TextEditingController(text: widget.project.surveyor);
  late final _width = TextEditingController(
    text: _unit.formatValue(widget.project.siteWidthMm),
  );
  late final _length = TextEditingController(
    text: _unit.formatValue(widget.project.siteLengthMm),
  );
  late final _ceiling = TextEditingController(
    text: widget.project.ceilingHeightMm == null
        ? ''
        : _unit.formatValue(widget.project.ceilingHeightMm!),
  );
  late final _beam = TextEditingController(
    text: widget.project.lowestBeamHeightMm == null
        ? ''
        : _unit.formatValue(widget.project.lowestBeamHeightMm!),
  );
  late final _notes = TextEditingController(text: widget.project.notes);

  @override
  void dispose() {
    for (final controller in [
      _name,
      _customer,
      _location,
      _surveyor,
      _width,
      _length,
      _ceiling,
      _beam,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(String value) => _unit.parseToMillimeters(value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(
              'Thông tin dự án',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            for (final item in <(TextEditingController, String)>[
              (_name, 'Tên dự án'),
              (_customer, 'Khách hàng'),
              (_location, 'Địa điểm'),
              (_surveyor, 'Người khảo sát'),
            ]) ...[
              TextField(
                controller: item.$1,
                decoration: InputDecoration(labelText: item.$2),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kích thước mặt bằng lắp đặt',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SegmentedButton<SiteDimensionUnit>(
                  showSelectedIcon: false,
                  segments: SiteDimensionUnit.values
                      .map(
                        (unit) => ButtonSegment(
                          value: unit,
                          label: Text(unit.symbol),
                        ),
                      )
                      .toList(),
                  selected: {_unit},
                  onSelectionChanged: (selection) =>
                      _changeUnit(selection.first),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _numberField(_width, 'Chiều rộng')),
                const SizedBox(width: 10),
                Expanded(child: _numberField(_length, 'Chiều dài')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _numberField(_ceiling, 'Chiều cao trần')),
                const SizedBox(width: 10),
                Expanded(child: _numberField(_beam, 'Dầm thấp nhất')),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Lưu thông tin dự án'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, suffixText: _unit.symbol),
      );

  void _changeUnit(SiteDimensionUnit next) {
    if (next == _unit) return;
    for (final controller in [_width, _length, _ceiling, _beam]) {
      final millimeters = _unit.parseToMillimeters(controller.text);
      if (millimeters != null) controller.text = next.formatValue(millimeters);
    }
    setState(() => _unit = next);
  }

  void _save() {
    final width = _number(_width.text);
    final length = _number(_length.text);
    if (_name.text.trim().isEmpty ||
        _location.text.trim().isEmpty ||
        _surveyor.text.trim().isEmpty ||
        width == null ||
        width <= 0 ||
        length == null ||
        length <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thông tin dự án và kích thước phải hợp lệ.'),
        ),
      );
      return;
    }
    widget.onSave(
      widget.project.copyWith(
        name: _name.text.trim(),
        customer: _customer.text.trim(),
        location: _location.text.trim(),
        surveyor: _surveyor.text.trim(),
        siteWidthMm: width,
        siteLengthMm: length,
        dimensionUnit: _unit,
        ceilingHeightMm: _number(_ceiling.text),
        clearCeilingHeight: _ceiling.text.trim().isEmpty,
        lowestBeamHeightMm: _number(_beam.text),
        clearLowestBeamHeight: _beam.text.trim().isEmpty,
        notes: _notes.text.trim(),
      ),
    );
    Navigator.pop(context);
  }
}
