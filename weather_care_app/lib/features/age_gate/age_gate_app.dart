import 'package:flutter/material.dart';

import '../../services/age_eligibility.dart';
import '../../services/age_eligibility_store.dart';
import '../../services/minimum_age_policy.dart';
import '../../theme/weather_theme.dart';

class AgeGateApp extends StatelessWidget {
  final AgeEligibilityController controller;
  final bool startingServices;
  final String? serviceError;
  final VoidCallback? onRetryServices;

  const AgeGateApp({
    super.key,
    required this.controller,
    this.startingServices = false,
    this.serviceError,
    this.onRetryServices,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '날씨챙겨',
      debugShowCheckedModeBanner: false,
      theme: WeatherCareTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => _AgeGateContent(
              controller: controller,
              startingServices: startingServices,
              serviceError: serviceError,
              onRetryServices: onRetryServices,
            ),
          ),
        ),
      ),
    );
  }
}

class _AgeGateContent extends StatelessWidget {
  final AgeEligibilityController controller;
  final bool startingServices;
  final String? serviceError;
  final VoidCallback? onRetryServices;

  const _AgeGateContent({
    required this.controller,
    required this.startingServices,
    required this.serviceError,
    required this.onRetryServices,
  });

  @override
  Widget build(BuildContext context) {
    final checking = !controller.ready || controller.busy;
    final starting = controller.sdkAccessAllowed && startingServices;
    final under14 = controller.ready &&
        controller.eligibility == AgeEligibility.under14 &&
        !controller.busy;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: WeatherCareTheme.primarySoft,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.cloud_outlined,
                  color: WeatherCareTheme.primaryDeep,
                  size: 34,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                under14 ? '날씨챙겨를 이용할 수 없어요' : '날씨챙겨를 이용할 분의\n연령대를 알려주세요.',
                key: const ValueKey('age-gate-title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: 14),
              Text(
                under14
                    ? '날씨챙겨는 만 $minimumServiceAge세 이상만 이용할 수 있어요.'
                    : '날씨챙겨는 만 $minimumServiceAge세 이상만 이용할 수 있어요. 생년월일은 입력하지 않아요.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: WeatherCareTheme.textSecondary,
                      height: 1.55,
                    ),
              ),
              const SizedBox(height: 24),
              if (checking || starting) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                Text(
                  starting ? '날씨 기능을 준비하고 있어요.' : '연령대 설정을 확인하고 있어요.',
                  textAlign: TextAlign.center,
                ),
              ] else if (under14) ...[
                _NoticeCard(
                  icon: Icons.block_outlined,
                  text:
                      '만 $minimumServiceAge세 미만은 날씨·위치·알림·이용 통계·광고를 포함한 앱 서비스를 이용할 수 없어요. 온라인 서비스와 기기 권한 요청은 시작하지 않았어요.',
                ),
                const SizedBox(height: 18),
                OutlinedButton(
                  key: const ValueKey('age-choose-again'),
                  onPressed: controller.chooseAgain,
                  child: const Text('연령대를 다시 선택할게요'),
                ),
              ] else if (controller.sdkAccessAllowed &&
                  serviceError != null) ...[
                _NoticeCard(
                  icon: Icons.cloud_off_outlined,
                  text: serviceError!,
                ),
                const SizedBox(height: 18),
                FilledButton(
                  key: const ValueKey('age-services-retry'),
                  onPressed: onRetryServices,
                  child: const Text('다시 시도'),
                ),
              ] else ...[
                _AgeChoiceButton(
                  key: const ValueKey('age-at-least-14'),
                  icon: Icons.person_outline_rounded,
                  label: '만 14세 이상이에요',
                  onPressed: () => controller.select(AgeEligibility.atLeast14),
                ),
                const SizedBox(height: 12),
                _AgeChoiceButton(
                  key: const ValueKey('age-under-14'),
                  icon: Icons.child_care_outlined,
                  label: '만 14세 미만이에요',
                  onPressed: () => controller.select(AgeEligibility.under14),
                ),
              ],
              if (controller.error != null) ...[
                const SizedBox(height: 18),
                Text(
                  controller.error!,
                  key: const ValueKey('age-gate-error'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: WeatherCareTheme.danger,
                        height: 1.45,
                      ),
                ),
              ],
              const SizedBox(height: 28),
              Text(
                '만 $minimumServiceAge세 이상 확인 전에는 온라인 서비스, 이용 통계, 광고와 기기 권한 요청을 시작하지 않아요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WeatherCareTheme.textSecondary,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgeChoiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _AgeChoiceButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(58),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NoticeCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: WeatherCareTheme.surfaceDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: WeatherCareTheme.primaryDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
