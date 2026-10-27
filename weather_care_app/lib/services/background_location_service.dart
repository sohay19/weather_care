import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'server_data_access.dart';

/// Native monitoring survives a suspended Flutter engine. No Dart timer tracks GPS.
class BackgroundLocationService extends ChangeNotifier {
  static const channelName = 'com.codesoha.weathercare/background-location';
  final MethodChannel channel;
  String status = 'disabled';
  DateTime? measuredAt;
  DateTime? syncedAt;
  bool _wanted = false;
  bool _disposed = false;
  String? _configured;
  Future<void> _queue = Future<void>.value();

  BackgroundLocationService({this.channel = const MethodChannel(channelName)});

  Future<void> synchronize(
      {required bool enabled, required ServerDataAccess access}) {
    _wanted = enabled && !access.paused;
    // Stop collection immediately, even while enrollment/network I/O is pending.
    if (!_wanted) {
      _configured = null;
      _invoke('stop');
    }
    final wanted = _wanted;
    _queue = _queue.then((_) async {
      if (_disposed || wanted != _wanted) return;
      if (!wanted) {
        if (!access.paused && access.credential != null) {
          await access.mutate((owner) => access.api.requestJson(
              'PUT', '/api/v1/installations/${owner.id}/background-location',
              headers: owner.headers, body: {'revision': null}).then((_) {}));
        }
        await refreshStatus();
        return;
      }
      await access.mutate((owner) async {
        if (!_wanted || _disposed) return;
        final key = '${access.api.baseUrl}:${owner.id}:${owner.secret}';
        if (_configured == key) {
          await _invoke('resume');
          return;
        }
        final revision = _revision();
        await access.api.requestJson(
            'PUT', '/api/v1/installations/${owner.id}/background-location',
            headers: owner.headers, body: {'revision': revision});
        if (!_wanted || _disposed || access.paused) return;
        await channel.invokeMethod<void>('configure', {
          'url':
              '${access.api.baseUrl}/api/v1/installations/${owner.id}/location',
          'authorization': owner.headers['Authorization'],
          'revision': revision,
          if (Uri.parse(access.api.baseUrl).host ==
                  'weather-test-api.codesoha.com' &&
              access.api.testAccessKey.isNotEmpty)
            'testAccessKey': access.api.testAccessKey,
        });
        _configured = key;
      });
      await refreshStatus();
    }).catchError((Object error) {
      _configured = null;
      status = error is MissingPluginException ? 'unsupported' : 'error';
      _notify();
    });
    return _queue;
  }

  Future<void> requestPermission({bool initial = false}) async {
    try {
      await channel
          .invokeMethod<void>('requestPermission', {'initial': initial});
    } catch (_) {
      /* The status below reports unsupported/unavailable platforms. */
    }
    await refreshStatus();
  }

  Future<void> refreshStatus() async {
    try {
      final data = await channel.invokeMapMethod<String, dynamic>('status');
      if (_disposed) return;
      status = data?['status'] as String? ?? 'disabled';
      if (_wanted && status == 'disabled') {
        _configured = null;
        status = 'error';
      }
      measuredAt = DateTime.tryParse(data?['measuredAt'] as String? ?? '');
      syncedAt = DateTime.tryParse(data?['syncedAt'] as String? ?? '');
    } on MissingPluginException {
      status = 'unsupported';
    } catch (_) {
      status = 'error';
    }
    _notify();
  }

  Future<void> _invoke(String method) async {
    try {
      await channel.invokeMethod<void>(method);
    } catch (_) {/* Fail closed natively. */}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    // Leaving the widget tree must not disable opted-in native monitoring.
    _disposed = true;
    super.dispose();
  }
}

String _revision() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
