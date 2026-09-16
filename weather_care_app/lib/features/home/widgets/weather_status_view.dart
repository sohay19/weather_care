import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

class WeatherStatusView extends StatelessWidget {
  final String viewKey;
  final bool loading;
  final bool offline;
  final String message;
  final String? title;
  final Future<void> Function() onRetry;
  final String? primaryActionLabel;
  final Future<void> Function()? onPrimaryAction;
  final Key? primaryActionKey;
  final IconData primaryActionIcon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const WeatherStatusView({
    super.key,
    required this.viewKey,
    required this.loading,
    required this.offline,
    required this.message,
    this.title,
    required this.onRetry,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.primaryActionKey,
    this.primaryActionIcon = Icons.my_location_rounded,
    this.secondaryActionLabel,
    this.onSecondaryAction,
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
                      if (loading) ...[
                        const SizedBox(height: 10),
                        Text(
                          '첫 실행은 권한 선택 시간을 제외하고 서버 재시도를 포함해 최대 약 2분 걸릴 수 있어요.',
                          key: const ValueKey('first-load-duration-guide'),
                          textAlign: TextAlign.center,
                          style: WeatherCareTheme.microTextStyle.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (!loading &&
                          primaryActionLabel != null &&
                          onPrimaryAction != null) ...[
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: primaryActionKey ??
                                const ValueKey('location-primary-action'),
                            onPressed: onPrimaryAction,
                            icon: Icon(primaryActionIcon),
                            label: Text(primaryActionLabel!),
                          ),
                        ),
                      ],
                      if (!loading &&
                          secondaryActionLabel != null &&
                          onSecondaryAction != null) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const ValueKey('manual-location-action'),
                            onPressed: onSecondaryAction,
                            icon: const Icon(Icons.map_outlined),
                            label: Text(secondaryActionLabel!),
                          ),
                        ),
                      ],
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
