import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

class PermissionOnboardingDialog extends StatelessWidget {
  const PermissionOnboardingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final backgroundPermissionGuide = switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        'Android 11 이상은 위치를 ‘항상 허용’하고 ‘정확한 위치 사용’을 켜주세요. 약 1km 영역을 벗어나면 이동을 감지하며 갱신이 늦어질 수 있어요.',
      TargetPlatform.iOS =>
        'iOS는 ‘앱을 사용하는 동안 허용’ 뒤 추가 요청에서 ‘항상 허용’이 필요해요. 표시 시점은 운영체제가 정해요.',
      _ => '백그라운드 위치 갱신에는 위치 권한의 ‘항상 허용’이 필요해요.',
    };
    return AlertDialog(
      key: const ValueKey('permission-onboarding-dialog'),
      title: const Text('\'날씨 챙겨\'에서 필요한 권한이에요'),
      content: SingleChildScrollView(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PermissionPurpose(
            icon: Icons.location_on_outlined,
            title: '구역 선택',
            description: '현재 지역의 날씨와 생활 정보를 확인하고 위젯에 표시할 때 사용해요.',
          ),
          const SizedBox(height: 14),
          const _PermissionPurpose(
            icon: Icons.notifications_none_rounded,
            title: '알림',
            description: '사용자가 켠 날씨·준비물 알림을 기기에 표시할 때 사용해요.',
          ),
          const SizedBox(height: 18),
          const _PermissionPurpose(
            icon: Icons.location_searching_rounded,
            title: '백그라운드 위치 갱신 · 선택',
            description:
                '앱을 사용하지 않을 때도 이동을 감지해 현재 위치·날씨 알림 지역·홈 위젯 날씨를 갱신해요. 최신 위치를 서버에 보내며 이동 경로는 저장하지 않아요.',
          ),
          const SizedBox(height: 14),
          Text(
            '계속을 누르면 알림 → 사용 중 위치 → 백그라운드 위치 순서로 요청해요.\n$backgroundPermissionGuide\nGPS 사용으로 배터리를 더 사용할 수 있어요.\nGPS 모드·전체 알림·서버 사용이 켜진 동안 동작하며 기능을 끄거나 지역을 직접 선택하면 감시를 중지해요.\n권한을 거부해도 직접 선택한 지역의 날씨를 볼 수 있어요.',
            style: TextStyle(
              color: WeatherCareTheme.of(context).textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      )),
      actions: [
        TextButton(
          key: const ValueKey('permission-onboarding-foreground-only'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('백그라운드 제외'),
        ),
        FilledButton(
          key: const ValueKey('permission-onboarding-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('계속'),
        ),
      ],
    );
  }
}

class _PermissionPurpose extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _PermissionPurpose({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: WeatherCareTheme.of(context).primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              size: 20, color: WeatherCareTheme.of(context).primaryDeep),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
