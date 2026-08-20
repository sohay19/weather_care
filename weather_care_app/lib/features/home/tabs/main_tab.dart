import 'package:flutter/material.dart';

import '../../../models/lifestyle_message.dart';
import '../../../models/weather.dart';
import '../../../theme/weather_theme.dart';
import '../widgets/tab_page_header.dart';

class MainTab extends StatelessWidget {
  final TodayWeatherResponse today;
  final String dateLabel;
  final String mood;
  final bool refreshing;
  final bool usingSampleData;
  final VoidCallback onRefresh;

  const MainTab({
    super.key,
    required this.today,
    required this.dateLabel,
    required this.mood,
    required this.refreshing,
    required this.usingSampleData,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: const ValueKey('main-tab'),
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, compact ? 8 : 12, 16, 12),
          child: Column(
            children: [
              TabPageHeader(
                eyebrow: dateLabel,
                title: '안녕하세요, ${today.region.name}',
                subtitle: '오늘의 핵심만 한 화면에 정리했어요',
                icon: Icons.wb_cloudy_outlined,
                onRefresh: onRefresh,
              ),
              SizedBox(height: compact ? 8 : 12),
              Expanded(
                flex: compact ? 10 : 11,
                child: _TopWeatherCard(
                  today: today,
                  mood: mood,
                  compact: compact,
                  refreshing: refreshing,
                  usingSampleData: usingSampleData,
                ),
              ),
              SizedBox(height: compact ? 8 : 12),
              Expanded(
                flex: compact ? 9 : 10,
                child: _LifestyleDashboard(
                  messages: today.lifestyleMessages,
                  compact: compact,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopWeatherCard extends StatelessWidget {
  final TodayWeatherResponse today;
  final String mood;
  final bool compact;
  final bool refreshing;
  final bool usingSampleData;

  const _TopWeatherCard({
    required this.today,
    required this.mood,
    required this.compact,
    required this.refreshing,
    required this.usingSampleData,
  });

  @override
  Widget build(BuildContext context) {
    final current = today.current;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: WeatherCareTheme.mood(mood),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SourceBadge(
                refreshing: refreshing,
                usingSampleData: usingSampleData,
              ),
              const Spacer(),
              Icon(
                _weatherIcon(current.sky),
                color: WeatherCareTheme.primaryDeep,
                size: compact ? 25 : 29,
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 14),
          Text(
            today.brief,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: WeatherCareTheme.textPrimary,
              fontSize: compact ? 23 : 27,
              height: 1.22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '${current.temperature.toStringAsFixed(1)}°',
                      style: TextStyle(
                        fontSize: compact ? 28 : 33,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          current.sky ?? '맑음',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: WeatherCareTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '체감 ${current.apparentTemperature.toStringAsFixed(1)}°',
                  style: const TextStyle(
                    color: WeatherCareTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 13),
          Container(
            padding: EdgeInsets.symmetric(vertical: compact ? 8 : 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                _TopMetric(
                  icon: Icons.water_drop_outlined,
                  label: '습도',
                  value: current.humidity == null
                      ? '--'
                      : '${current.humidity!.toStringAsFixed(0)}%',
                ),
                _TopMetric(
                  icon: Icons.air_rounded,
                  label: '바람',
                  value: current.windSpeed == null
                      ? '--'
                      : '${current.windSpeed!.toStringAsFixed(1)}m/s',
                ),
                _TopMetric(
                  icon: Icons.wb_sunny_outlined,
                  label: '자외선',
                  value: current.uvIndex?.toStringAsFixed(0) ?? '--',
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

  const _TopMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: WeatherCareTheme.primaryDeep),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: WeatherCareTheme.textSecondary,
                    fontSize: 9,
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

class _SourceBadge extends StatelessWidget {
  final bool refreshing;
  final bool usingSampleData;

  const _SourceBadge({
    required this.refreshing,
    required this.usingSampleData,
  });

  @override
  Widget build(BuildContext context) {
    final label = refreshing
        ? '서버 확인 중'
        : usingSampleData
            ? '샘플 데이터'
            : '실시간 서버';
    final accent =
        usingSampleData ? const Color(0xFFB56A32) : const Color(0xFF3C8C66);
    final background =
        usingSampleData ? const Color(0xFFFFF0E3) : const Color(0xFFE9F7EF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (refreshing)
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accent,
              ),
            )
          else
            Icon(
              usingSampleData
                  ? Icons.science_outlined
                  : Icons.cloud_done_outlined,
              size: 13,
              color: accent,
            ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LifestyleDashboard extends StatelessWidget {
  final List<LifestyleMessage> messages;
  final bool compact;

  const _LifestyleDashboard({required this.messages, required this.compact});

  @override
  Widget build(BuildContext context) {
    final display = messages.isEmpty
        ? _fallbackLifestyleMessages
        : messages.take(3).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: WeatherCareTheme.surfaceDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 36 : 40,
                height: compact ? 36 : 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.eco_outlined,
                  color: Color(0xFF4D9B7B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '생활 날씨',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (!compact)
                      Text(
                        '날씨를 오늘의 행동으로 바꿨어요',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const Text(
                'TODAY',
                style: TextStyle(
                  color: WeatherCareTheme.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          Expanded(
            child: Row(
              children: [
                for (var index = 0; index < display.length; index++) ...[
                  Expanded(
                    child: _LifestyleActionCard(
                      message: display[index],
                      compact: compact,
                    ),
                  ),
                  if (index < display.length - 1)
                    SizedBox(width: compact ? 6 : 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LifestyleActionCard extends StatelessWidget {
  final LifestyleMessage message;
  final bool compact;

  const _LifestyleActionCard({required this.message, required this.compact});

  @override
  Widget build(BuildContext context) {
    final presentation = _lifestylePresentation(message.type);
    return Container(
      height: double.infinity,
      padding: EdgeInsets.all(compact ? 9 : 11),
      decoration: BoxDecoration(
        color: presentation.background,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 30 : 34,
            height: compact ? 30 : 34,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              presentation.icon,
              color: presentation.accent,
              size: compact ? 16 : 18,
            ),
          ),
          const Spacer(),
          Text(
            message.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 4),
            Text(
              message.description ?? presentation.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: WeatherCareTheme.textSecondary,
                fontSize: 9,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
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

_LifestyleCardPresentation _lifestylePresentation(
  LifestyleMessageType type,
) {
  return switch (type) {
    LifestyleMessageType.rainGearUseful => const _LifestyleCardPresentation(
        icon: Icons.umbrella_outlined,
        accent: Color(0xFF4E8FD8),
        background: Color(0xFFEDF5FD),
        subtitle: '비 오기 전에 준비해요',
      ),
    LifestyleMessageType.strongSunExposure => const _LifestyleCardPresentation(
        icon: Icons.wb_sunny_outlined,
        accent: Color(0xFFE1A12A),
        background: Color(0xFFFFF6E3),
        subtitle: '한낮 햇볕을 피해주세요',
      ),
    LifestyleMessageType.laundryGood => const _LifestyleCardPresentation(
        icon: Icons.local_laundry_service_outlined,
        accent: Color(0xFF4E8FD8),
        background: Color(0xFFEDF5FD),
        subtitle: '오전에 널면 좋아요',
      ),
    LifestyleMessageType.outdoorCaution => const _LifestyleCardPresentation(
        icon: Icons.directions_walk_rounded,
        accent: Color(0xFFD47C55),
        background: Color(0xFFFFF1E9),
        subtitle: '해 질 무렵이 편안해요',
      ),
    LifestyleMessageType.ventilationGood => const _LifestyleCardPresentation(
        icon: Icons.window_outlined,
        accent: Color(0xFF4D9B7B),
        background: Color(0xFFEAF7F1),
        subtitle: '오후에 짧게 열어요',
      ),
    LifestyleMessageType.veryHotAndHumid => const _LifestyleCardPresentation(
        icon: Icons.thermostat_rounded,
        accent: Color(0xFFE98B65),
        background: Color(0xFFFFF2EB),
        subtitle: '물을 자주 마셔요',
      ),
    LifestyleMessageType.coolerThanTemperature =>
      const _LifestyleCardPresentation(
        icon: Icons.air_rounded,
        accent: Color(0xFF668EB7),
        background: Color(0xFFEEF4F8),
        subtitle: '조금 서늘해요',
      ),
    LifestyleMessageType.outerwearUseful => const _LifestyleCardPresentation(
        icon: Icons.checkroom_rounded,
        accent: Color(0xFF8B78C6),
        background: Color(0xFFF3F0FA),
        subtitle: '가벼운 겉옷이 좋아요',
      ),
    LifestyleMessageType.maskUseful => const _LifestyleCardPresentation(
        icon: Icons.masks_outlined,
        accent: Color(0xFF708398),
        background: Color(0xFFF0F3F6),
        subtitle: '외출 전 대기질을 확인해요',
      ),
    LifestyleMessageType.hydrationImportant => const _LifestyleCardPresentation(
        icon: Icons.local_drink_outlined,
        accent: Color(0xFF36A4BC),
        background: Color(0xFFEAF7FA),
        subtitle: '조금씩 자주 마셔요',
      ),
    LifestyleMessageType.sunscreenUseful => const _LifestyleCardPresentation(
        icon: Icons.spa_outlined,
        accent: Color(0xFFE98B65),
        background: Color(0xFFFFF2EB),
        subtitle: '외출 전에 발라요',
      ),
    LifestyleMessageType.snowTravelCaution => const _LifestyleCardPresentation(
        icon: Icons.ac_unit_rounded,
        accent: Color(0xFF5FA9C7),
        background: Color(0xFFEDF7FA),
        subtitle: '천천히 이동해요',
      ),
    LifestyleMessageType.largeTemperatureSwing =>
      const _LifestyleCardPresentation(
        icon: Icons.device_thermostat_outlined,
        accent: Color(0xFF8B78C6),
        background: Color(0xFFF3F0FA),
        subtitle: '겹쳐 입기 좋아요',
      ),
  };
}

class _LifestyleCardPresentation {
  final IconData icon;
  final Color accent;
  final Color background;
  final String subtitle;

  const _LifestyleCardPresentation({
    required this.icon,
    required this.accent,
    required this.background,
    required this.subtitle,
  });
}

final _fallbackLifestyleMessages = [
  LifestyleMessage(
    type: LifestyleMessageType.laundryGood,
    title: '빨래는 오전에',
  ),
  LifestyleMessage(
    type: LifestyleMessageType.outdoorCaution,
    title: '산책은 저녁에',
  ),
  LifestyleMessage(
    type: LifestyleMessageType.ventilationGood,
    title: '환기는 오후에',
  ),
];
