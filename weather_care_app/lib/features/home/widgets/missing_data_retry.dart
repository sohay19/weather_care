import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

class MissingDataRetry extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  final bool retrying;
  final String retryKey;
  final String retryTooltip;

  const MissingDataRetry({
    super.key,
    required this.message,
    required this.onRetry,
    required this.retryKey,
    this.retrying = false,
    this.retryTooltip = '이 자료만 다시 요청',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
      decoration: BoxDecoration(
        color: WeatherCareTheme.of(context).surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: WeatherCareTheme.of(context).textSecondary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: WeatherCareTheme.of(context).microTextStyle.copyWith(
                    color: WeatherCareTheme.of(context).textSecondary,
                  ),
            ),
          ),
          if (retrying)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Tooltip(
              message: retryTooltip,
              child: IconButton(
                key: ValueKey(retryKey),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                color: WeatherCareTheme.of(context).primaryDeep,
              ),
            ),
        ],
      ),
    );
  }
}
