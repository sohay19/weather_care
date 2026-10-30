import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import 'notification_time_picker.dart';
import 'settings_time_control.dart';

class CommuteNotificationTimeControls extends StatelessWidget {
  final AppSettings settings;
  final bool enabled;
  final ValueChanged<AppSettings> onSettingsChanged;

  const CommuteNotificationTimeControls(
      {super.key,
      required this.settings,
      required this.enabled,
      required this.onSettingsChanged});

  Future<void> _edit(BuildContext context, bool toWork) async {
    final from =
        toWork ? settings.commuteToWorkStart : settings.commuteFromWorkStart;
    final until =
        toWork ? settings.commuteToWorkEnd : settings.commuteFromWorkEnd;
    TimeOfDay parse(String value) {
      final pieces = value.split(':');
      return TimeOfDay(
          hour: int.parse(pieces[0]), minute: int.parse(pieces[1]));
    }

    String format(TimeOfDay time) =>
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final selected = await showNotificationTimeRangePicker(
      context: context,
      initialStartTime: parse(from),
      initialEndTime: parse(until),
      title: '${toWork ? '출근' : '퇴근'} 알림 시간 범위',
    );
    if (selected == null || !context.mounted) return;
    final start = format(selected.$1);
    final end = format(selected.$2);
    if (start == from && end == until) return;
    onSettingsChanged(toWork
        ? settings.copyWith(commuteToWorkStart: start, commuteToWorkEnd: end)
        : settings.copyWith(
            commuteFromWorkStart: start, commuteFromWorkEnd: end));
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        SettingsTimeControl(
          key: const ValueKey('commute-to-control'),
          label: '출근',
          value: '${settings.commuteToWorkStart}~${settings.commuteToWorkEnd}',
          onTap: enabled ? () => _edit(context, true) : null,
        ),
        const SizedBox(height: 10),
        SettingsTimeControl(
          key: const ValueKey('commute-from-control'),
          label: '퇴근',
          value:
              '${settings.commuteFromWorkStart}~${settings.commuteFromWorkEnd}',
          onTap: enabled ? () => _edit(context, false) : null,
        ),
      ]);
}
