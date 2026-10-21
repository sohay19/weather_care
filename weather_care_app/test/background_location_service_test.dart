import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/background_location_service.dart';
import 'package:weather_care/services/server_data_access.dart';

class _Api extends ApiClient {
  final bodies = <Map<String, dynamic>>[];
  Completer<void>? pending;
  _Api({super.baseUrl = 'https://example.invalid', super.testAccessKey});
  @override
  Future<Map<String, dynamic>> requestJson(String method, String path,
      {Map<String, String>? query,
      Map<String, String>? headers,
      Map<String, dynamic>? body}) async {
    expect(headers?['Authorization'], 'Bearer ${'a' * 64}');
    bodies.add(body!);
    await pending?.future;
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(BackgroundLocationService.channelName);
  final calls = <MethodCall>[];
  late BackgroundLocationService service;
  late ServerDataAccess access;
  late _Api api;
  var nativeStatus = 'disabled';

  Future<void> load(
      {_Api? client, ServerDataMode mode = ServerDataMode.active}) async {
    api = client ?? _Api();
    access = ServerDataAccess(
        api: api,
        legacyInstallationId: 'local-id',
        readStore: () async => jsonEncode({
              'mode': mode.name,
              'serverId': 'wc_synthetic_123456789012345',
              'secret': 'a' * 64
            }),
        writeStore: (_) async {});
    await access.load();
  }

  setUp(() async {
    calls.clear();
    nativeStatus = 'disabled';
    service = BackgroundLocationService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'configure') nativeStatus = 'active';
      if (call.method == 'stop') nativeStatus = 'disabled';
      if (call.method == 'status') return {'status': nativeStatus};
      return null;
    });
    await load();
  });
  tearDown(() {
    service.dispose();
    access.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('기본값은 꺼짐이며 동의는 로컬 설정에 저장된다', () {
    final defaults = AppSettings.fallback('local');
    expect(defaults.backgroundLocationEnabled, false);
    final optedIn = defaults.copyWith(backgroundLocationEnabled: true);
    expect(
        AppSettings.fromJson(optedIn.toJson(), 'local')
            .backgroundLocationEnabled,
        true);
    expect(AppSettings.fromJson({}, 'local').backgroundLocationEnabled, false);
  });
  test('서버가 세션을 허용한 뒤 네이티브에 구성하고 권한을 자동 요청하지 않는다', () async {
    api.pending = Completer();
    final sync = service.synchronize(enabled: true, access: access);
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c.method == 'configure'), isEmpty);
    api.pending!.complete();
    await sync;
    final config =
        calls.singleWhere((c) => c.method == 'configure').arguments as Map;
    expect(config['url'],
        'https://example.invalid/api/v1/installations/wc_synthetic_123456789012345/location');
    expect(config['revision'], api.bodies.single['revision']);
    expect(calls.where((c) => c.method == 'requestPermission'), isEmpty);
    expect(service.status, 'active');
  });
  test('반복 동기화는 감시 세션을 바꾸지 않고 재개한다', () async {
    await service.synchronize(enabled: true, access: access);
    await service.synchronize(enabled: true, access: access);
    expect(api.bodies.length, 1);
    expect(calls.where((c) => c.method == 'configure').length, 1);
    expect(calls.any((c) => c.method == 'resume'), true);
  });
  test('세션 생성 중 끄면 즉시 감시를 중지하고 뒤늦은 구성을 막는다', () async {
    api.pending = Completer();
    final start = service.synchronize(enabled: true, access: access);
    await Future<void>.delayed(Duration.zero);
    final stop = service.synchronize(enabled: false, access: access);
    await Future<void>.delayed(Duration.zero);
    expect(calls.any((c) => c.method == 'stop'), true);
    api.pending!.complete();
    await start;
    await stop;
    expect(calls.where((c) => c.method == 'configure'), isEmpty);
    expect(api.bodies.last, {'revision': null});
  });
  test('서버 데이터 중지 상태에서는 감시를 끄고 전송하지 않는다', () async {
    access.dispose();
    await load(mode: ServerDataMode.deleted);
    await service.synchronize(enabled: true, access: access);
    expect(calls.any((c) => c.method == 'stop'), true);
    expect(api.bodies, isEmpty);
  });
  test('테스트 서버 키는 해당 호스트에만 전달한다', () async {
    access.dispose();
    await load(client: _Api(testAccessKey: 'synthetic'));
    await service.synchronize(enabled: true, access: access);
    expect(
        (calls.singleWhere((c) => c.method == 'configure').arguments as Map)
            .containsKey('testAccessKey'),
        false);
    calls.clear();
    access.dispose();
    await load(
        client: _Api(
            baseUrl: 'https://weather-test-api.codesoha.com',
            testAccessKey: 'synthetic'));
    await service.synchronize(enabled: true, access: access);
    expect(
        (calls.singleWhere((c) => c.method == 'configure').arguments
            as Map)['testAccessKey'],
        'synthetic');
  });
  test('명시적인 권한 동작만 시스템 설정을 연다', () async {
    await service.requestPermission();
    expect(calls.singleWhere((c) => c.method == 'requestPermission').arguments,
        {'initial': false});
    calls.clear();
    await service.requestPermission(initial: true);
    expect(calls.singleWhere((c) => c.method == 'requestPermission').arguments,
        {'initial': true});
  });
}
