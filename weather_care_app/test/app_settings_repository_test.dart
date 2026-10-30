import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/app_settings_repository.dart';
import 'package:weather_care/services/installation_identity.dart';

void main() {
  test('구 앱의 눈·자외선·마스크 선택을 항목 설정으로 이관하고 개별 선택을 보존한다', () {
    final legacy = AppSettings.fromJson({
      'heavySnowEnabled': false,
      'parasolEnabled': false,
      'sunscreenEnabled': false,
      'maskEnabled': false,
    }, 'test');
    expect(legacy.snowPreparationEnabled, isFalse);
    expect(legacy.uvPreparationEnabled, isFalse);
    expect(legacy.pollenEnabled, isFalse);
    expect(legacy.blackIceEnabled, isTrue);
    final changed = legacy.copyWith(
        snowPreparationEnabled: true,
        uvPreparationEnabled: true,
        pollenEnabled: true,
        blackIceEnabled: false);
    final restored = AppSettings.fromJson(changed.toJson(), 'test');
    expect(restored.toJson(), changed.toJson());
    expect(restored.maskEnabled, isFalse);
  });
  test('Today 알림은 구 저장값에서 기본 ON이며 개별 OFF와 다른 설정을 재로딩해 보존한다', () async {
    SharedPreferences.setMockInitialValues({});
    const repository = AppSettingsRepository();
    final legacy = AppSettings.fromJson({'notificationTime': '08:15'}, 'test');
    expect(legacy.todayVisibilityEnabled, isTrue);
    expect(legacy.todayOzoneEnabled, isTrue);
    expect(legacy.todayWindEnabled, isTrue);
    expect(legacy.todayHumidityEnabled, isTrue);
    expect(legacy.todayApparentTemperatureEnabled, isTrue);
    final changed = legacy.copyWith(
        todayVisibilityEnabled: false,
        todayOzoneEnabled: false,
        todayWindEnabled: false,
        todayHumidityEnabled: false,
        todayApparentTemperatureEnabled: false);
    await repository.save(changed);
    final restored = await repository.load('test');
    expect(restored.toJson(), changed.toJson());
    expect(
        restored.copyWith(notificationTime: '09:30').todayWindEnabled, isFalse);
  });
  test('구역 구독과 발송 당시 위치 이름을 기기 저장에서 보존한다', () async {
    SharedPreferences.setMockInitialValues({});
    const repository = AppSettingsRepository();
    final settings = AppSettings.fallback('test').copyWith(
        notificationRegionKeys: ['GPS', 'manual'],
        manualRegionName: '서울 구로구 구로3동',
        legacyNotificationRegionAvailable: true);
    await repository.save(settings);
    final restored = await repository.load('test');
    expect(restored.notificationRegionKeys, ['GPS', 'manual']);
    expect(restored.manualRegionName, '서울 구로구 구로3동');
    expect(restored.legacyNotificationRegionAvailable, isTrue);
  });
  test('구역 키가 없던 과거 수동 설정도 이전 지역만 유지하고 OFF 후 다시 선택할 수 있다', () {
    final old = AppSettings.fromJson(
        {'locationMode': 'MANUAL', 'currentRegion': '98_76'}, 'test');
    expect(old.enabledNotificationRegionKeys, ['LEGACY']);
    final disabled = old.copyWith(notificationRegionKeys: []);
    final restored = AppSettings.fromJson(disabled.toJson(), 'test');
    expect(restored.enabledNotificationRegionKeys, isEmpty);
    expect(restored.legacyNotificationRegionAvailable, isTrue);
  });

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
      commuteToWorkStart: '23:00',
      commuteToWorkEnd: '01:30',
      commuteFromWorkStart: '10:00',
      commuteFromWorkEnd: '11:00',
      umbrellaEnabled: false,
      heavyRainEnabled: false,
      pipeFreezeEnabled: true,
      savedRegionKeys: ['부산|100|76', '제주|80|40'],
    );

    await repository.save(changed);
    final loaded = await repository.load('device-1');

    expect(loaded.notificationEnabled, false);
    expect(loaded.notificationTime, '06:35');
    expect(loaded.commuteToWorkStart, '23:00');
    expect(loaded.commuteToWorkEnd, '01:30');
    expect(loaded.commuteFromWorkStart, '10:00');
    expect(loaded.commuteFromWorkEnd, '11:00');
    expect(loaded.umbrellaEnabled, false);
    expect(loaded.heavyRainEnabled, false);
    expect(loaded.pipeFreezeEnabled, true);
    expect(loaded.savedRegionKeys, ['부산|100|76', '제주|80|40']);
  });

  test('이전 단일 선택 구역을 저장 구역 목록으로 옮긴다', () {
    final loaded = AppSettings.fromJson({
      'locationMode': 'MANUAL',
      'manualRegionKey': '이전 구역',
      'currentRegion': '60_121',
    }, 'device-1');
    expect(loaded.savedRegionKeys, ['이전 구역']);
    expect(loaded.pipeFreezeEnabled, false);
    expect(loaded.commuteToWorkStart, '07:00');
    expect(loaded.commuteToWorkEnd, '10:00');
    expect(loaded.commuteFromWorkStart, '17:00');
    expect(loaded.commuteFromWorkEnd, '20:00');
  });
}
