import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/utils/korea_date.dart';

void main() {
  test('한국시간 다음 정시와 시간 키를 계산한다', () {
    final beforeHour = DateTime.parse('2026-09-21T22:59:50Z');

    expect(untilNextKoreaHour(beforeHour), const Duration(seconds: 10));
    expect(koreaHourKey(beforeHour), '2026-09-22T07');
    expect(
      koreaHourKey(beforeHour.add(const Duration(seconds: 10))),
      '2026-09-22T08',
    );
  });
}
