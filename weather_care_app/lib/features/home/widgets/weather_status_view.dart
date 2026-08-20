import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

class WeatherStatusView extends StatelessWidget {
  final String viewKey;
  final bool loading;
  final bool offline;
  final String message;
  final Future<void> Function() onRetry;

  const WeatherStatusView({
    super.key,
    required this.viewKey,
    required this.loading,
    required this.offline,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey(viewKey),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: WeatherCareTheme.surfaceDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: WeatherCareTheme.primary,
                  ),
                )
              else
                Icon(
                  offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
                  size: 42,
                  color: WeatherCareTheme.textSecondary,
                ),
              const SizedBox(height: 18),
              Text(
                loading ? '날씨 정보를 확인하고 있어요' : '날씨 정보 미지원',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: WeatherCareTheme.textSecondary,
                    ),
              ),
              if (!loading) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('다시 시도'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
