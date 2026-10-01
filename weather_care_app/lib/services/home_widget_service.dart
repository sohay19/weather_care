import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/home_widget_snapshot.dart';

class HomeWidgetService {
  static const MethodChannel _channel =
      MethodChannel('com.codesoha.weathercare/home-widget');

  const HomeWidgetService();

  Future<void> publish(
    HomeWidgetSnapshot snapshot, {
    String? refreshUrl,
    bool gpsEnabled = false,
  }) async {
    if (!_isSupportedPlatform) return;
    try {
      await _channel.invokeMethod<void>('save', {
        'snapshot': snapshot.encode(),
        if (refreshUrl != null) 'refreshUrl': refreshUrl,
        'gpsEnabled': gpsEnabled,
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

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}
