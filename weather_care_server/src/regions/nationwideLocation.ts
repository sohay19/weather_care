import { KMA_ADMINISTRATIVE_AREAS } from './kmaAdministrativeAreas';
import { kmaGridCoordinates } from './kmaGridCoordinates';

export interface NationwideLocation {
  nx: number; ny: number; adminCode?: string; regionName?: string;
  coordinates?: { latitude: number; longitude: number };
  boundaryChecked?: boolean;
}
const normalizedAreas = KMA_ADMINISTRATIVE_AREAS.map((row) => ({ row, name: normalizeAdministrativeName(row[1]) }));
// 행정구역 경계가 없는 좌표를 다른 동의 중심점에 억지로 배정하지 않는다.
// 행정코드/전체 지역명 또는 동일 격자의 유일한 공식 구역만 확정할 수 있다.
export function administrativeAreaForLocation(location: NationwideLocation): typeof KMA_ADMINISTRATIVE_AREAS[number] | undefined {
  if (location.adminCode) {
    const area = KMA_ADMINISTRATIVE_AREAS.find((row) => row[0] === location.adminCode);
    if (area) return area;
  }
  const originalName = location.regionName?.trim().replace(/\s+/g, ' ');
  const originalMatch = KMA_ADMINISTRATIVE_AREAS.find((row) => row[1] === originalName);
  if (originalMatch) return originalMatch;
  const names = administrativeNameAlias(originalName ?? '').split(/\s+/).filter(Boolean);
  while (names.length) {
    const name = normalizeAdministrativeName(names.join(' '));
    const matches = normalizedAreas.filter((area) => area.name.endsWith(name)).map((area) => area.row);
    if (matches.length === 1) return matches[0];
    if (matches.length > 1) {
      const exact = matches.filter((row) => normalizeAdministrativeName(row[1]) === name);
      if (exact.length === 1) return exact[0];
      // 세종의 광역·시 계층은 같은 이름과 격자를 공유한다. 이름만 주면 광역 코드를 쓴다.
      const topLevel = exact.filter((row) => row[0].endsWith('00000000'));
      if (topLevel.length === 1) return topLevel[0];
      // 고성·광주처럼 동명인 공식 구역의 이름을 실제 GPS로 구분한다.
      // 이름이 없는 위치에 가까운 다른 동의 자료를 배정하는 경로가 아니다.
      const coordinates = coordinatesForLocation(location);
      if (coordinates) {
        const candidates = matches.map((row) => { const point = kmaGridCoordinates(row[2], row[3])!;
          return { row, distance: Math.hypot((point.latitude - coordinates.latitude) * 111,
            (point.longitude - coordinates.longitude) * 88) }; }).sort((a, b) => a.distance - b.distance);
        if (candidates[0].distance < 50 && candidates[1].distance - candidates[0].distance > 20) return candidates[0].row;
      }
    }
    names.pop();
  }
  if (location.boundaryChecked) return undefined;
  const matches = KMA_ADMINISTRATIVE_AREAS.filter((row) => row[2] === location.nx && row[3] === location.ny && !row[0].endsWith('00000'));
  return matches.length === 1 ? matches[0] : undefined;
}
function administrativeNameAlias(name: string): string {
  return name
    .replace(/^(?:광주광역시|전라남도|전남)(?=\s|$)/, '전남광주통합특별시')
    .replace(/^광주(?=\s+(?:광산구|북구|남구|동구|서구)(?:\s|$))/, '전남광주통합특별시')
    // 옛 중구의 섬 지역은 영종구로 개편됐다. 동 분할이 불명확하면 공식 상위 구까지 연결한다.
    .replace(/^(인천(?:광역시)?)\s+중구\s+(?=(?:운서(?:[12])?동|용유동|영종(?:[12])?동|운남동)(?:\s|$))/, '$1 영종구 ');
}
function normalizeAdministrativeName(name: string): string {
  return name.replace(/세종(?:특별자치시|시)/g, '세종').replace(/^(?:세종\s+)+세종(?=\s|$)/, '세종')
    .replace(/특별자치도|특별자치시|특별시|광역시/g, '')
    .replace('경기도', '경기').replace('강원도', '강원').replace('충청남도', '충남')
    .replace('충청북도', '충북').replace('전라남도', '전남').replace('전라북도', '전북')
    .replace('경상남도', '경남').replace('경상북도', '경북')
    // 거제·홍제의 고유명사 '제'는 보존하고 '제1동'의 서수만 제거한다.
    .replace(/제(\d+[.·ㆍ\d]*동)/g, (match, suffix, offset, text) => /(?:거|홍)$/.test(text.slice(0, offset)) ? match : suffix)
    .replace(/[,\.·ㆍ]/g, '').replace(/\s+/g, '');
}
export function coordinatesForLocation(location: NationwideLocation) {
  return location.coordinates ?? kmaGridCoordinates(location.nx, location.ny);
}
