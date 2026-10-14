import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/app_settings_repository.dart';
import 'package:weather_care/services/installation_identity.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('installation identity remains stable', () async {
    const identity = InstallationIdentity();
    expect(await identity.getExisting(), isNull);
    final first = await identity.getOrCreate();
    final second = await identity.getOrCreate();

    expect(first, startsWith('wc_'));
    expect(second, first);
    expect(await identity.getExisting(), first);
  });

  test('app settings survive a repository reload', () async {
    const repository = AppSettingsRepository();
    final changed = AppSettings.fallback('device-1').copyWith(
      notificationEnabled: false,
      notificationTime: '06:35',
      umbrellaEnabled: false,
      heavyRainEnabled: false,
      savedRegionKeys: ['부산|100|76', '제주|80|40'],
    );

    await repository.save(changed);
    final loaded = await repository.load('device-1');

    expect(loaded.notificationEnabled, false);
    expect(loaded.notificationTime, '06:35');
    expect(loaded.umbrellaEnabled, false);
    expect(loaded.heavyRainEnabled, false);
    expect(loaded.savedRegionKeys, ['부산|100|76', '제주|80|40']);
  });

  test('이전 단일 선택 구역을 저장 구역 목록으로 옮긴다', () {
    final loaded = AppSettings.fromJson({
      'locationMode': 'MANUAL',
      'manualRegionKey': '이전 구역',
      'currentRegion': '60_121',
    }, 'device-1');
    expect(loaded.savedRegionKeys, ['이전 구역']);
  });
}
