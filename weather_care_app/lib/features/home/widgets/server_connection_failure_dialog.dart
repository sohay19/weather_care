import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

enum ServerFailureAction {
  retryServer,
}

class ServerConnectionFailureDialog extends StatelessWidget {
  const ServerConnectionFailureDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(
          Icons.cloud_off_outlined,
          color: WeatherCareTheme.primaryDeep,
        ),
        title: const Text('운영 서버에 연결하지 못했어요'),
        content: const Text(
          '준비물 추천과 오늘의 TODO는 운영 서버에 연결해야 정확하게 '
          '제공할 수 있어요.\n\n이 앱은 기상청 API를 직접 호출하지 '
          '않으며, 운영 서버가 준비한 자료만 사용해요. '
          '잠시 후 서버 연결을 다시 시도해 주세요.',
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(
              ServerFailureAction.retryServer,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('운영 서버 다시 시도'),
          ),
        ],
      ),
    );
  }
}
