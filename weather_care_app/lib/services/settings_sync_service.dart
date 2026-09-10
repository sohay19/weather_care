import '../models/app_settings.dart';
import 'api_client.dart';

class SettingsSyncService {
  final ApiClient client;

  const SettingsSyncService(this.client);

  Future<void> save(AppSettings settings) async {
    // Selection identity belongs to this app's catalog, not the server API.
    final payload = settings.toJson()..remove('manualRegionKey');
    await client.putJson(
      '/api/v1/notification-settings/${settings.installationId}',
      payload,
    );
  }
}
