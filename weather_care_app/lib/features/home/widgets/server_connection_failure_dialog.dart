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
        title: const Text('운영 서버 날씨 자료를 받지 못했어요'),
        content: const Text(
          'Check List와 간단한 타임라인은 운영 서버가 준비한 날씨 '
          '자료가 있어야 제공할 수 있어요.\n\n서버 연결 또는 선택 지역의 '
          '자료 준비가 잠시 지연될 수 있어요. 잠시 후 다시 시도해 주세요.',
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
