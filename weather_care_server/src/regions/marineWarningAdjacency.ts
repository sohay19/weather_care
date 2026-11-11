import { administrativeAreaForLocation, type NationwideLocation } from './nationwideLocation';
import { selectableMarineWarningZones } from './kmaMarineWarningZones';

// 인접은 기상청 해상국지예보구역의 관할 육상 지역으로 판정한다.
// 출처: 예보업무규정 별표 4 / 날씨누리 특보구역. 먼바다는 육상에 배정하지 않는다.
// https://www.weather.go.kr/w/forecast/guide/wrn-area.do
// https://www.kma.go.kr/kma/flexer/html/lawinst/2020/08/03/ATC202008031457041_acd5de11-5f91-4d7c-999f-c51dcf1343e3.hwp.files/Sections1.html
const coastalAreas: Array<[string, RegExp]> = [
  ['S1131100', /^울산광역시 (동구|북구|남구|울주군) /],
  ['S1131200', /^경상북도 (경주시|포항시) /],
  ['S1131300', /^경상북도 (영덕군|울진군) /],
  ['S1151100', /^강원특별자치도 (속초시|고성군|양양군) /],
  ['S1151200', /^강원특별자치도 강릉시 /],
  ['S1151300', /^강원특별자치도 (동해시|삼척시) /],
  ['S1231100', /^전북특별자치도 (군산시|김제시) /],
  ['S1231200', /^전북특별자치도 (고창군|부안군) /],
  ['S1231300', /^(전라남도|전남광주통합특별시) (영광군|함평군) /],
  ['S1231400', /^(전라남도|전남광주통합특별시) ((목포시|무안군|영암군) |신안군 (?!흑산면 ))/],
  ['S1231500', /^(전라남도|전남광주통합특별시) (진도군 |해남군 (화원면|문내면|황산면|산이면|화산면|송지면) )/],
  ['S1321100', /^(전라남도|전남광주통합특별시) ((강진군|완도군|장흥군) |해남군 (북평면|북일면|송지면) )/],
  ['S1321200', /^(전라남도|전남광주통합특별시) (광양시|순천시|여수시|고흥군|보성군) /],
  ['S1251100', /^(경기도 김포시 |인천광역시 (강화군 |옹진군 (백령면|대청면|연평면) ))/],
  ['S1251200', /^(인천광역시 (중구|제물포구|영종구|동구|미추홀구|연수구|남동구|서구|서해구) |인천광역시 옹진군 (?!백령면 |대청면 |연평면 )|경기도 (시흥시 |안산시 |평택시 (현덕면|포승읍) |화성시 (?:[^ ]+구 )?(송산면|서신면|우정읍) ))/],
  ['S1251300', /^충청남도 (서산시|당진시|태안군|홍성군) /],
  ['S1251400', /^충청남도 (보령시|서천군) /],
  ['S1311100', /^부산광역시 (기장군|해운대구|수영구|남구|강서구|사하구|영도구|서구|동구|중구) /],
  ['S1311200', /^경상남도 ((사천시|남해군) |하동군 (금남면|금성면|진교면) |통영시 (?!용남면 |광도면 )|고성군 (?!거류면 |동해면 |마암면 |회화면 )|거제시 (둔덕면|거제면|동부면|남부면) )/],
  ['S1311300', /^경상남도 (창원시 |통영시 (용남면|광도면) |고성군 (거류면|동해면|마암면|회화면) |거제시 (장목면|하청면|연초면|사등면|고현동|상문동|장평동|수양동) )/],
  ['S1311400', /^경상남도 거제시 (옥포[12]?동|아주동|능포동|장승포동|마전동|일운면|동부면|남부면) /],
  ['S1323100', /^제주특별자치도 제주시 (?!구좌읍 |우도면 |한림읍 |한경면 |추자면 )/],
  ['S1323200', /^제주특별자치도 (제주시 (구좌읍|우도면) |서귀포시 (성산읍|표선면) )/],
  ['S1323300', /^제주특별자치도 서귀포시 (?!성산읍 |표선면 |대정읍 )/],
  ['S1323400', /^제주특별자치도 (제주시 (한림읍|한경면) |서귀포시 대정읍 )/],
];

const zoneNames = new Map(selectableMarineWarningZones.map(zone => [zone.id, zone.name]));
const parentZones: Record<string, readonly string[]> = {
  S1131000: ['S1131100', 'S1131200', 'S1131300'],
  S1151000: ['S1151100', 'S1151200', 'S1151300'],
  S1231000: ['S1231100', 'S1231200', 'S1231300', 'S1231400', 'S1231500'],
  S1251000: ['S1251100', 'S1251200', 'S1251300', 'S1251400'],
  S1311000: ['S1311100', 'S1311200', 'S1311300', 'S1311400'],
  S1321000: ['S1321100', 'S1321200'],
  S1323000: ['S1323100', 'S1323200', 'S1323300', 'S1323400'],
};

export function adjacentMarineWarningZoneIds(location: NationwideLocation): Set<string> {
  const area = administrativeAreaForLocation(location);
  const adjacent = new Set<string>();
  // 시도 이름만 확인된 위치는 해안 시군으로 확대하지 않는다.
  if (!area || area[0].endsWith('00000000')) return adjacent;
  const name = area[1] + ' ';
  for (const [id, pattern] of coastalAreas) if (pattern.test(name)) adjacent.add(id);
  for (const [id, children] of Object.entries(parentZones)) {
    if (children.some(child => adjacent.has(child))) adjacent.add(id);
  }
  // 연안·평수 구역은 상위 앞바다가 같을 때만 허용한다.
  for (const zone of selectableMarineWarningZones) {
    if (!zone.name.includes('중 ')) continue;
    const parentName = zone.name.split('중 ')[0];
    if ([...adjacent].some(id => zoneNames.get(id) === parentName)) {
      if (zone.name.includes('남해군') && !name.includes('남해군 ')) continue;
      if (zone.name.includes('우도') && !name.includes('우도면 ')) continue;
      if (zone.name.includes('가파도') && !name.includes('대정읍 ')) continue;
      adjacent.add(zone.id);
    }
  }
  // 상위 앞바다와 코드가 별개인 섬 연안도 정확한 행정구역으로 제한한다.
  if (/^제주특별자치도 제주시 추자면 /.test(name)) adjacent.add('S2330100');
  if (/^경상북도 울릉군 울릉읍 /.test(name)) adjacent.add('S2120800');
  if (/^경상북도 울릉군 서면 /.test(name)) adjacent.add('S2120900');
  if (/^경상북도 울릉군 북면 /.test(name)) adjacent.add('S2121000');
  return adjacent;
}
