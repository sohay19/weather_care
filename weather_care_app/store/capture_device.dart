// 연결 Android의 별도 촬영 패키지에서 제품 화면과 실제 서버 자료를 사용한다.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:weather_care/app.dart';
import 'package:weather_care/firebase_options.dart';
import 'package:weather_care/models/app_settings.dart';
import 'package:weather_care/services/app_settings_repository.dart';
import 'package:weather_care/services/installation_identity.dart';
import 'package:weather_care/services/permission_onboarding_store.dart';
import 'package:weather_care/services/region_catalog.dart';
import 'package:weather_care/services/theme_mode_settings.dart';

Future<void> main() async {
  if (!kDebugMode) throw StateError('스토어 촬영 전용 Debug 진입점입니다.');
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseMessaging.instance.setAutoInitEnabled(false);
  final id = await const InstallationIdentity().getOrCreate();
  final catalog = await RegionCatalog.load();
  final busan = catalog.regions.firstWhere((r) => r.code == '2629062000');
  final seoul = catalog.regions.firstWhere((r) => r.code == '1111000000');
  final siheung = catalog.regions.firstWhere((r) => r.name == '정왕1동');
  await const AppSettingsRepository().save(AppSettings.fallback(id).copyWith(
    locationMode: 'MANUAL',
    manualRegionKey: busan.key,
    savedRegionKeys: [busan.key, seoul.key, siheung.key],
    notificationRegionKeys: [busan.key, seoul.key],
    onboardingCompleted: true,
    notificationEnabled: true,
    backgroundLocationEnabled: false,
  ));
  await const PermissionOnboardingStore().confirm();
  await ThemeModeSettings.instance.load();
  await ThemeModeSettings.instance.save(ThemeMode.light);
  runApp(const WeatherCareApp());
}
