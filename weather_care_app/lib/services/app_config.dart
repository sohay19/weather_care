import 'dart:convert';
import 'dart:developer';

import 'package:flutter/services.dart';

const _defaultServerUrl = 'https://weather-care-server.sy40222.workers.dev';
const _configAssetPath = 'config/kma.config.json';

class AppConfig {
  final String serverUrl;
  final String kmaServiceKey;

  const AppConfig({
    required this.serverUrl,
    required this.kmaServiceKey,
  });

  static Future<AppConfig> load({AssetBundle? bundle}) async {
    var serverUrl = const String.fromEnvironment(
      'SERVER_URL',
      defaultValue: _defaultServerUrl,
    );
    var kmaServiceKey = const String.fromEnvironment('KMA_SERVICE_KEY');

    try {
      final raw = await (bundle ?? rootBundle).loadString(_configAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('KMA config must be a JSON object');
      }

      final assetServerUrl = decoded['SERVER_URL']?.toString().trim() ?? '';
      final assetServiceKey =
          decoded['KMA_SERVICE_KEY']?.toString().trim() ?? '';
      if (assetServerUrl.isNotEmpty) serverUrl = assetServerUrl;
      if (assetServiceKey.isNotEmpty) kmaServiceKey = assetServiceKey;
    } catch (error) {
      log('KMA config asset unavailable (${error.runtimeType})');
    }

    return AppConfig(
      serverUrl: serverUrl,
      kmaServiceKey: kmaServiceKey,
    );
  }
}
