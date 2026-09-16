import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/services/app_open_launch_store.dart';

void main() {
  test('첫 실행은 제외하고 두 번째 실행부터 앱 오프닝 광고 대상이다', () async {
    SharedPreferences.setMockInitialValues({});
    const store = AppOpenLaunchStore();

    expect(await store.recordLaunchAndShouldShow(), isFalse);
    expect(await store.recordLaunchAndShouldShow(), isTrue);
  });
}
