import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:weather_care/services/store_update_service.dart';

PackageInfo package({String version = '1.2.0'}) => PackageInfo(
      appName: '날씨챙겨',
      packageName: 'com.codesoha.weathercare',
      version: version,
      buildNumber: '12',
    );

AppUpdateInfo playUpdate(UpdateAvailability availability) => AppUpdateInfo(
      updateAvailability: availability,
      immediateUpdateAllowed: true,
      immediateAllowedPreconditions: null,
      flexibleUpdateAllowed: true,
      flexibleAllowedPreconditions: null,
      availableVersionCode: 13,
      installStatus: InstallStatus.unknown,
      packageName: 'com.codesoha.weathercare',
      clientVersionStalenessDays: null,
      updatePriority: 0,
    );

Map<String, dynamic> listing(String version) => {
      'bundleId': 'com.codesoha.weathercare',
      'version': version,
      'minimumOsVersion': '15.6',
      'trackViewUrl': 'https://apps.apple.com/kr/app/id1234567890',
    };

StoreUpdateService iosService({
  String current = '1.2.0',
  String os = 'Version 18.0 (Build 123)',
  required Future<http.Response> Function(http.Request) respond,
}) =>
    StoreUpdateService(
      platform: TargetPlatform.iOS,
      countryCode: 'KR',
      readPackageInfo: () async => package(version: current),
      readOperatingSystemVersion: () => os,
      client: MockClient(respond),
    );

http.Response response(List<Map<String, dynamic>> results) => http.Response(
    jsonEncode({'resultCount': results.length, 'results': results}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Google Play가 업데이트 가능하다고 확인한 앱의 상세 페이지를 연다', () async {
    final service = StoreUpdateService(
      platform: TargetPlatform.android,
      readPackageInfo: () async => package(),
      readPlayUpdate: () async =>
          playUpdate(UpdateAvailability.updateAvailable),
    );
    final update = await service.checkForUpdate();
    expect(update?.storeUrl.toString(),
        'https://play.google.com/store/apps/details?id=com.codesoha.weathercare');
    expect(update?.currentVersion, '1.2.0');
    expect(update?.latestVersion, isNull);
  });

  for (final availability in [UpdateAvailability.updateNotAvailable]) {
    test('Play 상태가 $availability 이면 새 업데이트 안내를 생략한다', () async {
      final service = StoreUpdateService(
        platform: TargetPlatform.android,
        readPackageInfo: () async => package(),
        readPlayUpdate: () async => playUpdate(availability),
      );
      expect(await service.checkForUpdate(), isNull);
    });
  }

  test('Play 미설치나 개발용 APK의 조회 오류를 업데이트 불필요와 구분한다', () async {
    final service = StoreUpdateService(
      platform: TargetPlatform.android,
      readPackageInfo: () async => package(),
      readPlayUpdate: () async => throw StateError('Play unavailable'),
    );
    await expectLater(service.checkForUpdate(), throwsStateError);
  });

  test('Play 알 수 없는 상태는 확인 실패로 처리한다', () async {
    final service = StoreUpdateService(
      platform: TargetPlatform.android,
      readPackageInfo: () async => package(),
      readPlayUpdate: () async => playUpdate(UpdateAvailability.unknown),
    );
    await expectLater(service.checkForUpdate(), throwsStateError);
  });

  test('Play 업데이트 진행 중에도 완료 확인 전까지 업데이트가 필요하다', () async {
    final service = StoreUpdateService(
      platform: TargetPlatform.android,
      readPackageInfo: () async => package(),
      readPlayUpdate: () async =>
          playUpdate(UpdateAvailability.developerTriggeredUpdateInProgress),
    );
    expect(await service.checkForUpdate(), isNotNull);
  });

  test('잘못된 App Store 버전은 확인 실패로 처리한다', () async {
    await expectLater(
      iosService(respond: (_) async => response([listing('invalid')]))
          .checkForUpdate(),
      throwsStateError,
    );
  });

  test('스토어 응답이 없으면 제한 시간 오류로 차단 상태를 유지한다', () async {
    final pending = Completer<AppUpdateInfo>();
    final service = StoreUpdateService(
      platform: TargetPlatform.android,
      timeout: const Duration(milliseconds: 10),
      readPackageInfo: () async => package(),
      readPlayUpdate: () => pending.future,
    );
    await expectLater(
        service.checkForUpdate(), throwsA(isA<TimeoutException>()));
    pending.complete(playUpdate(UpdateAvailability.updateAvailable));
  });

  test('App Store는 번들 ID와 국가로 조회하고 숫자 기준으로 버전을 비교한다', () async {
    final service = iosService(respond: (request) async {
      expect(request.url.host, 'itunes.apple.com');
      expect(request.url.queryParameters,
          {'bundleId': 'com.codesoha.weathercare', 'country': 'kr'});
      return response([listing('1.10.0')]);
    });
    expect((await service.checkForUpdate())?.latestVersion, '1.10.0');
  });

  for (final version in ['1.2.0', '1.2', '1.1.9']) {
    test('App Store 버전 $version 이 설치 버전보다 높지 않으면 생략한다', () async {
      final service =
          iosService(respond: (_) async => response([listing(version)]));
      expect(await service.checkForUpdate(), isNull);
    });
  }

  test('설치 앱의 빌드 번호는 App Store 버전 비교에서 제외한다', () async {
    final service = iosService(
      current: '1.2.0+12',
      respond: (_) async => response([listing('1.2.1')]),
    );
    expect((await service.checkForUpdate())?.latestVersion, '1.2.1');
  });

  test('현재 iOS에서 설치할 수 없는 버전은 안내하지 않는다', () async {
    final service = iosService(
      os: 'Version 15.5 (Build 123)',
      respond: (_) async => response([listing('1.3.0')]),
    );
    expect(await service.checkForUpdate(), isNull);
  });

  test('스토어 미등록 앱은 확인 실패로 처리한다', () async {
    final service = iosService(respond: (_) async => response([]));
    await expectLater(service.checkForUpdate(), throwsStateError);
  });

  test('다른 번들 또는 Apple 외부 링크를 업데이트 대상으로 사용하지 않는다', () async {
    for (final item in [
      {...listing('1.3.0'), 'bundleId': 'another.app'},
      {...listing('1.3.0'), 'trackViewUrl': 'https://example.com/app'},
    ]) {
      final service = iosService(respond: (_) async => response([item]));
      await expectLater(service.checkForUpdate(), throwsStateError);
    }
  });

  test('스토어 응답 오류·잘못된 JSON·네트워크 실패는 홈을 허용하지 않는다', () async {
    for (final result in [
      http.Response('unavailable', 503),
      http.Response('{', 200)
    ]) {
      final service = iosService(respond: (_) async => result);
      await expectLater(service.checkForUpdate(), throwsA(anything));
    }
    await expectLater(
        iosService(respond: (_) async => throw StateError('offline'))
            .checkForUpdate(),
        throwsStateError);
  });

  test('데스크톱에서는 스토어 조회를 하지 않는다', () async {
    final service = StoreUpdateService(
      platform: TargetPlatform.windows,
      readPackageInfo: () async => throw StateError('must not read'),
    );
    expect(await service.checkForUpdate(), isNull);
  });
}
