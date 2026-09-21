import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';

/// Khối "Nhắc tôi" trong màn tạo/sửa ghi chú: công tắc bật/tắt, khi bật mới
/// hiện thêm ngày/giờ nhắc và mức nhắc trước — mặc định OFF theo đúng yêu
/// cầu (ghi chú trước, nhắc hẹn là tuỳ chọn).
class ReminderSection extends StatelessWidget {
  const ReminderSection({
    super.key,
    required this.enabled,
    required this.dateTime,
    required this.leadTime,
    required this.onEnabledChanged,
    required this.onDateTimeChanged,
    required this.onLeadTimeChanged,
  });

  final bool enabled;
  final DateTime? dateTime;
  final ReminderLeadTime leadTime;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<DateTime> onDateTimeChanged;
  final ValueChanged<ReminderLeadTime> onLeadTimeChanged;

  Future<void> _pickDate(BuildContext context) async {
    final base = dateTime ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    onDateTimeChanged(
      DateTime(picked.year, picked.month, picked.day, base.hour, base.minute),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final base = dateTime ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;
    onDateTimeChanged(
      DateTime(base.year, base.month, base.day, picked.hour, picked.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final effectiveDate = dateTime ?? DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const Key('reminder_switch'),
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Nhắc tôi'),
          value: enabled,
          onChanged: onEnabledChanged,
        ),
        if (enabled) ...[
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const Key('reminder_date_field'),
                  onTap: () => _pickDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ngày nhắc',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    child: Text(dateFormat.format(effectiveDate)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  key: const Key('reminder_time_field'),
                  onTap: () => _pickTime(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Giờ nhắc',
                      prefixIcon: Icon(Icons.access_time_rounded),
                    ),
                    child: Text(
                      TimeOfDay.fromDateTime(effectiveDate).format(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ReminderLeadTime>(
            key: const Key('reminder_lead_time_field'),
            initialValue: leadTime,
            decoration: const InputDecoration(
              labelText: 'Nhắc trước',
              prefixIcon: Icon(Icons.timer_outlined),
            ),
            items: ReminderLeadTime.values
                .map(
                  (option) => DropdownMenuItem(
                    value: option,
                    child: Text(option.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onLeadTimeChanged(value);
            },
          ),
          if (effectiveDate
              .subtract(Duration(minutes: leadTime.minutes))
              .isBefore(DateTime.now()))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Thời điểm nhắc đã ở quá khứ. Hãy chọn ngày giờ khác.',
                style: TextStyle(color: Colors.red, fontSize: 12.5),
              ),
            ),
        ],
      ],
    );
  }
}
