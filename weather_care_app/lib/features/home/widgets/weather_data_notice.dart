import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';
import '../weather_data_phase.dart';

class WeatherDataNotice extends StatelessWidget {
  final WeatherDataPhase phase;
  final String subject;

  const WeatherDataNotice({
    super.key,
    required this.phase,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) {
    if (phase == WeatherDataPhase.ready) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Row(
        children: [
          if (phase == WeatherDataPhase.loading)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            const Icon(Icons.wifi_off_rounded, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              phase == WeatherDataPhase.loading
                  ? '$subject 자료를 불러오고 있어요.'
                  : '$subject 자료를 서버에서 불러오지 못했어요. 이전 자료가 표시될 수 있어요.',
            ),
          ),
        ],
      ),
    );
  }
}
