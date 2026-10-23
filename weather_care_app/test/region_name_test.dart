import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/models/home_widget_snapshot.dart';
import 'package:weather_care/models/weather.dart';
import 'package:weather_care/services/gps_region_name_service.dart';
import 'package:weather_care/utils/region_name.dart';

void main() {
  test('숫자 동 앞 서수만 생략하고 고유 지명과 주소는 보존한다', () {
    const cases = {
      '서울 구로구 구로제3동': '서울 구로구 구로3동',
      '서울 구로구 구로제3동 123': '서울 구로구 구로3동 123',
      '(구로제3동)': '(구로3동)',
      '종로제1.2.3.4가동': '종로제1.2.3.4가동',
      '상계제3·4동': '상계3·4동',
      '거제1동': '거제1동',
      '홍제3동': '홍제3동',
      '거제제1동': '거제1동',
      '제주 제주시': '제주 제주시',
      '구로제3동산': '구로제3동산',
    };
    for (final entry in cases.entries) {
      expect(displayRegionName(entry.key), entry.value);
    }
  });

  test('GPS 기기 이름·서버 이름·서버 날씨·위젯에 같은 표시 규칙을 쓴다', () {
    const name = '서울특별시 구로구 구로제3동';
    expect(gpsRegionDisplayName(deviceName: name), '서울특별시 구로구 구로3동');
    expect(gpsRegionDisplayName(serverName: name), '서울 구로구 구로3동');
    expect(
        koreanAdministrativeDisplayName(
            administrativeArea: '서울특별시', locality: '구로구', subLocality: '구로제3동'),
        '서울 구로구 구로3동');
    expect(WeatherRegion.fromJson({'name': name}).name, '서울특별시 구로구 구로3동');
    expect(compactWidgetRegionName(name), '구로구 구로3동');
  });
}
