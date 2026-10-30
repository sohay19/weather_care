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
    final selected = <String>[];
    for (final start in [true, false]) {
      final pieces = (start ? from : until).split(':');
      final time = await showNotificationTimePicker(
        context: context,
        initialTime:
            TimeOfDay(hour: int.parse(pieces[0]), minute: int.parse(pieces[1])),
        title: '${toWork ? '출근' : '퇴근'} ${start ? '시작' : '종료'} 시각',
      );
      if (time == null || !context.mounted) return;
      selected.add(
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
    }
    if (selected[0] == selected[1]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작과 종료 시각을 다르게 선택해주세요.')),
      );
      return;
    }
    if (selected[0] == from && selected[1] == until) return;
    onSettingsChanged(toWork
        ? settings.copyWith(
            commuteToWorkStart: selected[0], commuteToWorkEnd: selected[1])
        : settings.copyWith(
            commuteFromWorkStart: selected[0],
            commuteFromWorkEnd: selected[1]));
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
