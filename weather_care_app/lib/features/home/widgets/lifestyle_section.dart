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
            subtitle: '추천 행동 뒤에 영향과 공식 정보를 확인해요',
          ),
          const SizedBox(height: 16),
          if (messages.isEmpty)
            Text(
              '현재 예보에서 안내할 생활행동이 없어요.',
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
    final actions = message.parts
        .where((part) => part.role == WeatherMessageRole.appSuggestion)
        .map((part) => part.text)
        .toList();
    final action = actions.isEmpty ? null : actions.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: WeatherCareTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconFor(message.type),
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
                  action ?? message.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                for (final part in message.parts.skip(1)) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${part.role.label} · ${part.text}',
                    style: Theme.of(context).textTheme.bodySmall,
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

IconData _iconFor(LifestyleMessageType type) => switch (type) {
      LifestyleMessageType.rainGearUseful => Icons.umbrella_outlined,
      LifestyleMessageType.strongSunExposure ||
      LifestyleMessageType.sunscreenUseful =>
        Icons.wb_sunny_outlined,
      LifestyleMessageType.veryHotAndHumid ||
      LifestyleMessageType.hydrationImportant =>
        Icons.thermostat_rounded,
      LifestyleMessageType.outerwearUseful => Icons.checkroom_rounded,
      LifestyleMessageType.maskUseful => Icons.masks_outlined,
      LifestyleMessageType.snowTravelCaution => Icons.ac_unit_rounded,
      LifestyleMessageType.laundryPickupDue =>
        Icons.local_laundry_service_outlined,
      LifestyleMessageType.petWalkWindow => Icons.pets_outlined,
      LifestyleMessageType.nightWeatherCheck => Icons.bedtime_outlined,
      LifestyleMessageType.windowCloseSoon => Icons.window_outlined,
      LifestyleMessageType.wetRoadCaution => Icons.directions_car_outlined,
      LifestyleMessageType.blackIceCaution => Icons.warning_amber_rounded,
      LifestyleMessageType.commuteRouteCaution => Icons.alt_route_rounded,
      LifestyleMessageType.outdoorCaution ||
      LifestyleMessageType.coolerThanTemperature =>
        Icons.air_rounded,
      LifestyleMessageType.rainBreakWindow ||
      LifestyleMessageType.bestOutingWindow =>
        Icons.schedule_rounded,
      LifestyleMessageType.largeTemperatureSwing ||
      LifestyleMessageType.rapidTemperatureDrop =>
        Icons.device_thermostat_outlined,
      LifestyleMessageType.unknown => Icons.info_outline_rounded,
    };
