import { temperatureRegionIdForGrid } from './kmaMidTermGridCatalog';

export interface KmaMidTermRegionIds {
  temperatureRegionId: string;
  landRegionId: string;
}

export interface KmaMidTermLocationContext {
  nx: number;
  ny: number;
  adminCode?: string;
  regionName?: string;
  sido?: string;
  sigungu?: string;
  eupMyeonDong?: string;
}

interface TemperatureRegion {
  name: string;
  temperatureRegionId: string;
}

// 기상청 중기기온예보구역코드(2025.12)의 국내 도시·지역(C) 목록.
// 법정동 이름 전체를 저장하지 않고 요청 중 받은 표시명과 가장 긴 지역명을 맞춘다.
const TEMPERATURE_REGIONS: readonly TemperatureRegion[] = [
{ name: '백령도', temperatureRegionId: '11A00101' },
  { name: '서울', temperatureRegionId: '11B10101' },
  { name: '과천', temperatureRegionId: '11B10102' },
  { name: '광명', temperatureRegionId: '11B10103' },
  { name: '강화', temperatureRegionId: '11B20101' },
  { name: '김포', temperatureRegionId: '11B20102' },
  { name: '인천', temperatureRegionId: '11B20201' },
  { name: '시흥', temperatureRegionId: '11B20202' },
  { name: '안산', temperatureRegionId: '11B20203' },
  { name: '부천', temperatureRegionId: '11B20204' },
  { name: '의정부', temperatureRegionId: '11B20301' },
  { name: '고양', temperatureRegionId: '11B20302' },
  { name: '양주', temperatureRegionId: '11B20304' },
  { name: '파주', temperatureRegionId: '11B20305' },
  { name: '동두천', temperatureRegionId: '11B20401' },
  { name: '연천', temperatureRegionId: '11B20402' },
  { name: '포천', temperatureRegionId: '11B20403' },
  { name: '가평', temperatureRegionId: '11B20404' },
  { name: '구리', temperatureRegionId: '11B20501' },
  { name: '남양주', temperatureRegionId: '11B20502' },
  { name: '양평', temperatureRegionId: '11B20503' },
  { name: '하남', temperatureRegionId: '11B20504' },
  { name: '수원', temperatureRegionId: '11B20601' },
  { name: '안양', temperatureRegionId: '11B20602' },
  { name: '오산', temperatureRegionId: '11B20603' },
  { name: '화성', temperatureRegionId: '11B20604' },
  { name: '성남', temperatureRegionId: '11B20605' },
  { name: '평택', temperatureRegionId: '11B20606' },
  { name: '의왕', temperatureRegionId: '11B20609' },
  { name: '군포', temperatureRegionId: '11B20610' },
  { name: '안성', temperatureRegionId: '11B20611' },
  { name: '용인', temperatureRegionId: '11B20612' },
  { name: '이천', temperatureRegionId: '11B20701' },
  { name: '광주', temperatureRegionId: '11B20702' },
  { name: '여주', temperatureRegionId: '11B20703' },
  { name: '충주', temperatureRegionId: '11C10101' },
  { name: '진천', temperatureRegionId: '11C10102' },
  { name: '음성', temperatureRegionId: '11C10103' },
  { name: '제천', temperatureRegionId: '11C10201' },
  { name: '단양', temperatureRegionId: '11C10202' },
  { name: '청주', temperatureRegionId: '11C10301' },
  { name: '보은', temperatureRegionId: '11C10302' },
  { name: '괴산', temperatureRegionId: '11C10303' },
  { name: '증평', temperatureRegionId: '11C10304' },
  { name: '추풍령', temperatureRegionId: '11C10401' },
  { name: '영동', temperatureRegionId: '11C10402' },
  { name: '옥천', temperatureRegionId: '11C10403' },
  { name: '서산', temperatureRegionId: '11C20101' },
  { name: '태안', temperatureRegionId: '11C20102' },
  { name: '당진', temperatureRegionId: '11C20103' },
  { name: '홍성', temperatureRegionId: '11C20104' },
  { name: '보령', temperatureRegionId: '11C20201' },
  { name: '서천', temperatureRegionId: '11C20202' },
  { name: '천안', temperatureRegionId: '11C20301' },
  { name: '아산', temperatureRegionId: '11C20302' },
  { name: '예산', temperatureRegionId: '11C20303' },
  { name: '대전', temperatureRegionId: '11C20401' },
  { name: '공주', temperatureRegionId: '11C20402' },
  { name: '계룡', temperatureRegionId: '11C20403' },
  { name: '세종', temperatureRegionId: '11C20404' },
  { name: '부여', temperatureRegionId: '11C20501' },
  { name: '청양', temperatureRegionId: '11C20502' },
  { name: '금산', temperatureRegionId: '11C20601' },
  { name: '논산', temperatureRegionId: '11C20602' },
  { name: '철원', temperatureRegionId: '11D10101' },
  { name: '화천', temperatureRegionId: '11D10102' },
  { name: '인제', temperatureRegionId: '11D10201' },
  { name: '양구', temperatureRegionId: '11D10202' },
  { name: '춘천', temperatureRegionId: '11D10301' },
  { name: '홍천', temperatureRegionId: '11D10302' },
  { name: '원주', temperatureRegionId: '11D10401' },
  { name: '횡성', temperatureRegionId: '11D10402' },
  { name: '영월', temperatureRegionId: '11D10501' },
  { name: '정선', temperatureRegionId: '11D10502' },
  { name: '평창', temperatureRegionId: '11D10503' },
  { name: '대관령', temperatureRegionId: '11D20201' },
  { name: '태백', temperatureRegionId: '11D20301' },
  { name: '속초', temperatureRegionId: '11D20401' },
  { name: '고성', temperatureRegionId: '11D20402' },
  { name: '양양', temperatureRegionId: '11D20403' },
  { name: '강릉', temperatureRegionId: '11D20501' },
  { name: '동해', temperatureRegionId: '11D20601' },
  { name: '삼척', temperatureRegionId: '11D20602' },
  { name: '울릉도', temperatureRegionId: '11E00101' },
  { name: '독도', temperatureRegionId: '11E00102' },
  { name: '전주', temperatureRegionId: '11F10201' },
  { name: '익산', temperatureRegionId: '11F10202' },
  { name: '정읍', temperatureRegionId: '11F10203' },
  { name: '완주', temperatureRegionId: '11F10204' },
  { name: '장수', temperatureRegionId: '11F10301' },
  { name: '무주', temperatureRegionId: '11F10302' },
  { name: '진안', temperatureRegionId: '11F10303' },
  { name: '남원', temperatureRegionId: '11F10401' },
  { name: '임실', temperatureRegionId: '11F10402' },
  { name: '순창', temperatureRegionId: '11F10403' },
  { name: '완도', temperatureRegionId: '11F20301' },
  { name: '해남', temperatureRegionId: '11F20302' },
  { name: '강진', temperatureRegionId: '11F20303' },
  { name: '장흥', temperatureRegionId: '11F20304' },
  { name: '여수', temperatureRegionId: '11F20401' },
  { name: '광양', temperatureRegionId: '11F20402' },
  { name: '고흥', temperatureRegionId: '11F20403' },
  { name: '보성', temperatureRegionId: '11F20404' },
  { name: '순천시', temperatureRegionId: '11F20405' },
  { name: '광주', temperatureRegionId: '11F20501' },
  { name: '장성', temperatureRegionId: '11F20502' },
  { name: '나주', temperatureRegionId: '11F20503' },
  { name: '담양', temperatureRegionId: '11F20504' },
  { name: '화순', temperatureRegionId: '11F20505' },
  { name: '구례', temperatureRegionId: '11F20601' },
  { name: '곡성', temperatureRegionId: '11F20602' },
  { name: '순천', temperatureRegionId: '11F20603' },
  { name: '흑산도', temperatureRegionId: '11F20701' },
  { name: '성산', temperatureRegionId: '11G00101' },
  { name: '제주', temperatureRegionId: '11G00201' },
  { name: '성판악', temperatureRegionId: '11G00302' },
  { name: '서귀포', temperatureRegionId: '11G00401' },
  { name: '고산', temperatureRegionId: '11G00501' },
  { name: '이어도', temperatureRegionId: '11G00601' },
  { name: '추자도', temperatureRegionId: '11G00800' },
  { name: '산천단', temperatureRegionId: '11G00901' },
  { name: '한남', temperatureRegionId: '11G01001' },
  { name: '울진', temperatureRegionId: '11H10101' },
  { name: '영덕', temperatureRegionId: '11H10102' },
  { name: '포항', temperatureRegionId: '11H10201' },
  { name: '경주', temperatureRegionId: '11H10202' },
  { name: '문경', temperatureRegionId: '11H10301' },
  { name: '상주', temperatureRegionId: '11H10302' },
  { name: '예천', temperatureRegionId: '11H10303' },
  { name: '영주', temperatureRegionId: '11H10401' },
  { name: '봉화', temperatureRegionId: '11H10402' },
  { name: '영양', temperatureRegionId: '11H10403' },
  { name: '안동', temperatureRegionId: '11H10501' },
  { name: '의성', temperatureRegionId: '11H10502' },
  { name: '청송', temperatureRegionId: '11H10503' },
  { name: '김천', temperatureRegionId: '11H10601' },
  { name: '구미', temperatureRegionId: '11H10602' },
  { name: '고령', temperatureRegionId: '11H10604' },
  { name: '성주', temperatureRegionId: '11H10605' },
  { name: '대구', temperatureRegionId: '11H10701' },
  { name: '영천', temperatureRegionId: '11H10702' },
  { name: '경산', temperatureRegionId: '11H10703' },
  { name: '청도', temperatureRegionId: '11H10704' },
  { name: '칠곡', temperatureRegionId: '11H10705' },
  { name: '군위', temperatureRegionId: '11H10707' },
  { name: '울산', temperatureRegionId: '11H20101' },
  { name: '양산', temperatureRegionId: '11H20102' },
  { name: '부산', temperatureRegionId: '11H20201' },
  { name: '창원', temperatureRegionId: '11H20301' },
  { name: '김해', temperatureRegionId: '11H20304' },
  { name: '통영', temperatureRegionId: '11H20401' },
  { name: '사천', temperatureRegionId: '11H20402' },
  { name: '거제', temperatureRegionId: '11H20403' },
  { name: '고성', temperatureRegionId: '11H20404' },
  { name: '남해', temperatureRegionId: '11H20405' },
  { name: '함양', temperatureRegionId: '11H20501' },
  { name: '거창', temperatureRegionId: '11H20502' },
  { name: '합천', temperatureRegionId: '11H20503' },
  { name: '밀양', temperatureRegionId: '11H20601' },
  { name: '의령', temperatureRegionId: '11H20602' },
  { name: '함안', temperatureRegionId: '11H20603' },
  { name: '창녕', temperatureRegionId: '11H20604' },
  { name: '진주', temperatureRegionId: '11H20701' },
  { name: '산청', temperatureRegionId: '11H20703' },
  { name: '하동', temperatureRegionId: '11H20704' },
  { name: '군산', temperatureRegionId: '21F10501' },
  { name: '김제', temperatureRegionId: '21F10502' },
  { name: '고창', temperatureRegionId: '21F10601' },
  { name: '부안', temperatureRegionId: '21F10602' },
  { name: '함평', temperatureRegionId: '21F20101' },
  { name: '영광', temperatureRegionId: '21F20102' },
  { name: '진도', temperatureRegionId: '21F20201' },
  { name: '목포', temperatureRegionId: '21F20801' },
  { name: '영암', temperatureRegionId: '21F20802' },
  { name: '신안', temperatureRegionId: '21F20803' },
  { name: '무안', temperatureRegionId: '21F20804' },
];

const DEFAULT_BY_ADMIN_PREFIX: Readonly<Record<string, string>> = {
  '11': '11B10101',
  '26': '11H20201',
  '27': '11H10701',
  '28': '11B20201',
  '29': '11F20501',
  '30': '11C20401',
  '31': '11H20101',
  '36': '11C20404',
  '41': '11B20601',
  '43': '11C10301',
  '44': '11C20401',
  '45': '11F10201',
  '52': '11F10201',
  '46': '11F20501',
  '47': '11H10701',
  '48': '11H20301',
  '50': '11G00201',
  '51': '11D10301',
};

// These metropolitan administrative prefixes map to one mid-term temperature
// region. They are therefore safe to prefer over a grid shared across an
// administrative boundary. Province-wide defaults below remain fallbacks.
const AUTHORITATIVE_ADMIN_PREFIXES = new Set([
  '11', '26', '27', '28', '29', '30', '31', '36',
]);

export function resolveKmaMidTermLocation(
  context: KmaMidTermLocationContext,
): KmaMidTermRegionIds | undefined {
  const combinedName = [
    context.regionName,
    context.sido,
    context.sigungu,
    context.eupMyeonDong,
  ].filter((value): value is string => Boolean(value?.trim())).join(' ');
  return resolveKmaMidTermRegionIds(
    combinedName || undefined,
    context.adminCode,
    context.nx,
    context.ny,
  );
}

export function resolveKmaMidTermRegionIds(
  regionName: string | undefined,
  regionCode: string | undefined,
  nx: number,
  ny: number,
): KmaMidTermRegionIds | undefined {
  const normalizedName = normalizeRegionName(regionName ?? '');
  const adminPrefix = /^\d{10}$/.test(regionCode ?? '')
    ? regionCode!.slice(0, 2)
    : undefined;
  let matches = normalizedName.length === 0
    ? []
    : TEMPERATURE_REGIONS.filter((candidate) =>
        normalizedName.includes(normalizeRegionName(candidate.name)),
      );

  if (matches.length > 1) {
    matches = disambiguateDuplicate(matches, adminPrefix, nx, ny);
  }
  matches.sort(
    (left, right) =>
      normalizeRegionName(right.name).length -
      normalizeRegionName(left.name).length,
  );
  const administrativeRegionId = adminPrefix &&
      AUTHORITATIVE_ADMIN_PREFIXES.has(adminPrefix)
    ? DEFAULT_BY_ADMIN_PREFIX[adminPrefix]
    : undefined;
  const temperatureRegionId =
    matches[0]?.temperatureRegionId ??
    administrativeRegionId ??
    temperatureRegionIdForGrid(nx, ny) ??
    (adminPrefix ? DEFAULT_BY_ADMIN_PREFIX[adminPrefix] : undefined);
  if (!temperatureRegionId) return undefined;
  return {
    temperatureRegionId,
    landRegionId: landRegionIdForTemperature(temperatureRegionId),
  };
}

export function supportedKmaMidTermRegionIds(): KmaMidTermRegionIds[] {
  const temperatureRegionIds = new Set(
    TEMPERATURE_REGIONS.map(({ temperatureRegionId }) => temperatureRegionId),
  );
  return [...temperatureRegionIds].sort().map((temperatureRegionId) => ({
    temperatureRegionId,
    landRegionId: landRegionIdForTemperature(temperatureRegionId),
  }));
}

function disambiguateDuplicate(
  matches: TemperatureRegion[],
  adminPrefix: string | undefined,
  nx: number,
  ny: number,
): TemperatureRegion[] {
  if (matches.some((candidate) => candidate.name === '광주')) {
    const gyeonggi = adminPrefix === '41' || (!adminPrefix && nx >= 62 && ny >= 105);
    return matches.filter((candidate) =>
      gyeonggi
        ? candidate.temperatureRegionId.startsWith('11B')
        : candidate.temperatureRegionId.startsWith('11F'),
    );
  }
  if (matches.some((candidate) => candidate.name === '고성')) {
    const gangwon = adminPrefix === '51' || (!adminPrefix && ny >= 136);
    return matches.filter((candidate) =>
      gangwon
        ? candidate.temperatureRegionId.startsWith('11D')
        : candidate.temperatureRegionId.startsWith('11H'),
    );
  }
  return matches;
}

export function landRegionIdForTemperature(
  temperatureRegionId: string,
): string {
  if (temperatureRegionId.startsWith('11B') || temperatureRegionId.startsWith('11A')) {
    return '11B00000';
  }
  if (temperatureRegionId.startsWith('11C1')) return '11C10000';
  if (temperatureRegionId.startsWith('11C2')) return '11C20000';
  if (temperatureRegionId.startsWith('11D1')) return '11D10000';
  if (temperatureRegionId.startsWith('11D2')) return '11D20000';
  if (temperatureRegionId.startsWith('11E')) return '11E00000';
  if (temperatureRegionId.startsWith('11F1') || temperatureRegionId.startsWith('21F1')) {
    return '11F10000';
  }
  if (temperatureRegionId.startsWith('11F2') || temperatureRegionId.startsWith('21F2')) {
    return '11F20000';
  }
  if (temperatureRegionId.startsWith('11G')) return '11G00000';
  if (temperatureRegionId.startsWith('11H1')) return '11H10000';
  if (temperatureRegionId.startsWith('11H2')) return '11H20000';
  throw new Error('Unsupported KMA mid-term temperature region');
}

function normalizeRegionName(value: string): string {
  return value
    .slice(0, 100)
    .replace(/\s+/g, '')
    .replaceAll('특별자치도', '')
    .replaceAll('특별자치시', '')
    .replaceAll('특별시', '')
    .replaceAll('광역시', '');
}
