import { getCollectedCache, saveCollectedCache } from '../database/collectedWeatherRepository';
import { administrativeAreaForLocation, type NationwideLocation } from '../regions/nationwideLocation';
import type { TodayLivingIndices } from '../types';
import { latestUvPublicationTimes } from '../providers/uv/kmaUvProvider';

const STAGNATION_KEY = 'COLLECTED_NATIONWIDE_AIR_STAGNATION';
const POLLEN_KEY = 'COLLECTED_NATIONWIDE_POLLEN';
const LIVING_URL = 'https://apis.data.go.kr/1360000/LivingWthrIdxServiceV5/getAirDiffusionIdxV5';
const POLLEN_URL = 'https://apis.data.go.kr/1360000/HealthWthrIdxServiceV3';
const KST_MS = 9 * 60 * 60 * 1000;
const SPECIES = {
  oak: ['참나무', 'getOakPollenRiskIdxV3'],
  pine: ['소나무', 'getPinePollenRiskIdxV3'],
  weeds: ['잡초류', 'getWeedsPollenRiskndxV3'],
} as const;
const POLLEN_LEVELS = ['낮음', '보통', '높음', '매우 높음'] as const;
const STAGNATION_LEVELS: Record<string, string> = {
  '25': '낮음', '50': '보통', '75': '높음', '100': '매우 높음',
};

interface IndexRow { areaNo: string; date: string; [key: string]: unknown }
interface IndexCache { issue: string; rows: Record<string, IndexRow> }
interface PollenCache { issue: string; species: Record<string, Record<string, IndexRow>> }

function kstDate(now: Date): Date { return new Date(now.getTime() + KST_MS); }
function compact(date: Date, hour: number): string {
  return `${date.getUTCFullYear()}${String(date.getUTCMonth() + 1).padStart(2, '0')}${String(date.getUTCDate()).padStart(2, '0')}${String(hour).padStart(2, '0')}`;
}
function pollenIssue(now: Date): string {
  const effective = kstDate(new Date(now.getTime() - 30 * 60_000));
  if (effective.getUTCHours() >= 18) return compact(effective, 18);
  if (effective.getUTCHours() >= 6) return compact(effective, 6);
  return compact(new Date(effective.getTime() - 86_400_000), 18);
}
function activeSpecies(now: Date): (keyof typeof SPECIES)[] {
  const month = kstDate(now).getUTCMonth() + 1;
  if (month >= 3 && month <= 6) return ['oak', 'pine'];
  if (month >= 8 && month <= 10) return ['weeds'];
  return [];
}
function issueIso(issue: string): string {
  return `${issue.slice(0, 4)}-${issue.slice(4, 6)}-${issue.slice(6, 8)}T${issue.slice(8)}:00:00+09:00`;
}

async function nationwideRows(url: string, serviceKey: string, issue: string, fetcher: typeof fetch,
  keyName: 'ServiceKey' | 'serviceKey' = 'ServiceKey'): Promise<Record<string, IndexRow>> {
  const rows: Record<string, IndexRow> = {};
  let total: number | undefined;
  for (let page = 1; page <= (total === undefined ? 1 : Math.ceil(total / 1000)); page++) {
    const query = new URLSearchParams({ [keyName]: decodeURIComponent(serviceKey.trim()), pageNo: String(page),
      numOfRows: '1000', dataType: 'JSON', areaNo: '', time: issue });
    const response = await fetcher(`${url}?${query}`, { signal: AbortSignal.timeout(30_000) });
    if (!response.ok) throw new Error(`생활기상지수 HTTP ${response.status}`);
    const payload = await response.json() as { response?: { header?: { resultCode?: string }; body?: {
      totalCount?: string | number; items?: { item?: IndexRow | IndexRow[] } } } };
    const body = payload.response?.body;
    const count = Number(body?.totalCount);
    if (payload.response?.header?.resultCode !== '00' || !body ||
        !Number.isInteger(count) || count <= 0 || count > 10_000 ||
        (total !== undefined && total !== count)) throw new Error('생활기상지수 응답 또는 페이지 정보 오류');
    total = count;
    const items = body.items?.item;
    for (const row of Array.isArray(items) ? items : items ? [items] : []) {
      const areaNo = String(row.areaNo);
      if (!/^\d{10}$/.test(areaNo) || String(row.date) !== issue || rows[areaNo]) {
        throw new Error('생활기상지수 지역·발표시각 오류');
      }
      rows[areaNo] = row;
    }
  }
  if (Object.keys(rows).length !== total) throw new Error('생활기상지수 전국 자료 누락');
  return rows;
}

export async function collectNationwideLivingIndices(db: D1Database, serviceKey: string, now: Date,
  fetcher: typeof fetch = fetch): Promise<void> {
  if (!serviceKey.trim()) return;
  const stagnationIssue = latestUvPublicationTimes(now, 1)[0];
  const stagnation = await getCollectedCache<IndexCache>(db, STAGNATION_KEY);
  if (stagnation?.status !== 'AVAILABLE' || stagnation.value.issue !== stagnationIssue) {
    try {
      const rows = await nationwideRows(LIVING_URL, serviceKey, stagnationIssue, fetcher);
      await saveCollectedCache(db, { key: STAGNATION_KEY, type: STAGNATION_KEY,
        value: { issue: stagnationIssue, rows }, updatedAt: now });
    } catch (error) { console.warn('대기정체지수 수집 실패', error); }
  }
  const species = activeSpecies(now);
  if (species.length === 0) return;
  const issue = pollenIssue(now);
  const pollen = await getCollectedCache<PollenCache>(db, POLLEN_KEY);
  if (pollen?.status === 'AVAILABLE' && pollen.value.issue === issue &&
      species.every((key) => !!pollen.value.species[key])) return;
  const collected: PollenCache = { issue,
    species: pollen?.status === 'AVAILABLE' && pollen.value.issue === issue
      ? { ...pollen.value.species } : {} };
  for (const key of species) {
    if (collected.species[key]) continue;
    try {
      collected.species[key] = await nationwideRows(`${POLLEN_URL}/${SPECIES[key][1]}`, serviceKey, issue, fetcher, 'serviceKey');
    } catch (error) { console.warn(`${SPECIES[key][0]} 꽃가루지수 수집 실패`, error); }
  }
  if (Object.keys(collected.species).length) await saveCollectedCache(db, {
    key: POLLEN_KEY, type: POLLEN_KEY, value: collected, updatedAt: now,
  });
}

export async function readTodayLivingIndices(db: D1Database | undefined, location: NationwideLocation,
  now: Date): Promise<TodayLivingIndices> {
  const species = activeSpecies(now);
  const result: TodayLivingIndices = { pollenStatus: species.length ? 'UNAVAILABLE' : 'OUT_OF_SEASON', pollen: [] };
  const areaNo = administrativeAreaForLocation(location)?.[0];
  if (!areaNo) return result;
  const [stagnation, pollen] = await Promise.all([
    getCollectedCache<IndexCache>(db, STAGNATION_KEY),
    species.length ? getCollectedCache<PollenCache>(db, POLLEN_KEY) : Promise.resolve(null),
  ]);
  if (stagnation?.status === 'AVAILABLE' && now.getTime() - Date.parse(stagnation.updatedAt) <= 8 * 3_600_000) {
    const row = stagnation.value.rows[areaNo];
    const issuedAt = issueIso(stagnation.value.issue);
    const elapsedHours = (now.getTime() - Date.parse(issuedAt)) / 3_600_000;
    const slot = Math.max(3, Math.min(78, Math.floor(elapsedHours / 3) * 3));
    const level = STAGNATION_LEVELS[String(row?.[`h${slot}`] ?? '').trim()];
    if (level) result.airStagnation = { level, issuedAt,
      forecastAt: new Date(Date.parse(issuedAt) + slot * 3_600_000).toISOString() };
  }
  if (species.length && pollen?.status === 'AVAILABLE' &&
      now.getTime() - Date.parse(pollen.updatedAt) <= 24 * 3_600_000) {
    const issueDate = pollen.value.issue.slice(0, 8);
    const today = compact(kstDate(now), 0).slice(0, 8);
    const dayOffset = Math.round((Date.parse(`${today.slice(0, 4)}-${today.slice(4, 6)}-${today.slice(6)}T00:00:00Z`) -
      Date.parse(`${issueDate.slice(0, 4)}-${issueDate.slice(4, 6)}-${issueDate.slice(6)}T00:00:00Z`)) / 86_400_000);
    const field = ['today', 'tomorrow', 'dayaftertomorrow', 'todaysaftertomorrow'][dayOffset];
    if (field) for (const key of species) {
      const raw = pollen.value.species[key]?.[areaNo]?.[field];
      const code = raw === null || raw === undefined || String(raw).trim() === ''
        ? NaN : Number(raw);
      if (Number.isInteger(code) && code >= 0 && code <= 3) {
        result.pollen.push({ species: SPECIES[key][0], level: POLLEN_LEVELS[code],
          issuedAt: issueIso(pollen.value.issue) });
      }
    }
    if (result.pollen.length) result.pollenStatus = 'AVAILABLE';
  }
  return result;
}
