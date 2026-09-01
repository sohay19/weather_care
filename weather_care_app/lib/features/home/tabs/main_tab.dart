import 'package:flutter/material.dart';

import '../../../models/lifestyle_message.dart';
import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/tab_page_header.dart';
import '../widgets/weather_condition_icon.dart';

class MainTab extends StatelessWidget {
  final TodayWeatherResponse today;
  final String dateLabel;
  final String mood;
  final bool serverFeaturesAvailable;
  final Future<void> Function() onRefresh;

  const MainTab({
    super.key,
    required this.today,
    required this.dateLabel,
    required this.mood,
    required this.serverFeaturesAvailable,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: WeatherCareTheme.primary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          return CustomScrollView(
            key: const ValueKey('main-tab'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  compact ? 8 : 12,
                  16,
                  24,
                ),
                sliver: SliverList.list(
                  children: [
                    TabPageHeader(
                      eyebrow: dateLabel,
                      title: '${today.region.name}이라면 확인하세요',
                      subtitle: '화면을 아래로 당기면 최신 날씨 정보를 가져와요',
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    _TopWeatherCard(
                      today: today,
                      mood: mood,
                      compact: compact,
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    _LifestyleDashboard(
                      messages: today.lifestyleMessages,
                      dataStatusMessages: today.dataStatusMessages,
                      compact: compact,
                      serverFeaturesAvailable: serverFeaturesAvailable,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopWeatherCard extends StatelessWidget {
  final TodayWeatherResponse today;
  final String mood;
  final bool compact;

  const _TopWeatherCard({
    required this.today,
    required this.mood,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final current = today.current;
    final apparentTemperature = current.apparentTemperature;
    final fineDustValue = current.pm25 ?? current.pm10;
    final usesPm25 = current.pm25 != null;
    final feelingStyle = TextStyle(
      color: WeatherCareTheme.textPrimary,
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w600,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 13 : 16),
      decoration: WeatherCareTheme.mood(mood),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            today.brief,
            style: TextStyle(
              fontFamily: WeatherCareTheme.fontNeoHyundai,
              color: WeatherCareTheme.textPrimary,
              fontSize: compact ? 21 : 23,
              height: 1.24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.45,
            ),
          ),
          SizedBox(height: compact ? 22 : 28),
          Row(
            children: [
              Text(
                _forecastTemperatureLabel(current.forecastAt),
                style: TextStyle(
                  color: WeatherCareTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${current.temperature.toStringAsFixed(1)}℃',
                style: const TextStyle(
                  color: WeatherCareTheme.primaryDeep,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            key: const ValueKey('main-apparent-temperature-row'),
            children: [
              const Text(
                '예상 체감온도',
                style: TextStyle(
                  color: WeatherCareTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              if (apparentTemperature != null)
                Text(
                  '${apparentTemperature.toStringAsFixed(1)}℃',
                  style: const TextStyle(
                    color: WeatherCareTheme.primaryDeep,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Row(
            key: const ValueKey('main-weather-feeling'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _weatherSummaryMessage(
                    sky: current.sky,
                    apparentTemperature: apparentTemperature,
                    apparentTemperatureSource:
                        current.apparentTemperatureSource,
                  ),
                  style: feelingStyle,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: WeatherConditionIcon(
                  condition: current.sky,
                  color: WeatherCareTheme.textPrimary,
                  size: compact ? 20 : 23,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Container(
            padding: EdgeInsets.symmetric(vertical: compact ? 7 : 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                _TopMetric(
                  icon: Icons.water_drop_outlined,
                  label: '습도',
                  value: current.humidity == null
                      ? '--'
                      : '${current.humidity!.toStringAsFixed(0)}%',
                  state: _humidityState(current.humidity),
                ),
                _TopMetric(
                  icon: Icons.air_rounded,
                  label: '풍속',
                  value: current.windSpeed == null
                      ? '--'
                      : '${current.windSpeed!.toStringAsFixed(1)}m/s',
                  state: _windState(current.windSpeed),
                ),
                _TopMetric(
                  icon: Icons.wb_sunny_outlined,
                  label: '자외선',
                  value: current.uvIndex?.toStringAsFixed(0) ?? '--',
                  state: _uvState(current.uvIndex),
                ),
                _TopMetric(
                  icon: Icons.grain_rounded,
                  label: usesPm25 ? '초미세먼지' : '미세먼지',
                  value: fineDustValue == null ? '--' : '$fineDustValue㎍',
                  state: usesPm25
                      ? _pm25State(current.pm25)
                      : _pm10State(current.pm10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final _MetricState state;

  const _TopMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label $value, ${state.label}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: state.color),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: state.color,
                fontSize: 10.5,
                height: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: WeatherCareTheme.microTextStyle.copyWith(fontSize: 8.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricState {
  final String label;
  final Color color;

  const _MetricState(this.label, this.color);
}

const _unavailableMetric =
    _MetricState('정보 없음', WeatherCareTheme.textSecondary);

_MetricState _humidityState(double? value) => value == null
    ? _unavailableMetric
    : const _MetricState('실외 상대습도', WeatherCareTheme.primaryDeep);

_MetricState _windState(double? value) {
  if (value == null) return _unavailableMetric;
  if (value < 4) {
    return const _MetricState('약한 바람', WeatherCareTheme.primaryDeep);
  }
  if (value < 9) {
    return const _MetricState('약간 강한 바람', WeatherCareTheme.primaryDeep);
  }
  if (value < 14) {
    return const _MetricState('강한 바람', WeatherCareTheme.attentionDeep);
  }
  return const _MetricState('매우 강한 바람', WeatherCareTheme.danger);
}

_MetricState _uvState(double? value) {
  if (value == null) return _unavailableMetric;
  if (value <= 2) {
    return const _MetricState('낮음', WeatherCareTheme.primaryDeep);
  }
  if (value <= 5) {
    return const _MetricState('보통', WeatherCareTheme.primaryDeep);
  }
  if (value <= 7) {
    return const _MetricState('높음', WeatherCareTheme.attentionDeep);
  }
  if (value <= 10) {
    return const _MetricState('매우 높음', WeatherCareTheme.danger);
  }
  return const _MetricState('위험', WeatherCareTheme.danger);
}

_MetricState _pm25State(int? value) {
  if (value == null) return _unavailableMetric;
  if (value <= 15) {
    return const _MetricState('좋음', WeatherCareTheme.primaryDeep);
  }
  if (value <= 35) {
    return const _MetricState('보통', WeatherCareTheme.primaryDeep);
  }
  if (value <= 75) {
    return const _MetricState('나쁨', WeatherCareTheme.attentionDeep);
  }
  return const _MetricState('매우 나쁨', WeatherCareTheme.danger);
}

_MetricState _pm10State(int? value) {
  if (value == null) return _unavailableMetric;
  if (value <= 30) {
    return const _MetricState('좋음', WeatherCareTheme.primaryDeep);
  }
  if (value <= 80) {
    return const _MetricState('보통', WeatherCareTheme.primaryDeep);
  }
  if (value <= 150) {
    return const _MetricState('나쁨', WeatherCareTheme.attentionDeep);
  }
  return const _MetricState('매우 나쁨', WeatherCareTheme.danger);
}

class _LifestyleDashboard extends StatelessWidget {
  final List<LifestyleMessage> messages;
  final List<WeatherMessagePart> dataStatusMessages;
  final bool compact;
  final bool serverFeaturesAvailable;

  const _LifestyleDashboard({
    required this.messages,
    required this.dataStatusMessages,
    required this.compact,
    required this.serverFeaturesAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final display = _todoItems(messages);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 13 : 16),
      decoration: WeatherCareTheme.surfaceDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: WeatherCareTheme.primarySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Text(
                  'TODAY',
                  style: WeatherCareTheme.specialLabelStyle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Check List',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '오늘 날씨에 체크해야할 일들이에요',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          if (!serverFeaturesAvailable)
            const _LifestyleUnsupported()
          else if (display.isEmpty && dataStatusMessages.isEmpty)
            const _NoLifestyleMessages()
          else ...[
            for (var index = 0; index < display.length; index++) ...[
              _LifestyleActionCard(
                item: display[index],
                compact: compact,
              ),
              if (index < display.length - 1) SizedBox(height: compact ? 7 : 9),
            ],
            if (display.isNotEmpty && dataStatusMessages.isNotEmpty)
              SizedBox(height: compact ? 8 : 10),
            for (final status in dataStatusMessages)
              _DataStatusLine(status: status),
          ],
        ],
      ),
    );
  }
}

class _NoLifestyleMessages extends StatelessWidget {
  const _NoLifestyleMessages();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WeatherCareTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Text(
        '현재 예보에서 안내할 생활행동이 없어요.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: WeatherCareTheme.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DataStatusLine extends StatelessWidget {
  final WeatherMessagePart status;

  const _DataStatusLine({required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 15,
            color: WeatherCareTheme.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status.text,
              style: WeatherCareTheme.microTextStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifestyleUnsupported extends StatelessWidget {
  const _LifestyleUnsupported();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: WeatherCareTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Text(
        '운영 서버 미연결로 미지원',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: WeatherCareTheme.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LifestyleActionCard extends StatelessWidget {
  final _TodoItem item;
  final bool compact;

  const _LifestyleActionCard({
    required this.item,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    const style = _TodoStyle(
      background: WeatherCareTheme.surfaceSubtle,
      iconBackground: WeatherCareTheme.primarySoft,
      accent: WeatherCareTheme.primaryDeep,
    );
    return Container(
      key: ValueKey('main-todo-${item.title}'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 15 : 18,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 32 : 36,
            height: compact ? 32 : 36,
            decoration: BoxDecoration(
              color: style.iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              color: style.accent,
              size: compact ? 17 : 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.actionText,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                for (final part in item.details) ...[
                  const SizedBox(height: 5),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${part.role.label} · ',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(text: part.text),
                      ],
                    ),
                    style: WeatherCareTheme.microTextStyle.copyWith(
                      fontSize: compact ? 8.5 : 9.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _weatherExpression(String? sky) {
  final value = sky ?? '';
  if (value.contains('비')) return '비가 내리는 날씨예요.';
  if (value.contains('눈')) return '눈이 내리는 날씨예요.';
  if (value.contains('흐림') || value.contains('구름')) {
    return '구름이 많은 날씨예요.';
  }
  return '맑은 하늘이 이어지는 날씨예요.';
}

String _forecastTemperatureLabel(String? forecastAt) {
  if (forecastAt == null || forecastAt.length < 13) return '예상기온';
  final hour = int.tryParse(forecastAt.substring(11, 13));
  if (hour == null) return '예상기온';
  final period = hour < 12 ? '오전' : '오후';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$period $hour12시 예상기온';
}

String _weatherSummaryMessage({
  required String? sky,
  required double? apparentTemperature,
  required String? apparentTemperatureSource,
}) {
  final weatherExpression = _weatherExpression(sky);
  if (apparentTemperature == null) {
    return '$weatherExpression 예상 체감온도는 계산조건이 맞을 때 표시해요.';
  }
  final sourceLabel =
      apparentTemperatureSource == 'APP_KMA_METHOD_FROM_FORECAST'
          ? '기상청 예보의 기온·습도·풍속으로 계산한'
          : '제공된 자료로 확인한';
  return '$weatherExpression $sourceLabel 예상 체감온도는 ${apparentTemperature.toStringAsFixed(1)}℃예요.';
}

List<_TodoItem> _todoItems(List<LifestyleMessage> messages) {
  return messages.map((message) {
    final presentation = _lifestylePresentation(message.type);
    final actions = message.parts
        .where((part) => part.role == WeatherMessageRole.appSuggestion)
        .map((part) => part.text)
        .toList();
    final action = actions.isEmpty ? null : actions.first;
    final details = message.parts
        .where((part) => part.role != WeatherMessageRole.appSuggestion)
        .toList();
    return _TodoItem(
      icon: presentation.icon,
      title: message.title,
      actionText: action ?? message.title,
      details: details,
    );
  }).toList();
}

class _TodoItem {
  final IconData icon;
  final String title;
  final String actionText;
  final List<WeatherMessagePart> details;

  const _TodoItem({
    required this.icon,
    required this.title,
    required this.actionText,
    this.details = const [],
  });
}

class _TodoStyle {
  final Color background;
  final Color iconBackground;
  final Color accent;

  const _TodoStyle({
    required this.background,
    required this.iconBackground,
    required this.accent,
  });
}

_LifestyleCardPresentation _lifestylePresentation(
  LifestyleMessageType type,
) {
  return switch (type) {
    LifestyleMessageType.rainGearUseful => const _LifestyleCardPresentation(
        icon: Icons.umbrella_outlined,
      ),
    LifestyleMessageType.strongSunExposure => const _LifestyleCardPresentation(
        icon: Icons.wb_sunny_outlined,
      ),
    LifestyleMessageType.laundryPickupDue => const _LifestyleCardPresentation(
        icon: Icons.local_laundry_service_outlined,
      ),
    LifestyleMessageType.outdoorCaution => const _LifestyleCardPresentation(
        icon: Icons.air_rounded,
      ),
    LifestyleMessageType.windowCloseSoon => const _LifestyleCardPresentation(
        icon: Icons.window_outlined,
      ),
    LifestyleMessageType.veryHotAndHumid => const _LifestyleCardPresentation(
        icon: Icons.thermostat_rounded,
      ),
    LifestyleMessageType.coolerThanTemperature =>
      const _LifestyleCardPresentation(
        icon: Icons.air_rounded,
      ),
    LifestyleMessageType.outerwearUseful => const _LifestyleCardPresentation(
        icon: Icons.checkroom_rounded,
      ),
    LifestyleMessageType.maskUseful => const _LifestyleCardPresentation(
        icon: Icons.masks_outlined,
      ),
    LifestyleMessageType.hydrationImportant => const _LifestyleCardPresentation(
        icon: Icons.local_drink_outlined,
      ),
    LifestyleMessageType.sunscreenUseful => const _LifestyleCardPresentation(
        icon: Icons.spa_outlined,
      ),
    LifestyleMessageType.snowTravelCaution => const _LifestyleCardPresentation(
        icon: Icons.ac_unit_rounded,
      ),
    LifestyleMessageType.largeTemperatureSwing =>
      const _LifestyleCardPresentation(
        icon: Icons.device_thermostat_outlined,
      ),
    LifestyleMessageType.rainBreakWindow => const _LifestyleCardPresentation(
        icon: Icons.schedule_rounded,
      ),
    LifestyleMessageType.bestOutingWindow => const _LifestyleCardPresentation(
        icon: Icons.schedule_rounded,
      ),
    LifestyleMessageType.petWalkWindow => const _LifestyleCardPresentation(
        icon: Icons.pets_outlined,
      ),
    LifestyleMessageType.wetRoadCaution => const _LifestyleCardPresentation(
        icon: Icons.directions_car_outlined,
      ),
    LifestyleMessageType.blackIceCaution => const _LifestyleCardPresentation(
        icon: Icons.warning_amber_rounded,
      ),
    LifestyleMessageType.rapidTemperatureDrop =>
      const _LifestyleCardPresentation(
        icon: Icons.thermostat_auto_outlined,
      ),
    LifestyleMessageType.nightWeatherCheck => const _LifestyleCardPresentation(
        icon: Icons.bedtime_outlined,
      ),
    LifestyleMessageType.unknown => const _LifestyleCardPresentation(
        icon: Icons.info_outline_rounded,
      ),
  };
}

class _LifestyleCardPresentation {
  final IconData icon;

  const _LifestyleCardPresentation({
    required this.icon,
  });
}
