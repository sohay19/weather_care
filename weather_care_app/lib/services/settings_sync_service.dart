import '../models/app_settings.dart';
import 'api_client.dart';

class SettingsSyncService {
  final ApiClient client;

  const SettingsSyncService(this.client);

  Future<void> save(AppSettings settings) async {
    // This endpoint is strict: installation/location belong to the separate
    // installation registration API; onboarding/catalog identity stays local.
    final payload = {
      'notificationEnabled': settings.notificationEnabled,
      'notificationTime': settings.notificationTime,
      'commuteToWorkStart': settings.commuteToWorkStart,
      'commuteToWorkEnd': settings.commuteToWorkEnd,
      'commuteFromWorkStart': settings.commuteFromWorkStart,
      'commuteFromWorkEnd': settings.commuteFromWorkEnd,
      'umbrellaEnabled': settings.umbrellaEnabled,
      'parasolEnabled': settings.parasolEnabled,
      'outerwearEnabled': settings.outerwearEnabled,
      'maskEnabled': settings.maskEnabled,
      'waterEnabled': settings.waterEnabled,
      'sunscreenEnabled': settings.sunscreenEnabled,
      'drynessEnabled': settings.drynessEnabled,
      'heavyRainEnabled': settings.heavyRainEnabled,
      'heavySnowEnabled': settings.heavySnowEnabled,
      'heatwaveEnabled': settings.heatwaveEnabled,
      'coldWaveEnabled': settings.coldWaveEnabled,
      'pipeFreezeEnabled': settings.pipeFreezeEnabled,
      'showerAndLightRainEnabled': settings.showerAndLightRainEnabled,
      'lightningEnabled': settings.lightningEnabled,
      'todayVisibilityEnabled': settings.todayVisibilityEnabled,
      'todayOzoneEnabled': settings.todayOzoneEnabled,
      'todayWindEnabled': settings.todayWindEnabled,
      'todayHumidityEnabled': settings.todayHumidityEnabled,
      'todayApparentTemperatureEnabled':
          settings.todayApparentTemperatureEnabled,
      'snowPreparationEnabled': settings.snowPreparationEnabled,
      'uvPreparationEnabled': settings.uvPreparationEnabled,
      'pollenEnabled': settings.pollenEnabled,
      'blackIceEnabled': settings.blackIceEnabled,
      'carryNotificationEnabled': settings.carryNotificationEnabled,
      'todayNotificationEnabled': settings.todayNotificationEnabled,
      'weatherNotificationEnabled': settings.weatherNotificationEnabled,
      'dailyWeatherEnabled': settings.dailyWeatherEnabled,
    };
    await client.putJson(
      '/api/v1/notification-settings/${settings.installationId}',
      payload,
    );
    if (settings.notificationRegionKeys != null) {
      final available = {
        'GPS',
        ...settings.savedRegionKeys,
        if (settings.legacyNotificationRegionAvailable ||
            settings.enabledNotificationRegionKeys.contains('LEGACY'))
          'LEGACY'
      };
      await client.putJson(
        '/api/v1/installations/${settings.installationId}/notification-regions',
        {
          'regions': [
            for (final key in available)
              {
                'key': key,
                'enabled': settings.enabledNotificationRegionKeys.contains(key)
              }
          ]
        },
      );
    }
  }
}
