import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pipe_survey.dart';
import '../providers/pipe_survey_controller.dart';
import 'survey_sheets.dart';

/// Tab "Thông tin": công trình, khách hàng, ngày khảo sát, kích thước nhà
/// xưởng, độ cao treo ống, cỡ ống mặc định.
class SurveyInfoForm extends StatefulWidget {
  const SurveyInfoForm({super.key, required this.ctrl});
  final PipeSurveyController ctrl;

  @override
  State<SurveyInfoForm> createState() => _SurveyInfoFormState();
}

class _SurveyInfoFormState extends State<SurveyInfoForm> {
  late final s = widget.ctrl.survey;
  late final _name = TextEditingController(text: s.name);
  late final _customer = TextEditingController(text: s.customer);
  late final _address = TextEditingController(text: s.address);
  late final _surveyor = TextEditingController(text: s.surveyor);
  late final _title = TextEditingController(text: s.drawingTitle);
  late final _length = TextEditingController(
    text: formatSurveyNumber(s.buildingLengthM),
  );
  late final _width = TextEditingController(
    text: formatSurveyNumber(s.buildingWidthM),
  );
  late final _hang = TextEditingController(
    text: formatSurveyNumber(s.hangHeightM),
  );

  @override
  void dispose() {
    for (final c in [
      _name,
      _customer,
      _address,
      _surveyor,
      _title,
      _length,
      _width,
      _hang,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final survey = ctrl.survey;
    final scheme = Theme.of(context).colorScheme;
    Widget field(
      String key,
      TextEditingController c,
      String label,
      void Function(String v) set, {
      bool number = false,
      String? suffix,
      String? hint,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key('survey_info_$key'),
        controller: c,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixText: suffix,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) => ctrl.edit((_) => set(v), undoable: false),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        field('name', _name, 'Tên công trình', (v) => survey.name = v.trim()),
        field(
          'customer',
          _customer,
          'Khách hàng',
          (v) => survey.customer = v.trim(),
        ),
        field('address', _address, 'Địa chỉ', (v) => survey.address = v.trim()),
        field(
          'surveyor',
          _surveyor,
          'Người khảo sát',
          (v) => survey.surveyor = v.trim(),
        ),
        field(
          'title',
          _title,
          'Tên bản vẽ (khung tên trên sơ đồ)',
          (v) => survey.drawingTitle = v.trim(),
          hint: PipeSurvey.defaultDrawingTitle,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            key: const Key('survey_info_date'),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: survey.surveyDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                ctrl.edit((s) => s.surveyDate = picked, undoable: false);
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Ngày khảo sát',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.event_outlined),
              ),
              child: Text(DateFormat('dd/MM/yyyy').format(survey.surveyDate)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Nhà xưởng (để vẽ khung tường bao, không bắt buộc)',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: field(
                'length',
                _length,
                'Dài',
                (v) => survey.buildingLengthM = parseSurveyNumber(v),
                number: true,
                suffix: 'm',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: field(
                'width',
                _width,
                'Rộng',
                (v) => survey.buildingWidthM = parseSurveyNumber(v),
                number: true,
                suffix: 'm',
              ),
            ),
          ],
        ),
        field(
          'hang',
          _hang,
          'Độ cao treo ống',
          (v) => survey.hangHeightM = parseSurveyNumber(v),
          number: true,
          suffix: 'm',
          hint: 'Nhập theo thực tế',
        ),
        DropdownButtonFormField<int>(
          key: const Key('survey_info_dn'),
          initialValue: survey.defaultDn,
          decoration: const InputDecoration(
            labelText: 'Cỡ ống mặc định (đoạn mới)',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final size in ctrl.constants.sizes)
              DropdownMenuItem(value: size, child: Text('DN$size')),
          ],
          onChanged: (v) {
            if (v != null) ctrl.edit((s) => s.defaultDn = v, undoable: false);
          },
        ),
      ],
    );
  }
}
