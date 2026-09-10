import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/api_client.dart';
import 'package:weather_care/services/settings_sync_service.dart';

class _Client extends ApiClient {
  Map<String, dynamic>? body;
  _Client() : super(baseUrl: '');
  @override
  Future<void> putJson(String path, Map<String, dynamic> body,
      {Map<String, String>? query}) async {
    this.body = body;
  }
}

void main() {
  test('로컬 선택 식별자를 서버에 보내지 않고 기존 격자 계약을 유지한다', () async {
    final settings = AppSettings.fallback('test').copyWith(
        locationMode: 'MANUAL',
        currentRegionId: '100_76',
        manualRegionKey: '2635055100|좌제1동|100|76');
    final client = _Client();
    await SettingsSyncService(client).save(settings);
    expect(settings.toJson()['manualRegionKey'], settings.manualRegionKey);
    expect(client.body?.containsKey('manualRegionKey'), isFalse);
    expect(client.body?['currentRegion'], '100_76');
    expect(client.body?['locationMode'], 'MANUAL');
  });
}
