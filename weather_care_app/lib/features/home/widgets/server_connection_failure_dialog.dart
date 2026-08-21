import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

enum ServerFailureAction {
  retryServer,
  useDirectForecast,
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
          '제공할 수 있어요.\n\n맞춤 안내를 위해 운영 서버 연결을 먼저 '
          '다시 시도해 주세요. 급한 경우에는 앱에서 기상청 단기예보만 '
          '확인할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              ServerFailureAction.useDirectForecast,
            ),
            child: const Text('단기예보만 보기'),
          ),
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
