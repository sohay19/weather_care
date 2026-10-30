import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/weather_theme.dart';

Future<TimeOfDay?> showNotificationTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  required String title,
}) =>
    showDialog<TimeOfDay>(
      context: context,
      builder: (_) => NotificationTimePickerDialog(
        initialTime: initialTime,
        title: title,
      ),
    );

class NotificationTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final String title;

  const NotificationTimePickerDialog({
    super.key,
    required this.initialTime,
    required this.title,
  });

  @override
  State<NotificationTimePickerDialog> createState() =>
      _NotificationTimePickerDialogState();
}

class _NotificationTimePickerDialogState
    extends State<NotificationTimePickerDialog> {
  final _form = GlobalKey<FormState>();
  late TimeOfDay _time = widget.initialTime;
  late final _hour = TextEditingController(text: _digits(_time.hour));
  late final _minute = TextEditingController(text: _digits(_time.minute));
  bool _typing = false;

  static String _digits(int value) => value.toString().padLeft(2, '0');

  bool _readInput() {
    if (!_form.currentState!.validate()) return false;
    _time =
        TimeOfDay(hour: int.parse(_hour.text), minute: int.parse(_minute.text));
    return true;
  }

  void _switchMode() {
    if (_typing && !_readInput()) return;
    FocusScope.of(context).unfocus();
    _hour.text = _digits(_time.hour);
    _minute.text = _digits(_time.minute);
    _hour.selection =
        TextSelection(baseOffset: 0, extentOffset: _hour.text.length);
    setState(() => _typing = !_typing);
  }

  void _confirm() {
    if (_typing && !_readInput()) return;
    Navigator.of(context).pop(_time);
  }

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        scrollable: true,
        title: Text(widget.title),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_typing)
              Form(
                key: _form,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _input(hour: true)),
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Text(':', style: TextStyle(fontSize: 24)),
                      ),
                      Expanded(child: _input(hour: false)),
                    ]),
              )
            else
              _TimeWheels(
                initialTime: _time,
                onChanged: (value) => _time = value,
              ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _switchMode,
              icon: Icon(
                  _typing ? Icons.swap_vert_rounded : Icons.keyboard_outlined),
              label: Text(_typing ? '스크롤로 선택' : '숫자로 입력'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소')),
          FilledButton(onPressed: _confirm, child: const Text('확인')),
        ],
      );

  Widget _input({required bool hour}) => TextFormField(
        key: ValueKey(
            hour ? 'notification-hour-input' : 'notification-minute-input'),
        controller: hour ? _hour : _minute,
        autofocus: hour,
        keyboardType: TextInputType.number,
        textInputAction: hour ? TextInputAction.next : TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        onTap: () {
          final controller = hour ? _hour : _minute;
          controller.selection = TextSelection(
              baseOffset: 0, extentOffset: controller.text.length);
        },
        decoration: InputDecoration(
          labelText: hour ? '시' : '분',
          helperText: hour ? '0~23' : '0~59',
          border: const OutlineInputBorder(),
        ),
        validator: (text) {
          final value = int.tryParse(text ?? '');
          return value == null || value < 0 || value > (hour ? 23 : 59)
              ? (hour ? '0~23 입력' : '0~59 입력')
              : null;
        },
        onFieldSubmitted: (_) {
          if (!hour) _confirm();
        },
      );
}

class _TimeWheels extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onChanged;

  const _TimeWheels({required this.initialTime, required this.onChanged});

  @override
  State<_TimeWheels> createState() => _TimeWheelsState();
}

class _TimeWheelsState extends State<_TimeWheels> {
  late int _hour = widget.initialTime.hour;
  late int _minute = widget.initialTime.minute;
  // 직접 입력한 분도 표시해 다시 열거나 모드를 바꿀 때 반올림하지 않는다.
  late final _minutes =
      <int>{for (var i = 0; i < 60; i += 5) i, _minute}.toList()..sort();
  late final _hours = FixedExtentScrollController(initialItem: _hour);
  late final _minuteScroll =
      FixedExtentScrollController(initialItem: _minutes.indexOf(_minute));

  @override
  void dispose() {
    _hours.dispose();
    _minuteScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = WeatherCareTheme.of(context);
    final extent =
        math.max(44.0, MediaQuery.textScalerOf(context).scale(22) + 16);
    return Row(children: [
      for (final hour in [true, false])
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(hour ? '시' : '분'),
            const SizedBox(height: 8),
            SizedBox(
              height: extent * 3,
              child: CupertinoPicker(
                key: ValueKey(hour
                    ? 'notification-hour-wheel'
                    : 'notification-minute-wheel'),
                scrollController: hour ? _hours : _minuteScroll,
                itemExtent: extent,
                selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                  background: colors.primary.withValues(alpha: 0.12),
                ),
                onSelectedItemChanged: (index) {
                  if (hour) {
                    _hour = index;
                  } else {
                    _minute = _minutes[index];
                  }
                  widget.onChanged(TimeOfDay(hour: _hour, minute: _minute));
                },
                children: [
                  for (final value
                      in hour ? List.generate(24, (i) => i) : _minutes)
                    Center(
                        child: Text(
                      value.toString().padLeft(2, '0'),
                      style: TextStyle(
                          fontFamily: WeatherCareTheme.fontSuite,
                          color: colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600),
                    )),
                ],
              ),
            ),
          ]),
        ),
    ]);
  }
}
