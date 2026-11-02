import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../diagram/custom_equipment.dart';
import '../l10n/air_strings.dart';
import '../models/air_config.dart';
import '../pipe/pipe_strings.dart';
import '../providers/air_config_editor_controller.dart';
import 'air_diagram_view.dart';

/// Mở màn "Tuỳ chỉnh cấu hình" của [ctrl].
void openAirCustomLayout(BuildContext context, AirConfigEditorController ctrl) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider.value(
        value: ctrl,
        child: const AirCustomLayoutScreen(),
      ),
    ),
  );
}

IconData customKindIcon(CustomKind k) => switch (k) {
  CustomKind.compressor => Icons.air_rounded,
  CustomKind.afterCooler => Icons.ac_unit_rounded,
  CustomKind.tank => Icons.propane_tank_outlined,
  CustomKind.refrigeratedDryer => Icons.severe_cold_rounded,
  CustomKind.desiccantDryer => Icons.water_drop_outlined,
  _ => Icons.filter_alt_outlined,
};

/// Tuỳ chỉnh sơ đồ lắp đặt: các tầng thiết bị theo dòng khí (kéo đổi thứ
/// tự), số máy mỗi tầng, nối riêng từng nhánh, model từng máy; xem trước sơ
/// đồ ở trên.
class AirCustomLayoutScreen extends StatelessWidget {
  const AirCustomLayoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AirConfigEditorController>();
    final s = ctrl.strings;
    final layout = ctrl.config.custom;
    final eq = ctrl.customEquipment;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.customTitle),
        actions: [
          IconButton(
            key: const Key('air_custom_reset'),
            tooltip: s.customReset,
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(s.customReset),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(s.matCancel),
                    ),
                    FilledButton(
                      key: const Key('air_custom_reset_ok'),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
              if (ok ?? false) ctrl.resetCustom();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('air_custom_add'),
        onPressed: () => _add(context, ctrl, eq),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.customAdd),
      ),
      body: Column(
        children: [
          SwitchListTile(
            key: const Key('air_custom_enabled'),
            title: Text(
              s.customUse,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(s.customUseHint),
            value: layout.enabled,
            onChanged: ctrl.enableCustom,
          ),
          // Xem trước sơ đồ (đang dùng: tuỳ chỉnh; tắt: tự động).
          const SizedBox(height: 220, child: AirDiagramView()),
          const Divider(height: 1),
          Expanded(
            child: layout.stages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(s.customEmpty, textAlign: TextAlign.center),
                    ),
                  )
                : ReorderableListView.builder(
                    key: const Key('air_custom_stages'),
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
                    buildDefaultDragHandles: false,
                    itemCount: layout.stages.length,
                    onReorderItem: (from, to) => ctrl.edit((c) {
                      final st = c.custom.stages.removeAt(from);
                      c.custom.stages.insert(to, st);
                      c.custom.prune();
                    }),
                    itemBuilder: (context, k) => _StageCard(
                      key: ValueKey(layout.stages[k].id),
                      index: k,
                      ctrl: ctrl,
                      eq: eq,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(
    BuildContext context,
    AirConfigEditorController ctrl,
    CustomEquipment eq,
  ) async {
    final kind = await showModalBottomSheet<CustomKind>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final k in CustomKind.values)
              ListTile(
                key: ValueKey('air_custom_add_${k.name}'),
                leading: Icon(customKindIcon(k)),
                title: Text(eq.kindName(k)),
                onTap: () => Navigator.pop(context, k),
              ),
          ],
        ),
      ),
    );
    if (kind == null) return;
    // Thêm vào cuối, trước các lọc sau cùng nếu là máy nén / bình.
    ctrl.edit((c) {
      final stages = c.custom.stages;
      final at = switch (kind) {
        CustomKind.compressor => 0,
        _ => stages.length,
      };
      stages.insert(at, CustomStage(kind: kind));
    });
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    super.key,
    required this.index,
    required this.ctrl,
    required this.eq,
  });

  final int index;
  final AirConfigEditorController ctrl;
  final CustomEquipment eq;

  AirStrings get s => ctrl.strings;

  void _edit(void Function(CustomStage st, CustomLayout l) change) =>
      ctrl.edit((c) => change(c.custom.stages[index], c.custom));

  @override
  Widget build(BuildContext context) {
    final layout = ctrl.config.custom;
    final st = layout.stages[index];
    final scheme = Theme.of(context).colorScheme;
    final options = eq.options(st.kind);
    final models = {for (final u in st.units) eq.modelOf(st, u) ?? '—'}
        .join(', ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator_rounded),
                  ),
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(customKindIcon(st.kind), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. ${eq.kindName(st.kind)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        models,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Số máy (song song) trong tầng.
                IconButton(
                  key: ValueKey('air_custom_minus_$index'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  onPressed: st.qty > 1
                      ? () => _edit((st, l) {
                          st.units.removeLast();
                          l.prune();
                        })
                      : null,
                ),
                Text(
                  '${st.qty}',
                  key: ValueKey('air_custom_qty_$index'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  key: ValueKey('air_custom_plus_$index'),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: st.qty < 6
                      ? () => _edit((st, _) => st.units.add(CustomUnit()))
                      : null,
                ),
                IconButton(
                  key: ValueKey('air_custom_delete_$index'),
                  tooltip: s.matDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: const Color(0xFFDC2626),
                  onPressed: () => _edit((_, l) {
                    l.stages.removeAt(index);
                    l.prune();
                  }),
                ),
              ],
            ),
            if (index > 0) _Connections(index: index, ctrl: ctrl, eq: eq),
            // Model từng máy.
            if (options.isNotEmpty)
              for (var i = 0; i < st.qty; i++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('air_custom_model_${index}_$i'),
                    initialValue: options.any((o) => o.$1 == st.units[i].model)
                        ? st.units[i].model
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: st.qty > 1 ? s.customUnit(i) : s.modelLabel,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          [
                            s.customDefaultModel,
                            ?eq.defaultModel(st.kind),
                          ].join(' · '),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final (code, detail) in options)
                        DropdownMenuItem<String?>(
                          value: code,
                          child: Text(
                            '$code · $detail',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => _edit((st, _) => st.units[i].model = v),
                  ),
                )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(56, 0, 12, 4),
                child: Text(
                  s.customNoData,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Đường ống nối từ tầng trước: Gộp chung | Nối riêng (cùng số máy) |
/// Tuỳ chỉnh — chạm từng ô "Máy i → Máy j" để thêm / bỏ ống.
class _Connections extends StatelessWidget {
  const _Connections({
    required this.index,
    required this.ctrl,
    required this.eq,
  });

  final int index;
  final AirConfigEditorController ctrl;
  final CustomEquipment eq;

  @override
  Widget build(BuildContext context) {
    final s = ctrl.strings;
    final layout = ctrl.config.custom;
    final st = layout.stages[index];
    final prev = layout.stages[index - 1];
    final mode = layout.connection(index);
    final links = layout.linksFor(index);
    final (noIn, noOut) = layout.unlinked(index);
    final scheme = Theme.of(context).colorScheme;
    const warn = TextStyle(fontSize: 12, color: Color(0xFFB91C1C));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${s.customConnTitle} (${eq.kindName(prev.kind)})',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          SegmentedButton<CustomConnection>(
            key: ValueKey('air_custom_conn_$index'),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              for (final c in CustomConnection.values)
                if (c != CustomConnection.paired || layout.canPair(index))
                  ButtonSegment(value: c, label: Text(s.customConn(c))),
            ],
            selected: {mode},
            onSelectionChanged: (v) =>
                ctrl.edit((c) => c.custom.setConnection(index, v.first)),
          ),
          if (mode == CustomConnection.custom) ...[
            const SizedBox(height: 6),
            Text(
              s.customConnHint,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            for (var i = 0; i < prev.qty; i++)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        '${s.customUnit(i)} →',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (var j = 0; j < st.qty; j++)
                            FilterChip(
                              key: ValueKey('air_custom_link_${index}_${i}_$j'),
                              label: Text(s.customUnit(j)),
                              selected: links.contains((i, j)),
                              onSelected: (on) => ctrl.edit((c) {
                                final l = c.custom.stages[index].links!;
                                l.remove((i, j));
                                if (on) l.add((i, j));
                              }),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (noIn.isNotEmpty) Text(s.customNoInlet(noIn), style: warn),
          if (noOut.isNotEmpty) Text(s.customNoOutlet(noOut), style: warn),
        ],
      ),
    );
  }
}
