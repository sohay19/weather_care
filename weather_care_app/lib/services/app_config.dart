import 'dart:convert';
import 'dart:developer';

import 'package:flutter/services.dart';

const _defaultServerUrl = 'https://weather-api.codesoha.com';
const _configAssetPath = 'config/kma.config.json';

class AppConfig {
  final String serverUrl;

  const AppConfig({
    required this.serverUrl,
  });

  static Future<AppConfig> load({AssetBundle? bundle}) async {
    const definedServerUrl = String.fromEnvironment('SERVER_URL');
    var serverUrl =
        definedServerUrl.isEmpty ? _defaultServerUrl : definedServerUrl;

    try {
      final raw = await (bundle ?? rootBundle).loadString(_configAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('KMA config must be a JSON object');
      }

      final assetServerUrl = decoded['SERVER_URL']?.toString().trim() ?? '';
      if (definedServerUrl.isEmpty && assetServerUrl.isNotEmpty) {
        serverUrl = assetServerUrl;
      }
    } catch (error) {
      log('KMA config asset unavailable (${error.runtimeType})');
    }

    return AppConfig(
      serverUrl: serverUrl,
    );
  }
}
