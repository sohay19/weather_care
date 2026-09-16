import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

class PullToRefreshDataHint extends StatelessWidget {
  static const message = '화면을 아래로 당기면 데이터를 다시 요청할 수 있어요.';

  const PullToRefreshDataHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('pull-to-refresh-data-hint'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: WeatherCareTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.refresh_rounded,
              size: 17,
              color: WeatherCareTheme.primaryDeep,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              PullToRefreshDataHint.message,
              style: TextStyle(
                color: WeatherCareTheme.textSecondary,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
