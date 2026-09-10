import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

class WeatherStatusView extends StatelessWidget {
  final String viewKey;
  final bool loading;
  final bool offline;
  final String message;
  final String? title;
  final Future<void> Function() onRetry;

  const WeatherStatusView({
    super.key,
    required this.viewKey,
    required this.loading,
    required this.offline,
    required this.message,
    this.title,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: WeatherCareTheme.primary,
      onRefresh: onRetry,
      child: CustomScrollView(
        key: ValueKey(viewKey),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
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
                          offline
                              ? Icons.wifi_off_rounded
                              : Icons.cloud_off_rounded,
                          size: 42,
                          color: WeatherCareTheme.textSecondary,
                        ),
                      const SizedBox(height: 18),
                      Text(
                        title ?? (loading ? '날씨 정보를 확인하고 있어요' : '날씨 정보 미지원'),
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
                        const SizedBox(height: 14),
                        Text(
                          '화면을 아래로 당겨 다시 확인할 수 있어요.',
                          textAlign: TextAlign.center,
                          style: WeatherCareTheme.microTextStyle.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
