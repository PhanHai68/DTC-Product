import 'dart:convert';

import 'package:flutter/material.dart';

import '../../air_system_config/l10n/air_strings.dart';
import '../../air_system_config/models/air_config.dart';
import '../../air_system_config/repositories/air_config_repository.dart';
import '../../air_system_config/room/room_engine.dart';
import '../../air_system_config/room/room_strings.dart';
import '../engine/survey_plant.dart';
import '../models/pipe_survey.dart';
import 'survey_sheets.dart';

/// Kết quả hộp chọn cụm máy: [plant] mới, hoặc bỏ (dùng ký hiệu MN).
class SurveyPlantResult {
  const SurveyPlantResult(this.plant);
  final SurveyPlant? plant;
}

final _strings = AirStrings(AirLang.vi);

/// Tóm tắt cụm máy (model thiết bị, phương án, phòng tối thiểu) cho dòng
/// "Kích thước thật" trong hộp sửa điểm.
String surveyPlantSummary(SurveyPlant? plant, SurveyPlantEngine? engine) {
  if (plant == null) return 'Chưa dùng — vẽ ký hiệu MN';
  final room = engine?.roomFor(plant);
  if (room == null) return 'Chưa chọn đủ thiết bị';
  final models = [
    for (final i in room.items)
      if (i.kind != RoomItemKind.panel && i.model != null) i.model!,
  ];
  return '${models.join(' · ')}\n${_strings.roomStyle(plant.style)} · phòng '
      '${_m(room.lengthMm)} × ${_m(room.widthMm)} m';
}

String _m(double mm) => formatSurveyNumber((mm / 100).round() / 10);

/// Hộp chọn thiết bị cụm máy và cách xếp (3 phương án như mặt bằng phòng
/// lắp đặt). Trả `null` khi huỷ.
Future<SurveyPlantResult?> showSurveyPlantDialog(
  BuildContext context, {
  required SurveyPlantEngine engine,
  SurveyPlant? initial,
  AirConfigRepository? repository,
}) => showDialog<SurveyPlantResult>(
  context: context,
  builder: (_) =>
      _PlantDialog(engine: engine, initial: initial, repository: repository),
);

class _PlantDialog extends StatefulWidget {
  const _PlantDialog({
    required this.engine,
    required this.initial,
    required this.repository,
  });
  final SurveyPlantEngine engine;
  final SurveyPlant? initial;
  final AirConfigRepository? repository;

  @override
  State<_PlantDialog> createState() => _PlantDialogState();
}

class _PlantDialogState extends State<_PlantDialog> {
  late final SurveyPlant _plant = widget.initial?.copy() ?? SurveyPlant();
  late final _pressure = TextEditingController(
    text: formatSurveyNumber(_plant.pressure),
  );

  @override
  void dispose() {
    _pressure.dispose();
    super.dispose();
  }

  Future<void> _pickConfig() async {
    final repo = widget.repository ?? AirConfigRepository();
    final list = await repo.list();
    if (!mounted) return;
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Cấu hình đã lưu'),
        children: [
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Text(
                'Chưa có cấu hình nào. Tạo trong "Cấu hình hệ thống khí nén".',
              ),
            ),
          for (final c in list)
            SimpleDialogOption(
              key: Key('survey_plant_config_${c.id}'),
              onPressed: () => Navigator.pop(context, c.id),
              child: Text(c.name.isEmpty ? '(Chưa đặt tên)' : c.name),
            ),
        ],
      ),
    );
    if (id == null) return;
    final config = await repo.get(id);
    if (config == null || !mounted) return;
    setState(() {
      _plant
        ..configId = config.id
        ..configName = config.project.name
        // Bản chụp qua JSON: lưu cùng khảo sát.
        ..configJson =
            jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _plant;
    final room = widget.engine.roomFor(p);
    final catalog = widget.engine.air.catalogModels(p.type);
    final scheme = Theme.of(context).colorScheme;
    InputDecoration deco(String label, {String? suffix}) => InputDecoration(
      labelText: label,
      suffixText: suffix,
      isDense: true,
      border: const OutlineInputBorder(),
    );
    return AlertDialog(
      title: const Text('Cụm máy theo kích thước thật'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<SurveyPlantSource>(
                key: const Key('survey_plant_source'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: SurveyPlantSource.quick,
                    label: Text('Chọn nhanh'),
                  ),
                  ButtonSegment(
                    value: SurveyPlantSource.config,
                    label: Text('Cấu hình đã lưu'),
                  ),
                ],
                selected: {p.source},
                onSelectionChanged: (v) => setState(() => p.source = v.first),
              ),
              const SizedBox(height: 12),
              if (p.source == SurveyPlantSource.quick) ...[
                DropdownButtonFormField<CompressorType>(
                  key: const Key('survey_plant_type'),
                  initialValue: p.type,
                  isExpanded: true,
                  decoration: deco('Loại máy nén'),
                  items: [
                    for (final t in CompressorType.values)
                      if (t.hasCatalog)
                        DropdownMenuItem(
                          value: t,
                          child: Text(_strings.compressorType(t)),
                        ),
                  ],
                  onChanged: (v) => setState(() {
                    if (v == null || v == p.type) return;
                    p
                      ..type = v
                      ..modelCode = null;
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: ValueKey('survey_plant_model_${p.type.name}'),
                  initialValue: catalog.any((m) => m.modelCode == p.modelCode)
                      ? p.modelCode
                      : null,
                  isExpanded: true,
                  decoration: deco('Model máy nén'),
                  items: [
                    for (final m in catalog)
                      DropdownMenuItem(
                        value: m.modelCode,
                        child: Text(
                          '${m.modelCode} · ${_strings.n2(m.powerKW)} kW',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => p.modelCode = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('survey_plant_pressure'),
                  controller: _pressure,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: deco('Áp suất làm việc', suffix: 'bar'),
                  onChanged: (v) {
                    final bar = parseSurveyNumber(v);
                    if (bar != null && bar > 0) {
                      setState(() => p.pressure = bar);
                    }
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Bình tích khí, máy sấy, lọc tự chọn theo quy tắc của '
                  'Cấu hình hệ thống khí nén.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                ListTile(
                  key: const Key('survey_plant_pick_config'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_open_outlined),
                  title: Text(
                    p.configJson == null
                        ? 'Chọn cấu hình'
                        : (p.configName.isEmpty
                              ? '(Chưa đặt tên)'
                              : p.configName),
                  ),
                  subtitle: Text(
                    p.configJson == null
                        ? 'Dùng đúng máy nén, bình, máy sấy, lọc đã cấu hình'
                        : 'Chạm để chọn lại / cập nhật theo cấu hình',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _pickConfig,
                ),
              ],
              if (room != null) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    for (final i in room.items)
                      if (i.kind != RoomItemKind.panel && i.model != null)
                        i.model!,
                  ].join(' · '),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ] else if (p.ready) ...[
                const SizedBox(height: 8),
                const Text(
                  'Chưa tính được thiết bị (kiểm tra model / áp suất).',
                  style: TextStyle(color: Color(0xFFB91C1C)),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                _strings.roomStyleLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final style in RoomStyle.values)
                _StyleTile(
                  style: style,
                  selected: p.style == style,
                  option: room?.options
                      .where((o) => o.style == style)
                      .firstOrNull,
                  onTap: () => setState(() => p.style = style),
                ),
              const SizedBox(height: 10),
              DropdownButtonFormField<SurveyPlantDir>(
                key: const Key('survey_plant_dir'),
                initialValue: p.dir,
                decoration: deco('Hướng ống ra khỏi cụm máy'),
                items: [
                  for (final d in SurveyPlantDir.values)
                    DropdownMenuItem(value: d, child: Text(_dirLabel(d))),
                ],
                onChanged: (v) => setState(() => p.dir = v ?? p.dir),
              ),
              SwitchListTile(
                key: const Key('survey_plant_flip'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Đổi phía đặt thiết bị'),
                subtitle: const Text('Thiết bị sang bên kia đường ống'),
                value: p.flip,
                onChanged: (v) => setState(() => p.flip = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            key: const Key('survey_plant_remove'),
            onPressed: () =>
                Navigator.pop(context, const SurveyPlantResult(null)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Bỏ'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          key: const Key('survey_plant_save'),
          onPressed: p.ready
              ? () => Navigator.pop(context, SurveyPlantResult(p))
              : null,
          child: const Text('Áp dụng'),
        ),
      ],
    );
  }
}

String _dirLabel(SurveyPlantDir d) => switch (d) {
  SurveyPlantDir.auto => 'Tự động (theo đoạn ống nối vào)',
  SurveyPlantDir.right => 'Sang phải',
  SurveyPlantDir.down => 'Xuống dưới',
  SurveyPlantDir.left => 'Sang trái',
  SurveyPlantDir.up => 'Lên trên',
};

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.style,
    required this.selected,
    required this.option,
    required this.onTap,
  });
  final RoomStyle style;
  final bool selected;
  final RoomOption? option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = option;
    return ListTile(
      key: Key('survey_plant_style_${style.name}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      selected: selected,
      leading: Icon(
        selected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
      ),
      title: Text(
        o == null
            ? _strings.roomStyle(style)
            : '${_strings.roomStyle(style)} · '
                  '${_m(o.lengthMm)} × ${_m(o.widthMm)} m',
      ),
      subtitle: Text(_strings.roomStyleHint(style)),
      onTap: onTap,
    );
  }
}
