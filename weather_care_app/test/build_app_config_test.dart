import 'package:flutter_test/flutter_test.dart';

import '../tool/build_app_config.dart';

void main() {
  final testConfig = {
    'SERVER_URL': 'https://weather-test-api.codesoha.com',
    'TEST_ACCESS_KEY': '시험-접근-키',
  };

  test('Debug 자산에는 시험 서버와 한글 접근 키를 유지한다', () {
    expect(buildAppConfig(testConfig, buildMode: 'debug'), testConfig);
  });

  for (final mode in ['release', 'profile', null]) {
    test('$mode 자산은 시험 설정을 제거하고 운영 주소만 포함한다', () {
      expect(buildAppConfig(testConfig, buildMode: mode), {
        'SERVER_URL': 'https://weather-api.codesoha.com',
      });
      expect(testConfig['TEST_ACCESS_KEY'], '시험-접근-키');
    });
  }
}
