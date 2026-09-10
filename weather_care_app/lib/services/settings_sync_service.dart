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
      'umbrellaEnabled': settings.umbrellaEnabled,
      'parasolEnabled': settings.parasolEnabled,
      'outerwearEnabled': settings.outerwearEnabled,
      'maskEnabled': settings.maskEnabled,
      'waterEnabled': settings.waterEnabled,
      'sunscreenEnabled': settings.sunscreenEnabled,
      'heavyRainEnabled': settings.heavyRainEnabled,
      'heavySnowEnabled': settings.heavySnowEnabled,
      'heatwaveEnabled': settings.heatwaveEnabled,
      'coldWaveEnabled': settings.coldWaveEnabled,
      'showerAndLightRainEnabled': settings.showerAndLightRainEnabled,
      'dailyWeatherEnabled': settings.dailyWeatherEnabled,
    };
    await client.putJson(
      '/api/v1/notification-settings/${settings.installationId}',
      payload,
    );
  }
}
