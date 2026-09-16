import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import 'server_data_access.dart';

enum SettingsSaveState {
  checking,
  saving,
  localFailed,
  serverFailed,
  saved,
  localOnly
}

extension SettingsSaveStateMessage on SettingsSaveState {
  String get message => switch (this) {
        SettingsSaveState.checking => '설정 저장 상태를 확인하고 있어요.',
        SettingsSaveState.saving => '변경한 설정을 저장하고 있어요.',
        SettingsSaveState.localFailed =>
          '기기에 설정을 저장하지 못했어요.\n앱을 다시 실행하면 변경 내용이 사라질 수 있어요.\n서버 반영도 완료되지 않았어요.',
        SettingsSaveState.serverFailed =>
          '기기에는 저장했지만 서버 반영을 확인하지 못했어요.\n알림은 이전 설정으로 발송될 수 있어요.',
        SettingsSaveState.saved => '정상적으로 기기에 설정을 저장하고 서버에 반영했어요.',
        SettingsSaveState.localOnly =>
          '기기에만 설정을 저장했어요.\n서버 등록과 설정 전송은 중지된 상태예요.',
      };

  bool get canRetry =>
      this == SettingsSaveState.localFailed ||
      this == SettingsSaveState.serverFailed;
}

/// Persist in order, but only publish the result of the latest user choice.
/// Weather refresh and notification registration are separate operations.
class SettingsSaveController extends ChangeNotifier {
  final Future<void> Function(AppSettings) saveLocal;
  final Future<void> Function(AppSettings) saveServer;
  SettingsSaveState state = SettingsSaveState.checking;
  Future<void> _queue = Future<void>.value();
  int _revision = 0;
  bool _disposed = false;

  SettingsSaveController({required this.saveLocal, required this.saveServer});

  Future<void> save(AppSettings settings) {
    if (_disposed) return Future<void>.value();
    final revision = ++_revision;
    _publish(SettingsSaveState.saving, revision);
    _queue = _queue.then((_) async {
      if (_disposed) return;
      try {
        await saveLocal(settings);
      } catch (_) {
        _publish(SettingsSaveState.localFailed, revision);
        return;
      }
      try {
        await saveServer(settings);
        _publish(SettingsSaveState.saved, revision);
      } on ServerDataPaused {
        _publish(SettingsSaveState.localOnly, revision);
      } catch (_) {
        _publish(SettingsSaveState.serverFailed, revision);
      }
    });
    return _queue;
  }

  void _publish(SettingsSaveState value, int revision) {
    if (_disposed || revision != _revision) return;
    state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
