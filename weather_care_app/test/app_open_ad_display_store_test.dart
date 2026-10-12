import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_care/services/app_open_ad_display_store.dart';

void main() {
  test('마지막 광고 표시 시간을 앱 재시작 이후에도 읽을 수 있다', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesAppOpenAdDisplayStore();
    final shownAt = DateTime(2026, 10, 13, 12, 30);

    expect(await store.lastShownAt(), isNull);
    await store.recordShownAt(shownAt);
    expect(
      await const SharedPreferencesAppOpenAdDisplayStore().lastShownAt(),
      shownAt,
    );
  });
}
