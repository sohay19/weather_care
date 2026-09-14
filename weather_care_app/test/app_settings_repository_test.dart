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
    );

    await repository.save(changed);
    final loaded = await repository.load('device-1');

    expect(loaded.notificationEnabled, false);
    expect(loaded.notificationTime, '06:35');
    expect(loaded.umbrellaEnabled, false);
    expect(loaded.heavyRainEnabled, false);
  });
}
