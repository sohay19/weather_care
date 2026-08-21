import 'package:flutter/material.dart';

import '../../../models/lifestyle_message.dart';
import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/tab_page_header.dart';

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
          final compact = constraints.maxHeight < 620;
          return CustomScrollView(
            key: const ValueKey('main-tab'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    compact ? 8 : 12,
                    16,
                    12,
                  ),
                  child: Column(
                    children: [
                      TabPageHeader(
                        eyebrow: dateLabel,
                        title: '${today.region.name}이라면 확인하세요',
                        subtitle: '핵심만 한 화면에 정리했어요',
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      Expanded(
                        flex: compact ? 8 : 9,
                        child: _TopWeatherCard(
                          today: today,
                          mood: mood,
                          compact: compact,
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      Expanded(
                        flex: compact ? 12 : 13,
                        child: _LifestyleDashboard(
                          messages: today.lifestyleMessages,
                          compact: compact,
                          serverFeaturesAvailable: serverFeaturesAvailable,
                        ),
                      ),
                    ],
                  ),
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
    final style = TextStyle(
      color: WeatherCareTheme.textPrimary,
      fontSize: 11,
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
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: WeatherCareTheme.fontNeoHyundai,
              color: WeatherCareTheme.textPrimary,
              fontSize: compact ? 21 : 23,
              height: 1.24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.45,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Text(
                '현재 기온',
                style: TextStyle(
                  color: WeatherCareTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${current.temperature.toStringAsFixed(1)}°C',
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
            children: [
              const Text(
                '체감 온도',
                style: TextStyle(
                  color: WeatherCareTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              if (apparentTemperature != null)
                Text(
                  '${apparentTemperature.toStringAsFixed(1)}°C',
                  style: const TextStyle(
                    color: WeatherCareTheme.primaryDeep,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _weatherExpression(current.sky),
                        style: style,
                      ),
                      TextSpan(
                        text: apparentTemperature == null
                            ? ', 체감 미지원'
                            : ', 체감 상 ',
                        style: style,
                      ),
                      if (apparentTemperature != null)
                        TextSpan(
                          text: _apparentExpression(apparentTemperature),
                          style: style,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _weatherIcon(current.sky),
                color: WeatherCareTheme.textPrimary,
                size: compact ? 18 : 21,
              ),
            ],
          ),
          SizedBox(height: compact ? 7 : 9),
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
                  risk: _humidityRisk(current.humidity),
                ),
                _TopMetric(
                  icon: Icons.air_rounded,
                  label: '풍속',
                  value: current.windSpeed == null
                      ? '--'
                      : '${current.windSpeed!.toStringAsFixed(1)}m/s',
                  risk: _windRisk(current.windSpeed),
                ),
                _TopMetric(
                  icon: Icons.wb_sunny_outlined,
                  label: '자외선',
                  value: current.uvIndex?.toStringAsFixed(0) ?? '--',
                  risk: _uvRisk(current.uvIndex),
                ),
                _TopMetric(
                  icon: Icons.grain_rounded,
                  label: usesPm25 ? '초미세먼지' : '미세먼지',
                  value: fineDustValue == null ? '--' : '$fineDustValue㎍',
                  risk: usesPm25
                      ? _pm25Risk(current.pm25)
                      : _pm10Risk(current.pm10),
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
  final _MetricRisk risk;

  const _TopMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.risk,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: '$label $value, ${risk.label}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: risk.color),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: risk.color,
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

enum _MetricRisk { safe, caution, danger, unavailable }

extension on _MetricRisk {
  Color get color => switch (this) {
        _MetricRisk.safe => WeatherCareTheme.primaryDeep,
        _MetricRisk.caution => WeatherCareTheme.attention,
        _MetricRisk.danger => WeatherCareTheme.danger,
        _MetricRisk.unavailable => WeatherCareTheme.textSecondary,
      };

  String get label => switch (this) {
        _MetricRisk.safe => '안전',
        _MetricRisk.caution => '주의',
        _MetricRisk.danger => '위험',
        _MetricRisk.unavailable => '정보 없음',
      };
}

_MetricRisk _humidityRisk(double? value) {
  if (value == null) return _MetricRisk.unavailable;
  if (value >= 80) return _MetricRisk.danger;
  if (value <= 35 || value >= 70) return _MetricRisk.caution;
  return _MetricRisk.safe;
}

_MetricRisk _windRisk(double? value) {
  if (value == null) return _MetricRisk.unavailable;
  if (value >= 9) return _MetricRisk.danger;
  if (value >= 6) return _MetricRisk.caution;
  return _MetricRisk.safe;
}

_MetricRisk _uvRisk(double? value) {
  if (value == null) return _MetricRisk.unavailable;
  if (value >= 8) return _MetricRisk.danger;
  if (value >= 6) return _MetricRisk.caution;
  return _MetricRisk.safe;
}

_MetricRisk _pm25Risk(int? value) {
  if (value == null) return _MetricRisk.unavailable;
  if (value >= 76) return _MetricRisk.danger;
  if (value >= 36) return _MetricRisk.caution;
  return _MetricRisk.safe;
}

_MetricRisk _pm10Risk(int? value) {
  if (value == null) return _MetricRisk.unavailable;
  if (value >= 151) return _MetricRisk.danger;
  if (value >= 81) return _MetricRisk.caution;
  return _MetricRisk.safe;
}

class _LifestyleDashboard extends StatelessWidget {
  final List<LifestyleMessage> messages;
  final bool compact;
  final bool serverFeaturesAvailable;

  const _LifestyleDashboard({
    required this.messages,
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
          Expanded(
            child: !serverFeaturesAvailable
                ? const _LifestyleUnsupported()
                : Column(
                    children: [
                      for (var index = 0; index < display.length; index++) ...[
                        Expanded(
                          child: _LifestyleActionCard(
                            item: display[index],
                            compact: compact,
                          ),
                        ),
                        if (index < display.length - 1)
                          SizedBox(height: compact ? 6 : 8),
                      ],
                    ],
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
    final style = _todoStyle(item);
    return Container(
      key: ValueKey('main-todo-${item.title}'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
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
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11 : 12,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: WeatherCareTheme.microTextStyle.copyWith(
                    fontSize: compact ? 8.5 : 9.5,
                    height: 1.25,
                  ),
                ),
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
  if (value.contains('비')) return '우산 챙길 날';
  if (value.contains('눈')) return '사뿐한 눈길';
  if (value.contains('흐림') || value.contains('구름')) return '구름 낀 하늘';
  return '맑은 하늘';
}

String _apparentExpression(double temperature) {
  if (temperature >= 33) return '한낮의 온실';
  if (temperature >= 28) return '따뜻한 햇살';
  if (temperature >= 20) return '가벼운 바람';
  if (temperature >= 10) return '선선한 산책길';
  if (temperature >= 0) return '차가운 공기';
  return '얼어붙은 아침';
}

IconData _weatherIcon(String? sky) {
  final value = (sky ?? '').toLowerCase();
  if (value.contains('비')) return Icons.umbrella_outlined;
  if (value.contains('눈')) return Icons.ac_unit_rounded;
  if (value.contains('흐림') || value.contains('구름')) {
    return Icons.cloud_outlined;
  }
  return Icons.wb_sunny_outlined;
}

List<_TodoItem> _todoItems(List<LifestyleMessage> messages) {
  final items = messages.take(3).map((message) {
    final presentation = _lifestylePresentation(message.type);
    return _TodoItem(
      icon: presentation.icon,
      title: message.title,
      description: message.description ?? presentation.subtitle,
      isCarryItem: _isCarryItem(message.type),
      importance: _todoImportance(message.score),
    );
  }).toList();
  for (final fallback in _fallbackTodoItems) {
    if (items.length >= 3) break;
    items.add(fallback);
  }
  return items;
}

const _fallbackTodoItems = [
  _TodoItem(
    icon: Icons.schedule_rounded,
    title: '시간대별 흐름 확인하기',
    description: '외출 전 오늘의 변화를 한 번 살펴보세요.',
  ),
  _TodoItem(
    icon: Icons.local_drink_outlined,
    title: '물 한 모금 챙기기',
    description: '하루 틈틈이 가볍게 수분을 채워요.',
  ),
  _TodoItem(
    icon: Icons.self_improvement_rounded,
    title: '여유 있게 움직이기',
    description: '오늘의 흐름에 맞춰 천천히 시작해요.',
  ),
];

class _TodoItem {
  final IconData icon;
  final String title;
  final String description;
  final bool isCarryItem;
  final _TodoImportance importance;

  const _TodoItem({
    required this.icon,
    required this.title,
    required this.description,
    this.isCarryItem = false,
    this.importance = _TodoImportance.low,
  });
}

enum _TodoImportance { low, medium, high }

_TodoImportance _todoImportance(double score) {
  if (score >= 80) return _TodoImportance.high;
  if (score >= 60) return _TodoImportance.medium;
  return _TodoImportance.low;
}

bool _isCarryItem(LifestyleMessageType type) {
  return switch (type) {
    LifestyleMessageType.rainGearUseful ||
    LifestyleMessageType.strongSunExposure ||
    LifestyleMessageType.veryHotAndHumid ||
    LifestyleMessageType.coolerThanTemperature ||
    LifestyleMessageType.outerwearUseful ||
    LifestyleMessageType.maskUseful ||
    LifestyleMessageType.hydrationImportant ||
    LifestyleMessageType.sunscreenUseful =>
      true,
    _ => false,
  };
}

_TodoStyle _todoStyle(_TodoItem item) {
  if (!item.isCarryItem) {
    return const _TodoStyle(
      background: WeatherCareTheme.surfaceMuted,
      iconBackground: Colors.white,
      accent: WeatherCareTheme.primaryDeep,
    );
  }
  return switch (item.importance) {
    _TodoImportance.high => const _TodoStyle(
        background: WeatherCareTheme.attentionSoft,
        iconBackground: Colors.white,
        accent: WeatherCareTheme.attentionDeep,
      ),
    _TodoImportance.medium => const _TodoStyle(
        background: WeatherCareTheme.primarySoft,
        iconBackground: Colors.white,
        accent: WeatherCareTheme.primaryDeep,
      ),
    _TodoImportance.low => const _TodoStyle(
        background: WeatherCareTheme.surfaceSubtle,
        iconBackground: WeatherCareTheme.primarySoft,
        accent: WeatherCareTheme.primary,
      ),
  };
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
        subtitle: '비 오기 전에 준비해요',
      ),
    LifestyleMessageType.strongSunExposure => const _LifestyleCardPresentation(
        icon: Icons.wb_sunny_outlined,
        subtitle: '한낮 햇볕을 피해주세요',
      ),
    LifestyleMessageType.laundryGood => const _LifestyleCardPresentation(
        icon: Icons.local_laundry_service_outlined,
        subtitle: '오전에 널면 좋아요',
      ),
    LifestyleMessageType.outdoorCaution => const _LifestyleCardPresentation(
        icon: Icons.directions_walk_rounded,
        subtitle: '해 질 무렵이 편안해요',
      ),
    LifestyleMessageType.ventilationGood => const _LifestyleCardPresentation(
        icon: Icons.window_outlined,
        subtitle: '오후에 짧게 열어요',
      ),
    LifestyleMessageType.veryHotAndHumid => const _LifestyleCardPresentation(
        icon: Icons.thermostat_rounded,
        subtitle: '물을 자주 마셔요',
      ),
    LifestyleMessageType.coolerThanTemperature =>
      const _LifestyleCardPresentation(
        icon: Icons.air_rounded,
        subtitle: '조금 서늘해요',
      ),
    LifestyleMessageType.outerwearUseful => const _LifestyleCardPresentation(
        icon: Icons.checkroom_rounded,
        subtitle: '가벼운 겉옷이 좋아요',
      ),
    LifestyleMessageType.maskUseful => const _LifestyleCardPresentation(
        icon: Icons.masks_outlined,
        subtitle: '외출 전 대기질을 확인해요',
      ),
    LifestyleMessageType.hydrationImportant => const _LifestyleCardPresentation(
        icon: Icons.local_drink_outlined,
        subtitle: '조금씩 자주 마셔요',
      ),
    LifestyleMessageType.sunscreenUseful => const _LifestyleCardPresentation(
        icon: Icons.spa_outlined,
        subtitle: '외출 전에 발라요',
      ),
    LifestyleMessageType.snowTravelCaution => const _LifestyleCardPresentation(
        icon: Icons.ac_unit_rounded,
        subtitle: '천천히 이동해요',
      ),
    LifestyleMessageType.largeTemperatureSwing =>
      const _LifestyleCardPresentation(
        icon: Icons.device_thermostat_outlined,
        subtitle: '겹쳐 입기 좋아요',
      ),
    LifestyleMessageType.dailyWeatherCheck => const _LifestyleCardPresentation(
        icon: Icons.schedule_rounded,
        subtitle: '시간대별 변화를 살펴봐요',
      ),
    LifestyleMessageType.dailyHydration => const _LifestyleCardPresentation(
        icon: Icons.local_drink_outlined,
        subtitle: '틈틈이 수분을 채워요',
      ),
    LifestyleMessageType.flexibleDayPlan => const _LifestyleCardPresentation(
        icon: Icons.self_improvement_rounded,
        subtitle: '여유 있게 움직여요',
      ),
  };
}

class _LifestyleCardPresentation {
  final IconData icon;
  final String subtitle;

  const _LifestyleCardPresentation({
    required this.icon,
    required this.subtitle,
  });
}
