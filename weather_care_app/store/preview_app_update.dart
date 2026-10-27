// 별도 applicationId로 빌드하는 강제 업데이트 화면 확인용 진입점.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:weather_care/features/update/app_update_gate.dart';
import 'package:weather_care/services/store_update_service.dart';

void main() {
  if (kReleaseMode) throw StateError('업데이트 예시는 디버그 빌드에서만 실행할 수 있어요.');
  runApp(const AppUpdateGate(
    service: _PreviewUpdates(),
    child: SizedBox(),
  ));
}

class _PreviewUpdates extends StoreUpdateService {
  const _PreviewUpdates();

  @override
  Future<StoreUpdate?> checkForUpdate() async => StoreUpdate(
        currentVersion: '1.1.1',
        storeName: 'Google Play',
        storeUrl: Uri.https('play.google.com', '/store/apps/details',
            {'id': 'com.codesoha.weathercare'}),
      );
}
