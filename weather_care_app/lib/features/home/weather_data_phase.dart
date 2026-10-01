import 'package:flutter/widgets.dart';

enum WeatherDataPhase { loading, ready, failed }

extension WeatherDataPhaseLabel on WeatherDataPhase {
  String missingText([String readyText = '자료 없음']) => switch (this) {
        WeatherDataPhase.loading => '불러오는 중',
        WeatherDataPhase.ready => readyText,
        WeatherDataPhase.failed => '서버 연결 실패',
      };

  String get explanation => switch (this) {
        WeatherDataPhase.loading => '서버에서 자료를 불러오고 있어요.',
        WeatherDataPhase.ready => '현재 제공된 자료에 이 항목의 값이 없어요.',
        WeatherDataPhase.failed => '서버와 통신하지 못해 자료를 불러오지 못했어요. 다시 시도해주세요.',
      };
}

class WeatherDataPhaseScope extends InheritedWidget {
  final WeatherDataPhase phase;

  const WeatherDataPhaseScope({
    super.key,
    required this.phase,
    required super.child,
  });

  static WeatherDataPhase of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WeatherDataPhaseScope>()
          ?.phase ??
      WeatherDataPhase.ready;

  @override
  bool updateShouldNotify(WeatherDataPhaseScope oldWidget) =>
      phase != oldWidget.phase;
}
