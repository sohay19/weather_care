import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/settings_save_controller.dart';

void main() {
  final first = AppSettings.fallback('device');
  final latest = first.copyWith(notificationEnabled: false);
  late List<AppSettings> local;
  late List<AppSettings> server;
  late SettingsSaveController controller;
  bool localFails = false;
  bool serverFails = false;
  Completer<void>? pending;
  setUp(() {
    local = [];
    server = [];
    localFails = serverFails = false;
    pending = null;
    controller = SettingsSaveController(saveLocal: (settings) async {
      local.add(settings);
      if (localFails) throw StateError('disk');
    }, saveServer: (settings) async {
      server.add(settings);
      final fails = serverFails;
      await pending?.future;
      if (fails) throw StateError('offline');
    });
  });
  tearDown(() => controller.dispose());

  test('기기와 서버 저장이 완료된 경우에만 성공으로 안내한다', () async {
    expect(controller.state, SettingsSaveState.checking);
    final saving = controller.save(first);
    expect(controller.state, SettingsSaveState.saving);
    await saving;
    expect(local, [first]);
    expect(server, [first]);
    expect(controller.state, SettingsSaveState.saved);
  });
  test('기기 저장 실패는 서버 저장 성공으로 오인하지 않고 재시도한다', () async {
    localFails = true;
    await controller.save(first);
    expect(server, isEmpty);
    expect(controller.state, SettingsSaveState.localFailed);
    localFails = false;
    await controller.save(latest);
    expect(server, [latest]);
    expect(controller.state, SettingsSaveState.saved);
  });
  test('서버 실패는 기기 저장을 보존하고 최신 설정으로 재시도한다', () async {
    serverFails = true;
    await controller.save(first);
    expect(local, [first]);
    expect(controller.state, SettingsSaveState.serverFailed);
    serverFails = false;
    await controller.save(latest);
    expect(server, [first, latest]);
    expect(controller.state, SettingsSaveState.saved);
  });
  test('연속 변경은 직렬화하고 이전 성공으로 최신 저장 중 표시를 덮지 않는다', () async {
    pending = Completer<void>();
    final firstSave = controller.save(first);
    await Future<void>.delayed(Duration.zero);
    final latestSave = controller.save(latest);
    expect(server, [first]);
    final states = <SettingsSaveState>[];
    controller.addListener(() => states.add(controller.state));
    serverFails = true;
    final held = pending!;
    pending = null;
    held.complete();
    await Future.wait([firstSave, latestSave]);
    expect(server, [first, latest]);
    expect(local, [first, latest]);
    expect(states, [SettingsSaveState.serverFailed]);
  });
  test('이전 실패가 다음 저장을 막지 않는다', () async {
    serverFails = true;
    pending = Completer<void>();
    final firstSave = controller.save(first);
    await Future<void>.delayed(Duration.zero);
    final latestSave = controller.save(latest);
    serverFails = false;
    final held = pending!;
    pending = null;
    held.complete();
    await Future.wait([firstSave, latestSave]);
    expect(controller.state, SettingsSaveState.saved);
    expect(server.last, latest);
  });
  test('상태 문구는 로컬 실패·서버 실패·성공을 구분한다', () {
    expect(SettingsSaveState.localFailed.message, contains('사라질 수'));
    expect(SettingsSaveState.serverFailed.message, contains('이전 설정'));
    expect(SettingsSaveState.saved.canRetry, false);
    expect(SettingsSaveState.saving.canRetry, false);
    expect(SettingsSaveState.serverFailed.canRetry, true);
  });
}
