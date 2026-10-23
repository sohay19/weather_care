import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class StoreUpdate {
  final String currentVersion;
  final String? latestVersion;
  final String storeName;
  final Uri storeUrl;

  const StoreUpdate({
    required this.currentVersion,
    this.latestVersion,
    required this.storeName,
    required this.storeUrl,
  });
}

class StoreUpdateService {
  final TargetPlatform? platform;
  final Future<PackageInfo> Function()? readPackageInfo;
  final Future<AppUpdateInfo> Function()? readPlayUpdate;
  final String Function()? readOperatingSystemVersion;
  final http.Client? client;
  final String? countryCode;
  final Duration timeout;

  const StoreUpdateService({
    this.platform,
    this.readPackageInfo,
    this.readPlayUpdate,
    this.readOperatingSystemVersion,
    this.client,
    this.countryCode,
    this.timeout = const Duration(seconds: 5),
  });

  Future<StoreUpdate?> checkForUpdate() async {
    if (kIsWeb) return null;
    final target = platform ?? defaultTargetPlatform;
    if (target != TargetPlatform.android && target != TargetPlatform.iOS) {
      return null;
    }
    try {
      return await _check(target).timeout(timeout);
    } catch (_) {
      // 스토어 미등록·Play 미설치·오프라인이어도 앱 시작은 계속한다.
      return null;
    }
  }

  Future<StoreUpdate?> _check(TargetPlatform target) async {
    final package = await (readPackageInfo ?? PackageInfo.fromPlatform)();
    if (target == TargetPlatform.android) {
      final update = await (readPlayUpdate ?? InAppUpdate.checkForUpdate)();
      if (update.updateAvailability != UpdateAvailability.updateAvailable ||
          update.packageName != package.packageName) {
        return null;
      }
      return StoreUpdate(
        currentVersion: package.version,
        storeName: 'Google Play',
        storeUrl: Uri.https('play.google.com', '/store/apps/details',
            {'id': package.packageName}),
      );
    }

    final connection = client ?? http.Client();
    try {
      final country =
          countryCode ?? PlatformDispatcher.instance.locale.countryCode;
      final response = await connection
          .get(Uri.https('itunes.apple.com', '/lookup', {
            'bundleId': package.packageName,
            'country': country == null || country.isEmpty
                ? 'kr'
                : country.toLowerCase(),
          }))
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      for (final item in (data['results'] as List)) {
        if (item['bundleId'] != package.packageName) continue;
        final version = item['version'] as String;
        if (!_isNewer(version, package.version)) return null;
        final minimumOs = item['minimumOsVersion'] as String?;
        if (minimumOs != null) {
          final os = (readOperatingSystemVersion ??
              () => Platform.operatingSystemVersion)();
          final installedOs = RegExp(r'\d+(?:\.\d+)*').firstMatch(os)?.group(0);
          if (installedOs == null || _isNewer(minimumOs, installedOs)) {
            return null;
          }
        }
        final url = Uri.tryParse(item['trackViewUrl'] as String);
        if (url == null ||
            url.scheme != 'https' ||
            url.host != 'apps.apple.com') {
          return null;
        }
        return StoreUpdate(
          currentVersion: package.version,
          latestVersion: version,
          storeName: 'App Store',
          storeUrl: url,
        );
      }
      return null;
    } finally {
      if (client == null) connection.close();
    }
  }

  static bool _isNewer(String latest, String current) {
    List<int>? parse(String value) {
      final version = value.trim().split('+').first;
      if (!RegExp(r'^\d+(?:\.\d+)*$').hasMatch(version)) return null;
      return version.split('.').map(int.parse).toList();
    }

    final left = parse(latest);
    final right = parse(current);
    if (left == null || right == null) return false;
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final difference = (index < left.length ? left[index] : 0) -
          (index < right.length ? right[index] : 0);
      if (difference != 0) return difference > 0;
    }
    return false;
  }
}
