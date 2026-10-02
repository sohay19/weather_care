import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

class PermissionOnboardingDialog extends StatelessWidget {
  const PermissionOnboardingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('permission-onboarding-dialog'),
      title: const Text('\'날씨 챙겨\'에서 필요한 권한이에요'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PermissionPurpose(
            icon: Icons.location_on_outlined,
            title: '지역 선택',
            description: '현재 지역의 날씨와 생활 정보를 확인하고 위젯에 표시할 때 사용해요.',
          ),
          SizedBox(height: 14),
          _PermissionPurpose(
            icon: Icons.notifications_none_rounded,
            title: '알림',
            description: '사용자가 켠 날씨·준비물 알림을 기기에 표시할 때 사용해요.',
          ),
          SizedBox(height: 18),
          Text(
            '계속을 누르면 운영체제 권한 창이 차례대로 표시돼요.\niOS 위젯의 위치 사용은 위젯을 추가할 때 별도로 물을 수 있어요.\n권한을 허용하지 않아도 Setting에서 지역을 직접 선택할 수 있어요.',
            style: TextStyle(
              color: WeatherCareTheme.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
      actions: [
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
            color: WeatherCareTheme.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: WeatherCareTheme.primaryDeep),
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
