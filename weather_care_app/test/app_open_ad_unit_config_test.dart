import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/app_open_ad_unit_config.dart';

void main() {
  test('Debug는 Google 공식 앱 오프닝 테스트 단위를 사용한다', () {
    const config = AppOpenAdUnitConfig();

    expect(
      config.resolve(
        platform: TargetPlatform.android,
        releaseMode: false,
        web: false,
      ),
      AppOpenAdUnitConfig.androidTestId,
    );
    expect(
      config.resolve(
        platform: TargetPlatform.iOS,
        releaseMode: false,
        web: false,
      ),
      AppOpenAdUnitConfig.iosTestId,
    );
  });

  test('Release는 유효한 앱 오프닝 운영 ID만 사용한다', () {
    const invalid = AppOpenAdUnitConfig(
      androidReleaseId: 'ca-app-pub-invalid',
    );
    expect(
      invalid.resolve(
        platform: TargetPlatform.android,
        releaseMode: true,
        web: false,
      ),
      isNull,
    );

    const enabled = AppOpenAdUnitConfig(
      androidReleaseId: 'ca-app-pub-1234567890123456/1234567890',
      iosReleaseId: 'ca-app-pub-1234567890123456/0987654321',
    );
    expect(
      enabled.resolve(
        platform: TargetPlatform.android,
        releaseMode: true,
        web: false,
      ),
      'ca-app-pub-1234567890123456/1234567890',
    );
    expect(
      enabled.resolve(
        platform: TargetPlatform.iOS,
        releaseMode: true,
        web: false,
      ),
      'ca-app-pub-1234567890123456/0987654321',
    );
  });
}
