import 'package:flutter/material.dart';

import '../../../data/product_data.dart';
import '../../air_system_config/l10n/air_strings.dart';
import '../../air_system_config/pipe/material_catalog.dart';
import '../../air_system_config/pipe/material_list.dart';
import '../../air_system_config/widgets/editable_material_table.dart';
import '../engine/survey_bom.dart';
import '../providers/pipe_survey_controller.dart';
import 'survey_sheets.dart';

String surveyWarningText(SurveyWarning w) => switch (w.code) {
  SurveyWarningCode.empty =>
    'Chưa có đoạn ống: sang tab Sơ đồ để vẽ tuyến ống.',
  SurveyWarningCode.noHangHeight =>
    'Chưa nhập độ cao treo ống (tab Thông tin): chưa tính ống đứng xuống máy.',
  SurveyWarningCode.isolatedPoint =>
    'Điểm "${w.params['name']}" chưa nối vào ống.',
  SurveyWarningCode.hangBelowConnection =>
    'Điểm "${w.params['name']}": độ cao treo không cao hơn cao độ đầu nối, không tính ống đứng.',
};

/// Tab "Vật tư": cảnh báo, tổng hợp chiều dài theo cỡ, bảng đoạn ống, bảng
/// vật tư bóc từ sơ đồ (sửa tay được, chọn từ danh mục).
class SurveyMaterialsView extends StatelessWidget {
  const SurveyMaterialsView({super.key, required this.ctrl});
  final PipeSurveyController ctrl;

  @override
  Widget build(BuildContext context) {
    final bom = ctrl.bom;
    final s = ctrl.survey;
    final c = ctrl.constants;
    final scheme = Theme.of(context).colorScheme;
    const list = PipeSurveyController.materialList;
    Widget card(String title, IconData icon, List<Widget> children) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );

    final dns = bom.lengthByDn.keys.toList()..sort((a, b) => b - a);
    return ListView(
      key: const PageStorageKey('survey_materials'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        for (final w in bom.warnings)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              surveyWarningText(w),
              style: const TextStyle(color: Color(0xFF1E293B)),
            ),
          ),
        card('Tổng hợp tuyến ống', Icons.straighten_rounded, [
          for (final dn in dns)
            Text(
              'Ống DN$dn: ${formatSurveyNumber(_round1(bom.lengthByDn[dn]!))} m',
            ),
          Text('Điểm sử dụng: ${s.usePoints.length}'),
          if (dns.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Ống làm tròn nguyên cây ${formatSurveyNumber(c.barLengthM)} m; phụ kiện cộng dự phòng ${formatSurveyNumber(c.reservePercent)}%, van không cộng.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
            ),
        ]),
        if (bom.runs.isNotEmpty)
          card('Bảng đoạn ống', Icons.timeline_rounded, [
            Table(
              key: const Key('survey_runs_table'),
              border: TableBorder.all(color: scheme.outlineVariant),
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FixedColumnWidth(56),
                2: FixedColumnWidth(64),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: scheme.secondaryContainer),
                  children: [
                    for (final h in ['Đoạn', 'Cỡ', 'Dài (m)'])
                      _cell(h, bold: true),
                  ],
                ),
                for (final r in bom.runs)
                  TableRow(
                    children: [
                      _cell(r.label),
                      _cell('DN${r.dn}', center: true),
                      _cell(
                        '${formatSurveyNumber(_round1(r.lengthM))}${r.measured ? '*' : ''}',
                        center: true,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '* chiều dài đo thực tế; còn lại theo hình vẽ.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ]),
        card('Vật tư theo khảo sát', Icons.list_alt_rounded, [
          EditableMaterialTable(
            strings: AirStrings(AirLang.vi),
            rows: ctrl.materialRows,
            tableKey: 'survey_bom_table',
            edited: s.edits[list] != null,
            catalog: buildMaterialCatalog(kits: installKits, run: pipeRunKit),
            onSave: (row, d) => ctrl.edit(
              (s) => row == null
                  ? s.edits.addMaterial(
                      list,
                      code: d.code,
                      name: d.name,
                      spec: d.spec,
                      unit: d.unit,
                      qty: d.qty,
                    )
                  : s.edits.saveMaterial(
                      list,
                      row,
                      code: d.code,
                      name: d.name,
                      spec: d.spec,
                      unit: d.unit,
                      qty: d.qty,
                    ),
              undoable: false,
            ),
            onDelete: (row) => ctrl.edit(
              (s) => s.edits.removeMaterial(list, row),
              undoable: false,
            ),
            onReset: (row) => ctrl.edit(
              (s) => s.edits.resetMaterial(list, row),
              undoable: false,
            ),
            onResetList: () => ctrl.edit(
              (s) => s.edits.resetMaterialList(list),
              undoable: false,
            ),
          ),
        ]),
      ],
    );
  }

  static double _round1(double v) => (v * 10).round() / 10;

  static Widget _cell(String text, {bool bold = false, bool center = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        child: Text(
          text,
          textAlign: bold || center ? TextAlign.center : TextAlign.start,
          style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
      );
}
