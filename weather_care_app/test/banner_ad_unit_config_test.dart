import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/banner_ad_unit_config.dart';

void main() {
  test('debug builds always use Google test banner units', () {
    const config = BannerAdUnitConfig(
      androidReleaseId: 'ca-app-pub-1234567890123456/1234567890',
      iosReleaseId: 'ca-app-pub-1234567890123456/0987654321',
      releaseServingEnabled: true,
    );

    expect(
      config.resolve(
        platform: TargetPlatform.android,
        releaseMode: false,
        web: false,
      ),
      BannerAdUnitConfig.androidTestId,
    );
    expect(
      config.resolve(
        platform: TargetPlatform.iOS,
        releaseMode: false,
        web: false,
      ),
      BannerAdUnitConfig.iosTestId,
    );
  });

  test('release ads require both the kill switch and a valid unit ID', () {
    const disabled = BannerAdUnitConfig(
      androidReleaseId: 'ca-app-pub-1234567890123456/1234567890',
    );
    expect(
      disabled.resolve(
        platform: TargetPlatform.android,
        releaseMode: true,
        web: false,
      ),
      isNull,
    );

    const invalid = BannerAdUnitConfig(
      androidReleaseId: 'ca-app-pub-invalid',
      releaseServingEnabled: true,
    );
    expect(
      invalid.resolve(
        platform: TargetPlatform.android,
        releaseMode: true,
        web: false,
      ),
      isNull,
    );

    const enabled = BannerAdUnitConfig(
      androidReleaseId: 'ca-app-pub-1234567890123456/1234567890',
      iosReleaseId: 'ca-app-pub-1234567890123456/0987654321',
      releaseServingEnabled: true,
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

  test('web and unsupported desktop platforms never return an ad unit', () {
    const config = BannerAdUnitConfig();
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
