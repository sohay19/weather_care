import 'package:flutter/material.dart';

import '../../../theme/weather_theme.dart';

enum ServerFailureAction {
  retryServer,
  dismiss,
}

class ServerConnectionFailureDialog extends StatelessWidget {
  final bool refreshFailure;
  final bool partialFailure;

  const ServerConnectionFailureDialog({
    super.key,
    this.refreshFailure = false,
    this.partialFailure = false,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: refreshFailure,
      child: AlertDialog(
        icon: const Icon(
          Icons.cloud_off_outlined,
          color: WeatherCareTheme.primaryDeep,
        ),
        title: Text(
          refreshFailure
              ? partialFailure
                  ? '날씨 자료를 모두 새로고침하지 못했어요'
                  : '날씨 자료를 새로고침하지 못했어요'
              : '운영 서버 날씨 자료를 받지 못했어요',
        ),
        content: Text(
          refreshFailure
              ? '${partialFailure ? '일부 자료만 새로 받았어요. ' : ''}'
                  '서버 연결 또는 선택 지역의 자료 준비가 잠시 '
                  '지연될 수 있어요.\n\n현재 화면의 기존 자료는 '
                  '유지되며 잠시 후 다시 시도할 수 있어요.'
              : 'Check List와 간단한 타임라인은 운영 서버가 준비한 '
                  '날씨 자료가 있어야 제공할 수 있어요.\n\n서버 연결 또는 '
                  '선택 지역의 자료 준비가 잠시 지연될 수 있어요. '
                  '잠시 후 다시 시도해 주세요.',
        ),
        actions: [
          if (refreshFailure)
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                ServerFailureAction.dismiss,
              ),
              child: const Text('확인'),
            ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(
              ServerFailureAction.retryServer,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(refreshFailure ? '다시 시도' : '운영 서버 다시 시도'),
          ),
        ],
      ),
    );
  }
}
