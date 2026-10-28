import 'package:flutter/material.dart';

import '../../models/app_settings.dart';
import '../../theme/weather_theme.dart';

class CommuteNotificationSettingsScreen extends StatefulWidget {
  final AppSettings initialSettings;
  final bool enabled;
  final ValueChanged<AppSettings> onSettingsChanged;

  const CommuteNotificationSettingsScreen({
    super.key,
    required this.initialSettings,
    required this.enabled,
    required this.onSettingsChanged,
  });

  @override
  State<CommuteNotificationSettingsScreen> createState() =>
      _CommuteNotificationSettingsScreenState();
}

class _CommuteNotificationSettingsScreenState
    extends State<CommuteNotificationSettingsScreen> {
  late AppSettings settings = widget.initialSettings;

  Future<void> _selectTime({required bool toWork, required bool start}) async {
    if (!widget.enabled) return;
    final from =
        toWork ? settings.commuteToWorkStart : settings.commuteFromWorkStart;
    final until =
        toWork ? settings.commuteToWorkEnd : settings.commuteFromWorkEnd;
    final value = start ? from : until;
    final pieces = value.split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: int.parse(pieces[0]), minute: int.parse(pieces[1])),
      helpText: '${toWork ? '출근' : '퇴근'} ${start ? '시작' : '종료'} 시각',
      cancelText: '취소',
      confirmText: '확인',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    final time = '${selected.hour.toString().padLeft(2, '0')}:'
        '${selected.minute.toString().padLeft(2, '0')}';
    if (time == value) return;
    if (time == (start ? until : from)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시작과 종료 시각을 다르게 선택해주세요.')),
      );
      return;
    }
    final updated = toWork
        ? settings.copyWith(
            commuteToWorkStart: start ? time : from,
            commuteToWorkEnd: start ? until : time,
          )
        : settings.copyWith(
            commuteFromWorkStart: start ? time : from,
            commuteFromWorkEnd: start ? until : time,
          );
    setState(() => settings = updated);
    widget.onSettingsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = WeatherCareTheme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('출퇴근 알림 시간')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text('이 시간에만 출퇴근 경로 알림을 받아요',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 10),
            Text('도로통제 안내를 받을 출근·퇴근 시간대를 각각 정해주세요.',
                style: TextStyle(color: colors.textSecondary, height: 1.5)),
            const SizedBox(height: 24),
            _timeRange(toWork: true),
            const SizedBox(height: 16),
            _timeRange(toWork: false),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '설정한 시간 안에서만 도로통제 알림을 보내요.\n'
                '시작 시각은 포함하고 종료 시각부터는 보내지 않아요.\n'
                '종료가 시작보다 이르면 다음 날까지 이어져요.\n\n'
                '준비물 요약과 다른 날씨 알림은 기존 설정을 따라요.\n'
                '기기나 통신 상태에 따라 알림 도착은 늦어질 수 있어요.',
                style: TextStyle(color: colors.textSecondary, height: 1.6),
              ),
            ),
            if (!widget.enabled)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('날씨 알림과 서버 데이터 사용을 켜면 시간을 변경할 수 있어요.'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _timeRange({required bool toWork}) {
    final colors = WeatherCareTheme.of(context);
    final from =
        toWork ? settings.commuteToWorkStart : settings.commuteFromWorkStart;
    final until =
        toWork ? settings.commuteToWorkEnd : settings.commuteFromWorkEnd;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(toWork ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
              color: colors.primary),
          const SizedBox(width: 10),
          Text(toWork ? '출근 시간' : '퇴근 시간',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(16) > 22;
          final width =
              stacked ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final start in [true, false])
              SizedBox(
                width: width,
                child: OutlinedButton(
                  key: ValueKey(
                      'commute-${toWork ? 'to' : 'from'}-${start ? 'start' : 'end'}'),
                  onPressed: widget.enabled
                      ? () => _selectTime(toWork: toWork, start: start)
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    backgroundColor: colors.surfaceMuted,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Column(children: [
                    Text(start ? '시작' : '종료'),
                    const SizedBox(height: 6),
                    Text(start ? from : until,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900)),
                  ]),
                ),
              ),
          ]);
        }),
        if (from.compareTo(until) > 0)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('종료 시각은 다음 날이에요.'),
          ),
      ]),
    );
  }
}
