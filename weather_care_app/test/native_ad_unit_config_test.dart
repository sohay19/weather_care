import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/native_ad_unit_config.dart';

void main() {
  test('Debug는 항상 Google 공식 네이티브 테스트 단위를 사용한다', () {
    const config = NativeAdUnitConfig(
      androidWeekReleaseId: 'ca-app-pub-1234567890123456/1234567890',
      iosWeekReleaseId: 'ca-app-pub-1234567890123456/0987654321',
    );

    expect(
      config.resolve(
        platform: TargetPlatform.android,
        releaseMode: false,
        web: false,
      ),
      NativeAdUnitConfig.androidTestId,
    );
    expect(
      config.resolve(
        platform: TargetPlatform.iOS,
        releaseMode: false,
        web: false,
      ),
      NativeAdUnitConfig.iosTestId,
    );
  });

  test('Release 광고는 유효한 운영 단위 ID만 사용한다', () {
    const invalid = NativeAdUnitConfig(
      androidWeekReleaseId: 'ca-app-pub-invalid',
    );
    expect(
      invalid.resolve(
        platform: TargetPlatform.android,
        releaseMode: true,
        web: false,
      ),
      isNull,
    );

    const enabled = NativeAdUnitConfig(
      androidWeekReleaseId: 'ca-app-pub-1234567890123456/1234567890',
      iosWeekReleaseId: 'ca-app-pub-1234567890123456/0987654321',
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

  test('Release는 Today, Main, Week별 광고 단위를 구분한다', () {
    const config = NativeAdUnitConfig(
      androidTodayReleaseId: 'ca-app-pub-1234567890123456/1111111111',
      androidMainReleaseId: 'ca-app-pub-1234567890123456/2222222222',
      androidWeekReleaseId: 'ca-app-pub-1234567890123456/3333333333',
    );

    String? resolve(NativeAdPlacement placement) => config.resolve(
          placement: placement,
          platform: TargetPlatform.android,
          releaseMode: true,
          web: false,
        );

    expect(resolve(NativeAdPlacement.today), endsWith('/1111111111'));
    expect(resolve(NativeAdPlacement.main), endsWith('/2222222222'));
    expect(resolve(NativeAdPlacement.week), endsWith('/3333333333'));
  });

  test('웹과 지원하지 않는 데스크톱은 광고 단위를 반환하지 않는다', () {
    const config = NativeAdUnitConfig();
    expect(
      config.resolve(
        platform: TargetPlatform.android,
        releaseMode: false,
        web: true,
      ),
      isNull,
    );
    expect(
      config.resolve(
        platform: TargetPlatform.windows,
        releaseMode: false,
        web: false,
      ),
      isNull,
    );
  });
}
