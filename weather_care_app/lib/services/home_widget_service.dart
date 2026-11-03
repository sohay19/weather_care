import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';

import '../models/home_widget_snapshot.dart';

class HomeWidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.codesoha.weathercare/home-widget');

  const HomeWidgetService();

  void setWatchRefreshHandler(Future<void> Function()? onRefresh) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _channel.setMethodCallHandler(onRefresh == null
        ? null
        : (call) async {
            if (call.method == 'refreshFromWatch') await onRefresh();
          });
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (!_isSupportedPlatform) return;
    try {
      await _channel.invokeMethod<void>('setThemeMode', mode.name);
    } on MissingPluginException {
      // Widget extensions are not available in unit/widget test hosts.
    } on PlatformException catch (error) {
      debugPrint('위젯 테마를 갱신하지 못했어요: ${error.code}');
    }
  }

  Future<void> publish(
    HomeWidgetSnapshot snapshot, {
    String? refreshUrl,
    String? testAccessKey,
    bool gpsEnabled = false,
    DateTime? locationMeasuredAt,
    Map<String, dynamic>? wearDetails,
  }) async {
    if (!_isSupportedPlatform) return;
    try {
      await _channel.invokeMethod<void>('save', {
        'snapshot': snapshot.encode(),
        if (wearDetails != null) 'wearDetails': wearDetails,
        if (refreshUrl != null) 'refreshUrl': refreshUrl,
        if (Uri.tryParse(refreshUrl ?? '')?.host ==
                'weather-test-api.codesoha.com' &&
            Uri.tryParse(refreshUrl ?? '')?.scheme == 'https' &&
            testAccessKey != null &&
            testAccessKey.isNotEmpty)
          'testAccessKey': testAccessKey,
        'gpsEnabled': gpsEnabled,
        if (locationMeasuredAt != null)
          'locationMeasuredAt': locationMeasuredAt.toUtc().toIso8601String(),
      });
    } on MissingPluginException {
      // Widget extensions are not available in unit/widget test hosts.
    } on PlatformException {
      // Weather rendering must remain available even if a launcher rejects an update.
    }
  }

  Future<void> clear() async {
    if (!_isSupportedPlatform) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // Widget extensions are not available in unit/widget test hosts.
    } on PlatformException {
      // A stale launcher process can disappear while the app is changing region.
    }
  }

  Future<void> clearWatchChecks({String? regionKey}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    String? locationKey;
    if (regionKey != null) {
      final parts = regionKey.split('|');
      if (parts.length != 4) return;
      locationKey = '${parts[2]}:${parts[3]}:admin:${parts[0]}';
    }
    try {
      await _channel.invokeMethod<void>('clearWatchChecks', {
        if (locationKey != null) 'locationKey': locationKey,
      });
    } on MissingPluginException {
      // 워치 연동이 없는 실행 환경에서는 삭제를 건너뛴다.
    } on PlatformException {
      // 워치 연결 상태가 휴대전화의 설정 저장을 막지 않게 한다.
    }
  }

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
