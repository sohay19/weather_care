import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/settings_sync_service.dart';

class _Client extends ApiClient {
  Map<String, dynamic>? body;
  String? path;
  bool fail = false;
  final calls = <({String path, Map<String, dynamic> body})>[];
  _Client() : super(baseUrl: '');
  @override
  Future<void> putJson(String path, Map<String, dynamic> body,
      {Map<String, String>? query}) async {
    this.body = body;
    this.path = path;
    calls.add((path: path, body: body));
    if (fail) throw StateError('HTTP 400');
  }
}

void main() {
  test('새 앱 구역 구독은 기존 설정 필드와 분리하고 OFF 지역도 명시한다', () async {
    final client = _Client();
    await SettingsSyncService(client).save(AppSettings.fallback('test')
        .copyWith(
            savedRegionKeys: ['region1', 'region2'],
            notificationRegionKeys: ['GPS', 'region2']));
    expect(client.calls, hasLength(2));
    expect(client.calls.first.path, '/api/v1/notification-settings/test');
    expect(client.calls.first.body.containsKey('regions'), isFalse);
    expect(client.calls.last.path,
        '/api/v1/installations/test/notification-regions');
    expect(client.calls.last.body, {
      'regions': [
        {'key': 'GPS', 'enabled': true},
        {'key': 'region1', 'enabled': false},
        {'key': 'region2', 'enabled': true}
      ]
    });
  });

  test('알림 설정 API에는 출퇴근 시간을 포함한 허용 필드만 전송한다', () async {
    final settings = AppSettings.fallback('test').copyWith(
        locationMode: 'MANUAL',
        currentRegionId: '100_76',
        manualRegionKey: '2635055100|좌제1동|100|76');
    final client = _Client();
    await SettingsSyncService(client).save(settings);
    expect(settings.toJson()['manualRegionKey'], settings.manualRegionKey);
    expect(client.path, '/api/v1/notification-settings/test');
    expect(client.body, {
      'notificationEnabled': true,
      'notificationTime': '07:00',
      'commuteToWorkStart': '07:00',
      'commuteToWorkEnd': '10:00',
      'commuteFromWorkStart': '17:00',
      'commuteFromWorkEnd': '20:00',
      'umbrellaEnabled': true,
      'parasolEnabled': true,
      'outerwearEnabled': true,
      'maskEnabled': true,
      'waterEnabled': true,
      'sunscreenEnabled': true,
      'drynessEnabled': true,
      'snowPreparationEnabled': true,
      'uvPreparationEnabled': true,
      'pollenEnabled': true,
      'blackIceEnabled': true,
      'todayVisibilityEnabled': true,
      'todayOzoneEnabled': true,
      'todayWindEnabled': true,
      'todayHumidityEnabled': true,
      'todayApparentTemperatureEnabled': true,
      'heavyRainEnabled': true,
      'heavySnowEnabled': true,
      'heatwaveEnabled': true,
      'coldWaveEnabled': true,
      'pipeFreezeEnabled': true,
      'showerAndLightRainEnabled': true,
      'lightningEnabled': true,
      'carryNotificationEnabled': true,
      'todayNotificationEnabled': true,
      'weatherNotificationEnabled': true,
      'dailyWeatherEnabled': true,
    });
  });
  test('끄기와 시간 변경을 누락하지 않고 서버 실패를 호출자에게 전달한다', () async {
    final settings = AppSettings.fallback('test').copyWith(
        notificationEnabled: false,
        notificationTime: '22:35',
        commuteToWorkStart: '23:00',
        commuteToWorkEnd: '01:00',
        commuteFromWorkStart: '08:30',
        commuteFromWorkEnd: '09:30',
        umbrellaEnabled: false,
        parasolEnabled: false,
        outerwearEnabled: false,
        maskEnabled: false,
        waterEnabled: false,
        sunscreenEnabled: false,
        drynessEnabled: false,
        snowPreparationEnabled: false,
        uvPreparationEnabled: false,
        pollenEnabled: false,
        blackIceEnabled: false,
        weatherNotificationEnabled: false,
        todayVisibilityEnabled: false,
        todayOzoneEnabled: false,
        todayWindEnabled: false,
        todayHumidityEnabled: false,
        todayApparentTemperatureEnabled: false,
        heavyRainEnabled: false,
        heavySnowEnabled: false,
        pipeFreezeEnabled: false,
        heatwaveEnabled: false,
        coldWaveEnabled: false,
        showerAndLightRainEnabled: false,
        lightningEnabled: false,
        dailyWeatherEnabled: false);
    final client = _Client()..fail = true;
    await expectLater(
        SettingsSyncService(client).save(settings), throwsStateError);
    expect(client.body!['notificationTime'], '22:35');
    expect(client.body!['commuteToWorkStart'], '23:00');
    expect(client.body!['commuteToWorkEnd'], '01:00');
    expect(client.body!['commuteFromWorkStart'], '08:30');
    expect(client.body!['commuteFromWorkEnd'], '09:30');
    expect(
        client.body!.entries
            .where((entry) => entry.value is bool)
            .every((entry) => entry.value == false),
        isTrue);
  });
}
