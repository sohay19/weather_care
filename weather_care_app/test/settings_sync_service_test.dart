import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/settings_sync_service.dart';

class _Client extends ApiClient {
  Map<String, dynamic>? body;
  String? path;
  bool fail = false;
  _Client() : super(baseUrl: '');
  @override
  Future<void> putJson(String path, Map<String, dynamic> body,
      {Map<String, String>? query}) async {
    this.body = body;
    this.path = path;
    if (fail) throw StateError('HTTP 400');
  }
}

void main() {
  test('알림 설정 API에는 허용된 알림 필드 14개만 전송한다', () async {
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
      'umbrellaEnabled': true,
      'parasolEnabled': true,
      'outerwearEnabled': true,
      'maskEnabled': true,
      'waterEnabled': true,
      'sunscreenEnabled': true,
      'heavyRainEnabled': true,
      'heavySnowEnabled': true,
      'heatwaveEnabled': true,
      'coldWaveEnabled': true,
      'showerAndLightRainEnabled': true,
      'dailyWeatherEnabled': true,
    });
  });
  test('끄기와 시간 변경을 누락하지 않고 서버 실패를 호출자에게 전달한다', () async {
    final settings = AppSettings.fallback('test').copyWith(
        notificationEnabled: false,
        notificationTime: '22:35',
        umbrellaEnabled: false,
        parasolEnabled: false,
        outerwearEnabled: false,
        maskEnabled: false,
        waterEnabled: false,
        sunscreenEnabled: false,
        heavyRainEnabled: false,
        heavySnowEnabled: false,
        heatwaveEnabled: false,
        coldWaveEnabled: false,
        showerAndLightRainEnabled: false,
        dailyWeatherEnabled: false);
    final client = _Client()..fail = true;
    await expectLater(
        SettingsSyncService(client).save(settings), throwsStateError);
    expect(client.body!['notificationTime'], '22:35');
    expect(
        client.body!.entries
            .where((entry) => entry.key != 'notificationTime')
            .every((entry) => entry.value == false),
        isTrue);
  });
}
