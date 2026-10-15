import 'dart:convert';
import 'dart:developer';

import 'package:flutter/services.dart';

const _defaultServerUrl = 'https://weather-api.codesoha.com';
const _configAssetPath = 'config/kma.config.json';

class AppConfig {
  final String serverUrl;
  final String testAccessKey;

  const AppConfig({
    required this.serverUrl,
    this.testAccessKey = '',
  });

  static Future<AppConfig> load({AssetBundle? bundle}) async {
    const definedServerUrl = String.fromEnvironment('SERVER_URL');
    const definedTestAccessKey = String.fromEnvironment('TEST_ACCESS_KEY');
    var serverUrl =
        definedServerUrl.isEmpty ? _defaultServerUrl : definedServerUrl;
    var testAccessKey = definedTestAccessKey;

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
      if (definedTestAccessKey.isEmpty) {
        testAccessKey = decoded['TEST_ACCESS_KEY']?.toString().trim() ?? '';
      }
    } catch (error) {
      log('KMA config asset unavailable (${error.runtimeType})');
    }

    return AppConfig(
      serverUrl: serverUrl,
      testAccessKey: testAccessKey,
    );
  }
}
