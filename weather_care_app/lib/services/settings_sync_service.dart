import '../models/app_settings.dart';
import 'api_client.dart';

class SettingsSyncService {
  final ApiClient client;

  const SettingsSyncService(this.client);

  Future<void> save(AppSettings settings) async {
    await client.putJson(
      '/api/v1/notification-settings/${settings.installationId}',
      settings.toJson(),
    );
  }
}
