import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/gps_region_name_service.dart';

void main() {
  test('세종의 광역 표기와 시 표기를 중복해서 표시하지 않는다', () {
    expect(
        koreanAdministrativeDisplayName(
            administrativeArea: '세종특별자치시', locality: '세종시', subLocality: '금남면'),
        '세종시 금남면');
  });
  test('도 지역은 시·구·동을 표시하고 결합된 시구 이름을 분리한다', () {
    expect(
      koreanAdministrativeDisplayName(
        administrativeArea: '경기도',
        subAdministrativeArea: '수원시팔달구',
        locality: '수원시',
        subLocality: '인계동',
      ),
      '수원시 팔달구 인계동',
    );
  });

  test('특별시와 광역시는 짧은 시 이름 뒤에 구·동을 표시한다', () {
    expect(
      koreanAdministrativeDisplayName(
        administrativeArea: '서울특별시',
        locality: '강남구',
        subLocality: '역삼동',
      ),
      '서울 강남구 역삼동',
    );
    expect(
      koreanAdministrativeDisplayName(
        administrativeArea: '부산광역시',
        locality: '해운대구',
        subLocality: '우1동',
      ),
      '부산 해운대구 우1동',
    );
  });

  test('읍·면도 동과 같은 최하위 생활권 이름으로 표시한다', () {
    expect(
      koreanAdministrativeDisplayName(
        administrativeArea: '제주특별자치도',
        locality: '제주시',
        subLocality: '우도면',
      ),
      '제주시 우도면',
    );
  });

  test('행정 필드에 동이 없으면 placemark 이름에서 동만 보완한다', () {
    expect(
      koreanAdministrativeDisplayName(
        administrativeArea: '경기도',
        locality: '성남시',
        subAdministrativeArea: '분당구',
        name: '정자동 12-3',
      ),
      '성남시 분당구 정자동',
    );
  });

  test('첫 결과가 시까지만 있어도 뒤 결과의 동 이름을 우선한다', () {
    expect(
      preferNeighborhoodDisplayName([
        '시흥시',
        '시흥시 대야동',
        '시흥시 은행동',
      ]),
      '시흥시 대야동',
    );
    expect(preferNeighborhoodDisplayName(['시흥시', null]), '시흥시');
  });

  test('행정 필드와 장소명에 동이 없으면 도로 주소에서 동을 보완한다', () {
    expect(
      koreanAdministrativeDisplayName(
        administrativeArea: '경기도',
        locality: '시흥시',
        name: '대야역',
        street: '경기도 시흥시 대야동 서해안로 123',
      ),
      '시흥시 대야동',
    );
  });

  test('행정구역으로 확인할 수 없는 값은 표시하지 않는다', () {
    expect(
      koreanAdministrativeDisplayName(name: '테헤란로 123'),
      isNull,
    );
  });
}
