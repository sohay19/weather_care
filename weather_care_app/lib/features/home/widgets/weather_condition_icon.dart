import 'package:flutter/material.dart';

enum WeatherConditionKind {
  clear,
  partlyCloudy,
  overcast,
  drizzle,
  rain,
  shower,
  lightWintryMix,
  wintryMix,
  snowFlurry,
  snow,
  unknown,
}

WeatherConditionKind weatherConditionKind(String? condition) {
  final value = (condition ?? '').trim().toLowerCase().replaceAll(' ', '');

  if (value.contains('빗방울/눈날림')) {
    return WeatherConditionKind.lightWintryMix;
  }
  if (value.contains('비/눈') ||
      value.contains('진눈깨비') ||
      value.contains('rain/snow') ||
      value.contains('sleet')) {
    return WeatherConditionKind.wintryMix;
  }
  if (value.contains('소나기') || value.contains('shower')) {
    return WeatherConditionKind.shower;
  }
  if (value.contains('빗방울') ||
      value.contains('이슬비') ||
      value.contains('가랑비') ||
      value.contains('약한비') ||
      value.contains('drizzle')) {
    return WeatherConditionKind.drizzle;
  }
  if (value.contains('비') || value.contains('rain')) {
    return WeatherConditionKind.rain;
  }
  if (value.contains('눈날림') || value.contains('flurry')) {
    return WeatherConditionKind.snowFlurry;
  }
  if (value.contains('눈') || value.contains('snow')) {
    return WeatherConditionKind.snow;
  }
  if (value.contains('구름많음') || value.contains('partlycloudy')) {
    return WeatherConditionKind.partlyCloudy;
  }
  if (value.contains('흐림') ||
      value.contains('overcast') ||
      value.contains('cloudy') ||
      value.contains('구름')) {
    return WeatherConditionKind.overcast;
  }
  if (value.contains('맑음') ||
      value.contains('clear') ||
      value.contains('sunny')) {
    return WeatherConditionKind.clear;
  }
  return WeatherConditionKind.unknown;
}

class WeatherConditionIcon extends StatelessWidget {
  final String? condition;
  final double size;
  final Color color;

  const WeatherConditionIcon({
    super.key,
    required this.condition,
    this.size = 24,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final kind = weatherConditionKind(condition);
    return Semantics(
      label: '날씨 ${condition?.trim().isNotEmpty == true ? condition : '정보 없음'}',
      image: true,
      child: ExcludeSemantics(
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox.square(
            key: ValueKey('weather-condition-${kind.name}'),
            dimension: size,
            child: switch (kind) {
              WeatherConditionKind.clear => Icon(
                  Icons.wb_sunny_outlined,
                  size: size,
                  color: color,
                ),
              WeatherConditionKind.partlyCloudy =>
                _PartlyCloudyWeatherGlyph(size: size, color: color),
              WeatherConditionKind.overcast =>
                _OvercastWeatherGlyph(size: size, color: color),
              WeatherConditionKind.drizzle =>
                _RainWeatherGlyph(size: size, color: color, dropCount: 1),
              WeatherConditionKind.rain =>
                _RainWeatherGlyph(size: size, color: color, dropCount: 2),
              WeatherConditionKind.shower =>
                _RainWeatherGlyph(size: size, color: color, dropCount: 3),
              WeatherConditionKind.lightWintryMix =>
                _WintryMixWeatherGlyph(size: size, color: color, light: true),
              WeatherConditionKind.wintryMix =>
                _WintryMixWeatherGlyph(size: size, color: color),
              WeatherConditionKind.snowFlurry =>
                _SnowWeatherGlyph(size: size, color: color, flurry: true),
              WeatherConditionKind.snow =>
                _SnowWeatherGlyph(size: size, color: color),
              WeatherConditionKind.unknown => Icon(
                  Icons.help_outline_rounded,
                  size: size,
                  color: color,
                ),
            },
          ),
        ),
      ),
    );
  }
}

class _PartlyCloudyWeatherGlyph extends StatelessWidget {
  final double size;
  final Color color;

  const _PartlyCloudyWeatherGlyph({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(size * 0.18, -size * 0.16),
          child: Icon(
            Icons.wb_sunny_outlined,
            size: size * 0.58,
            color: color.withValues(alpha: 0.82),
          ),
        ),
        Transform.translate(
          offset: Offset(-size * 0.08, size * 0.12),
          child: Icon(Icons.cloud_rounded, size: size * 0.78, color: color),
        ),
      ],
    );
  }
}

class _OvercastWeatherGlyph extends StatelessWidget {
  final double size;
  final Color color;

  const _OvercastWeatherGlyph({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(size * 0.16, -size * 0.1),
          child: Icon(
            Icons.cloud_outlined,
            size: size * 0.62,
            color: color.withValues(alpha: 0.58),
          ),
        ),
        Transform.translate(
          offset: Offset(-size * 0.09, size * 0.11),
          child: Icon(Icons.cloud_rounded, size: size * 0.82, color: color),
        ),
      ],
    );
  }
}

class _RainWeatherGlyph extends StatelessWidget {
  final double size;
  final Color color;
  final int dropCount;

  const _RainWeatherGlyph({
    required this.size,
    required this.color,
    required this.dropCount,
  });

  @override
  Widget build(BuildContext context) {
    final dropSize = size * (dropCount == 3 ? 0.22 : 0.24);
    final spacing = size * 0.05;
    final dropsWidth = dropCount * dropSize + (dropCount - 1) * spacing;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(Icons.cloud_rounded, size: size * 0.78, color: color),
        Positioned(
          bottom: 0,
          left: (size - dropsWidth) / 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < dropCount; index++) ...[
                Icon(Icons.water_drop_rounded, size: dropSize, color: color),
                if (index < dropCount - 1) SizedBox(width: spacing),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WintryMixWeatherGlyph extends StatelessWidget {
  final double size;
  final Color color;
  final bool light;

  const _WintryMixWeatherGlyph({
    required this.size,
    required this.color,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(
          light ? Icons.cloud_outlined : Icons.cloud_rounded,
          size: size * 0.76,
          color: color,
        ),
        Positioned(
          left: size * 0.22,
          bottom: 0,
          child: Icon(
            Icons.water_drop_rounded,
            size: size * (light ? 0.19 : 0.24),
            color: color,
          ),
        ),
        Positioned(
          right: size * 0.16,
          bottom: 0,
          child: Icon(
            Icons.ac_unit_rounded,
            size: size * (light ? 0.24 : 0.3),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SnowWeatherGlyph extends StatelessWidget {
  final double size;
  final Color color;
  final bool flurry;

  const _SnowWeatherGlyph({
    required this.size,
    required this.color,
    this.flurry = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(
          flurry ? Icons.cloud_outlined : Icons.cloud_rounded,
          size: size * 0.76,
          color: color,
        ),
        Positioned(
          bottom: 0,
          child: Icon(
            Icons.ac_unit_rounded,
            size: size * (flurry ? 0.26 : 0.34),
            color: color,
          ),
        ),
      ],
    );
  }
}
