import 'package:flutter/material.dart';

import '../../../models/lifestyle_message.dart';
import '../../../theme/weather_theme.dart';
import 'home_section_header.dart';

class LifestyleSection extends StatelessWidget {
  final List<LifestyleMessage> messages;

  const LifestyleSection({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionHeader(
            icon: Icons.eco_outlined,
            title: '생활 날씨',
            subtitle: '날씨를 오늘의 행동으로 바꿔봤어요',
          ),
          const SizedBox(height: 16),
          if (messages.isEmpty)
            Text(
              '오늘은 특별한 생활 메시지가 없어요',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            for (var index = 0; index < messages.length; index++) ...[
              _LifestyleTile(message: messages[index]),
              if (index < messages.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _LifestyleTile extends StatelessWidget {
  final LifestyleMessage message;

  const _LifestyleTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationFor(message.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: WeatherCareTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              presentation.icon,
              size: 22,
              color: WeatherCareTheme.primaryDeep,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message.description ?? presentation.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: WeatherCareTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

_LifestylePresentation _presentationFor(LifestyleMessageType type) {
  return switch (type) {
    LifestyleMessageType.rainGearUseful => const _LifestylePresentation(
        icon: Icons.umbrella_outlined,
        subtitle: '비가 오기 전에 우산과 이동 시간을 확인해요',
      ),
    LifestyleMessageType.strongSunExposure => const _LifestylePresentation(
        icon: Icons.wb_sunny_outlined,
        subtitle: '한낮에는 그늘을 이용해 햇볕 노출을 줄여요',
      ),
    LifestyleMessageType.veryHotAndHumid => const _LifestylePresentation(
        icon: Icons.thermostat_rounded,
        subtitle: '낮에는 무리하지 말고 물을 자주 마셔요',
      ),
    LifestyleMessageType.laundryGood => const _LifestylePresentation(
        icon: Icons.local_laundry_service_outlined,
        subtitle: '오전에 널면 보송하게 마르기 좋아요',
      ),
    LifestyleMessageType.coolerThanTemperature => const _LifestylePresentation(
        icon: Icons.air_rounded,
        subtitle: '표시 온도보다 서늘하게 느껴질 수 있어요',
      ),
    LifestyleMessageType.outerwearUseful => const _LifestylePresentation(
        icon: Icons.checkroom_rounded,
        subtitle: '가벼운 겉옷이 있으면 편안해요',
      ),
    LifestyleMessageType.maskUseful => const _LifestylePresentation(
        icon: Icons.masks_outlined,
        subtitle: '외출 전에 대기질을 확인하고 마스크를 챙겨요',
      ),
    LifestyleMessageType.hydrationImportant => const _LifestylePresentation(
        icon: Icons.local_drink_outlined,
        subtitle: '갈증이 나기 전부터 물을 조금씩 마셔요',
      ),
    LifestyleMessageType.sunscreenUseful => const _LifestylePresentation(
        icon: Icons.spa_outlined,
        subtitle: '외출 전에 선크림을 미리 발라요',
      ),
    LifestyleMessageType.snowTravelCaution => const _LifestylePresentation(
        icon: Icons.ac_unit_rounded,
        subtitle: '눈길에서는 평소보다 천천히 이동해요',
      ),
    LifestyleMessageType.largeTemperatureSwing => const _LifestylePresentation(
        icon: Icons.device_thermostat_outlined,
        subtitle: '벗기 쉬운 옷을 겹쳐 입으면 편안해요',
      ),
    LifestyleMessageType.outdoorCaution => const _LifestylePresentation(
        icon: Icons.directions_walk_rounded,
        subtitle: '야외활동은 짧게 하고 휴식을 챙겨요',
      ),
    LifestyleMessageType.ventilationGood => const _LifestylePresentation(
        icon: Icons.window_outlined,
        subtitle: '오후에는 창문을 짧게 열어도 좋아요',
      ),
    LifestyleMessageType.dailyWeatherCheck => const _LifestylePresentation(
        icon: Icons.schedule_rounded,
        subtitle: '외출 전 시간대별 변화를 살펴봐요',
      ),
    LifestyleMessageType.dailyHydration => const _LifestylePresentation(
        icon: Icons.local_drink_outlined,
        subtitle: '하루 틈틈이 가볍게 수분을 채워요',
      ),
    LifestyleMessageType.flexibleDayPlan => const _LifestylePresentation(
        icon: Icons.self_improvement_rounded,
        subtitle: '오늘의 흐름에 맞춰 여유 있게 움직여요',
      ),
  };
}

class _LifestylePresentation {
  final IconData icon;
  final String subtitle;

  const _LifestylePresentation({
    required this.icon,
    required this.subtitle,
  });
}
