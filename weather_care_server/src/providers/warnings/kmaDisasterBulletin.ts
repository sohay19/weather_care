import { KMA_ADMINISTRATIVE_AREAS } from '../../regions/kmaAdministrativeAreas';
import { selectableMarineWarningZones } from '../../regions/kmaMarineWarningZones';

const home = 'https://www.weather.go.kr/w/wnuri-main';
export const disasterBulletinMaxAgeMs = 45 * 60_000;

export interface KmaDisasterBulletin {
  issuedAt: string;
  title: string;
  regionCodes: string[];
}

const areaNames = new Map<string, Set<string>>();
const administrativeNames = new Map<string, string>();
function addAreaName(name: string, code: string): void {
  const codes = areaNames.get(name) ?? new Set<string>();
  codes.add(code);
  areaNames.set(name, codes);
}

for (const [code, fullName] of KMA_ADMINISTRATIVE_AREAS) {
  const hierarchy = fullName.replace(/([가-힣]+시)([가-힣]+구)(?=\s|$)/g, '$1 $2');
  administrativeNames.set(code, hierarchy);
  if (!code.endsWith('00000')) continue;
  addAreaName(fullName, code);
  addAreaName(hierarchy, code);
  if (code.endsWith('00000000')) {
    addAreaName(fullName.replace(/특별자치도|특별자치시|광역시|특별시|도$/g, ''), code);
  } else {
    const name = fullName.split(' ').at(-1)!;
    addAreaName(name, code);
    addAreaName(hierarchy.split(' ').at(-1)!, code);
    if (!name.endsWith('구')) addAreaName(name.replace(/[시군]$/, ''), code);
  }
}
for (const [name, code] of Object.entries({
  충남: '4400000000', 충북: '4300000000', 경남: '4800000000', 경북: '4700000000', 전라북도: '5200000000',
})) addAreaName(name, code);
for (const { id, name } of selectableMarineWarningZones) addAreaName(name, id);

// 관측 표의 권역 머리글은 동명이인 지역을 구분하는 데만 사용한다.
const observationRegions: Record<string, readonly string[]> = {
  수도권: ['11', '28', '41'], 경기도: ['41'], 강원도: ['51'], 강원권: ['51'],
  충청권: ['30', '36', '43', '44'], 전라권: ['12', '52'], 경상권: ['26', '27', '31', '47', '48'],
  제주도: ['50'],
};

const areaPattern = new RegExp(
  '(?:^|[\\s,(·])(' +
  [...areaNames.keys()].sort((a, b) => b.length - a.length)
    .map((name) => name.replace(/[^가-힣0-9 ]/g, (character) => '\\' + character)).join('|') +
  ')(?=$|[\\s,).·]|(?:과|와|에는|에서는|에서|에|을|를|은|는)(?=$|[\\s,]))', 'g',
);

function unambiguousArea(name: string, prefixes?: readonly string[]): string | undefined {
  const codes = [...(areaNames.get(name) ?? [])].filter((code) =>
    !prefixes || prefixes.includes(code.slice(0, 2)));
  return codes.length === 1 ? codes[0] : undefined;
}

function bulletinRegions(lines: readonly string[]): string[] {
  const regions = new Set<string>();
  for (const line of lines) {
    if (/^○\s*\((?:현황|전망|현황 및 전망)\)/.test(line)) {
      if (/제외|이외|이전보다/.test(line)) continue;
      for (const match of line.matchAll(areaPattern)) {
        // '강원 내륙'처럼 일부만 가리키면 도 전체로 확장하지 않는다.
        const rest = line.slice(match.index + match[0].length);
        if (/^\s*(?:\(|내륙|산지|동부|서부|남부|북부|중부|해안|일부|대부분|부근|인근)/.test(rest)) continue;
        const code = unambiguousArea(match[1]);
        if (code) regions.add(code);
      }
      continue;
    }
    const observation = /^-\s*([가-힣]+):\s*(.+)$/.exec(line);
    const prefixes = observation && observationRegions[observation[1]];
    if (!observation || !prefixes) continue;
    for (const [, station] of observation[2].matchAll(/(?:^|\s)([가-힣]+(?:\([가-힣]+\))?)\s+-?\d+(?:\.\d+)?(?=\s|$)/g)) {
      const place = /\(([가-힣]+)\)$/.exec(station)?.[1] ?? station;
      const code = unambiguousArea(place, prefixes);
      if (code) regions.add(code);
    }
  }
  return [...regions];
}

function issueTime(compact: string): number {
  const match = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})$/.exec(compact);
  if (!match) return NaN;
  const [, year, month, day, hour, minute] = match;
  return Date.parse(year + '-' + month + '-' + day + 'T' + hour + ':' + minute + ':00+09:00');
}

export function disasterBulletinIsCurrent(issuedAt: string, now: Date): boolean {
  const age = now.getTime() - issueTime(issuedAt);
  return age >= 0 && age < disasterBulletinMaxAgeMs;
}

export function disasterBulletinExpiresAt(issuedAt: string): string {
  return new Date(issueTime(issuedAt) + disasterBulletinMaxAgeMs).toISOString();
}

export function parseKmaDisasterBulletin(html: string, issuedAt: string): KmaDisasterBulletin {
  const header = /\[기상청 속보\]\s*(\d{4})년\s*(\d{1,2})월\s*(\d{1,2})일\s*(\d{1,2})시\s*(\d{1,2})분/.exec(html);
  const paragraph = /<div class="paragraph">\s*<p class="tit">([\s\S]*?)<\/p>/i.exec(html);
  if (!header || header.slice(1).map((part) => part.padStart(2, '0')).join('') !== issuedAt || !paragraph) {
    throw new Error('KMA_DISASTER_BULLETIN_FORMAT_CHANGED');
  }
  const [heading, ...lines] = paragraph[1].split(/<br\s*\/?>/i)
    .map((line) => line.replace(/&nbsp;/g, ' ').replace(/&lt;/g, '<').replace(/&gt;/g, '>').trim());
  const title = /^<?([가-힣0-9 ,·().~-]{2,65})>?$/.exec(heading)?.[1];
  if (!title || !lines.length) throw new Error('KMA_DISASTER_BULLETIN_FORMAT_CHANGED');
  return { issuedAt, title, regionCodes: bulletinRegions(lines) };
}

export async function fetchKmaDisasterBulletin(
  now: Date, previous: KmaDisasterBulletin | null, fetcher: typeof fetch = fetch,
): Promise<KmaDisasterBulletin | null> {
  const status = await fetcher(home + '/rest/bangjae/bangjae-xml-exists.do', {
    method: 'POST', redirect: 'error', signal: AbortSignal.timeout(8_000),
  });
  if (!status.ok) throw new Error('KMA_DISASTER_BULLETIN_STATUS_FAILED');
  const { bangjaeExists, lastTmFc } = await status.json() as { bangjaeExists?: boolean; lastTmFc?: string };
  if (bangjaeExists === false) return null;
  if (bangjaeExists !== true || typeof lastTmFc !== 'string' || !Number.isFinite(issueTime(lastTmFc))) {
    throw new Error('KMA_DISASTER_BULLETIN_INVALID_STATUS');
  }
  if (!disasterBulletinIsCurrent(lastTmFc, now)) return null;
  if (previous?.issuedAt === lastTmFc) return previous;
  const detail = await fetcher(home + '/bangjae/bang-xml.do?bngEx=true', {
    redirect: 'error', signal: AbortSignal.timeout(8_000),
  });
  if (!detail.ok) throw new Error('KMA_DISASTER_BULLETIN_DETAIL_FAILED');
  const html = await detail.text();
  if (html.length > 64_000) throw new Error('KMA_DISASTER_BULLETIN_INVALID_SIZE');
  return parseKmaDisasterBulletin(html, lastTmFc);
}

export function disasterBulletinMatchesRegion(regionCodes: readonly string[], regionCode: string): boolean {
  const regionName = administrativeNames.get(regionCode);
  return regionCodes.some((code) => {
    if (code === regionCode) return true;
    const name = administrativeNames.get(code);
    return Boolean(name && regionName?.startsWith(name + ' '));
  });
}
