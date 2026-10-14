import { apiHubBudgetedFetch } from '../services/apiHubFetch';
import { getGridExtraSnapshot, gridExtraSnapshotExists, reserveGridExtraRequest,
  saveGridExtraSnapshot } from '../database/gridExtraRepository';
import { providerErrorDiagnostic } from '../observability/providerErrorDiagnostics';

export interface GridExtraConfig {
  tideStations: string[];
  buoyStations: string[];
  forecastStations: string[];
  ripCurrentBeaches: string[];
  romsAreas: Array<{ id: string; ymin: number; ymax: number; xmin: number; xmax: number }>;
  riverStations: Array<{ damCode: string; stationCode: string }>;
  dams: string[];
}

type Source = 'KHOA_TIDE_OBS' | 'KHOA_BUOY_OBS' | 'KHOA_TIDE_EXTREME'
  | 'KHOA_TIDE_HOURLY' | 'KHOA_ROMS' | 'KHOA_RIP_CURRENT'
  | 'KWATER_RIVER_LEVEL' | 'KWATER_DAM' | 'KWATER_DAM_CODES' | 'NIFS_JELLYFISH'
  | 'NIFS_JELLYFISH_DETAIL'
  | 'KMA_LIGHTNING' | 'HRFCO_RIVER_FLOW';

type RecordValue = Record<string, unknown>;

const KHOA_BASE = 'https://apis.data.go.kr';
const ONE_DAY_MS = 86_400_000;
const MAX_PAGES = 30;
const PAGE_SIZE = 300;

function koreanDate(now: Date): string {
  return new Date(now.getTime() + 9 * 3_600_000).toISOString().slice(0, 10);
}

function compactDate(now: Date): string { return koreanDate(now).replaceAll('-', ''); }

function hourSlot(now: Date): string {
  return `${now.toISOString().slice(0, 13)}:00:00.000Z`;
}

function asRecord(value: unknown): RecordValue {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as RecordValue : {};
}

function asItems(value: unknown): RecordValue[] {
  if (Array.isArray(value)) return value.map(asRecord);
  if (value && typeof value === 'object') return [value as RecordValue];
  return [];
}

function numberOrNull(value: unknown): number | null {
  if (value === null || value === undefined ||
    (typeof value === 'string' && !value.trim())) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function pick(row: RecordValue, fields: Record<string, string>): RecordValue {
  const result: RecordValue = {};
  for (const [name, field] of Object.entries(fields)) result[name] = row[field] ?? null;
  return result;
}

async function readText(response: Response, maxBytes: number): Promise<string> {
  const reader = response.body?.getReader();
  if (!reader) return '';
  const chunks: Uint8Array[] = [];
  let bytes = 0;
  try {
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      bytes += part.value.byteLength;
      if (bytes > maxBytes) {
        await reader.cancel();
        throw new Error('GRID_EXTRA_RESPONSE_TOO_LARGE');
      }
      chunks.push(part.value);
    }
  } finally { reader.releaseLock(); }
  const body = new Uint8Array(bytes);
  let offset = 0;
  for (const chunk of chunks) { body.set(chunk, offset); offset += chunk.byteLength; }
  return new TextDecoder('utf-8').decode(body);
}

async function fetchJsonPage(input: {
  db: D1Database; source: Source; url: URL; now: Date; fetcher: typeof fetch;
  page: number; dailyLimit?: number;
}): Promise<{ rows: RecordValue[]; total: number }> {
  const provider = `DATA_GO_${input.source}`;
  if (!await reserveGridExtraRequest(input.db, provider, input.dailyLimit ?? 9_000, input.now)) {
    throw new Error('GRID_EXTRA_DAILY_BUDGET_EXHAUSTED');
  }
  input.url.searchParams.set('pageNo', String(input.page));
  input.url.searchParams.set('numOfRows', String(PAGE_SIZE));
  const response = await input.fetcher(input.url, { signal: AbortSignal.timeout(20_000) });
  if (!response.ok) throw new Error(`GRID_EXTRA_HTTP_${response.status}`);
  const text = await readText(response, 2_000_000);
  let payload: RecordValue;
  try { payload = asRecord(JSON.parse(text)); }
  catch { throw new Error('GRID_EXTRA_INVALID_JSON'); }
  const gatewayError = asRecord(asRecord(payload.OpenAPI_ServiceResponse).cmmMsgHeader);
  if (gatewayError.returnReasonCode)
    throw new Error(`GRID_EXTRA_PROVIDER_${String(gatewayError.returnReasonCode)}`);
  const envelope = asRecord(payload.response ?? payload);
  const header = asRecord(envelope.header);
  const code = String(header.resultCode ?? payload.resultCode ?? '');
  if (code && !['0', '00', '03'].includes(code)) throw new Error(`GRID_EXTRA_PROVIDER_${code}`);
  if (code === '03') return { rows: [], total: 0 };
  if (!envelope.body || typeof envelope.body !== 'object')
    throw new Error('GRID_EXTRA_INVALID_RESPONSE');
  const body = asRecord(envelope.body);
  const rows = asItems(asRecord(body.items).item ?? body.item);
  const total = numberOrNull(body.totalCount) ?? rows.length;
  return { rows, total };
}

async function fetchAllPages(input: {
  db: D1Database; source: Source; path: string; key: string; now: Date;
  params: Record<string, string>; fetcher: typeof fetch; dailyLimit?: number;
}): Promise<RecordValue[]> {
  const url = new URL(input.path, KHOA_BASE);
  url.searchParams.set('serviceKey', input.key);
  url.searchParams.set(input.source.startsWith('KWATER_') ? '_type' : 'type', 'json');
  for (const [key, value] of Object.entries(input.params)) url.searchParams.set(key, value);
  const rows: RecordValue[] = [];
  for (let page = 1; page <= MAX_PAGES; page += 1) {
    let result: { rows: RecordValue[]; total: number } | undefined;
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try { result = await fetchJsonPage({ ...input, url, page }); break; }
      catch (error) {
        if (!(error instanceof Error) || error.message !== 'GRID_EXTRA_PROVIDER_04' ||
          attempt === 2) throw error;
        await new Promise((resolve) => setTimeout(resolve, 1_000 * (attempt + 1)));
      }
    }
    if (!result) throw new Error('GRID_EXTRA_RETRY_FAILED');
    rows.push(...result.rows);
    if (rows.length >= result.total) return rows;
    if (result.rows.length === 0) throw new Error('GRID_EXTRA_INCOMPLETE_PAGINATION');
  }
  throw new Error('GRID_EXTRA_PAGE_LIMIT_REACHED');
}

async function collectOne(input: {
  db: D1Database; source: Source; targetId: string; slot: string;
  now: Date; load: () => Promise<unknown>;
}): Promise<void> {
  if (await gridExtraSnapshotExists(input.db, input.source, input.targetId, input.slot)) return;
  try {
    const payload = await input.load();
    await saveGridExtraSnapshot(input.db, {
      source: input.source, targetId: input.targetId, slot: input.slot,
      payload, collectedAt: input.now,
    });
    console.log(JSON.stringify({ event: 'grid_extra_collected', source: input.source,
      targetId: input.targetId, slot: input.slot }));
  } catch (error) {
    console.error(JSON.stringify({ event: 'grid_extra_collection_failed',
      source: input.source, targetId: input.targetId, slot: input.slot,
      reason: error instanceof Error && /^GRID_(?:EXTRA|LIGHTNING)_[A-Z0-9_]+$/.test(error.message)
        ? error.message : undefined,
      ...providerErrorDiagnostic(error) }));
  }
}

function normalizeKhoa(rows: RecordValue[], fields: Record<string, string>): RecordValue[] {
  return rows.map((row) => ({ ...pick(row, fields),
    latitude: numberOrNull(row.lat), longitude: numberOrNull(row.lot) }));
}

export async function collectGridHourly(input: {
  db: D1Database; config: GridExtraConfig; now: Date;
  khoaKey?: string; kwaterKey?: string; nifsKey?: string; fetcher?: typeof fetch;
}): Promise<void> {
  const { db, config, now } = input;
  const fetcher = input.fetcher ?? fetch;
  const date = compactDate(now);
  const slot = hourSlot(now);
  const jobs: Array<() => Promise<void>> = [];
  const add = (source: Source, targetId: string, period: string,
    load: () => Promise<unknown>) => jobs.push(() => collectOne({ db, source, targetId,
      slot: period, now, load }));

  if (input.khoaKey) {
    const khoa = (source: Source, path: string, params: Record<string, string>) =>
      fetchAllPages({ db, source, path, params, key: input.khoaKey!, now, fetcher });
    for (const code of config.tideStations) add('KHOA_TIDE_OBS', code, slot, async () =>
      normalizeKhoa(await khoa('KHOA_TIDE_OBS', '/1192136/dtRecent/GetDTRecentApiService',
        { obsCode: code, reqDate: date, min: '60' }),
      { name: 'obsvtrNm', observedAt: 'obsrvnDt', tideCm: 'bscTdlvHgt',
        waterTempC: 'wtem', currentDirectionDeg: 'crdir', currentSpeedMs: 'crsp' }));
    for (const code of config.buoyStations) add('KHOA_BUOY_OBS', code, slot, async () =>
      normalizeKhoa(await khoa('KHOA_BUOY_OBS', '/1192136/twRecent/GetTWRecentApiService',
        { obsCode: code, reqDate: date, min: '60' }),
      { name: 'obsvtrNm', observedAt: 'obsrvnDt', waterTempC: 'wtem',
        currentDirectionDeg: 'crdir', currentSpeedCmPerSec: 'crsp' }));
    for (const code of config.forecastStations) {
      add('KHOA_TIDE_EXTREME', code, date, async () =>
        normalizeKhoa(await khoa('KHOA_TIDE_EXTREME',
          '/1192136/tideFcstHghLw/GetTideFcstHghLwApiService',
          { obsCode: code, reqDate: date }),
        { name: 'obsvtrNm', forecastAt: 'predcDt', tideCm: 'predcTdlvVl',
          extremeType: 'extrSe' }));
      add('KHOA_TIDE_HOURLY', code, date, async () =>
        normalizeKhoa(await khoa('KHOA_TIDE_HOURLY',
          '/1192136/tideFcstTime/GetTideFcstTimeApiService',
          { obsCode: code, reqDate: date, min: '60' }),
        { name: 'obsvtrNm', forecastAt: 'predcDt', tideCm: 'tdlvHgt' }));
    }
    for (const code of config.ripCurrentBeaches) add('KHOA_RIP_CURRENT', code, slot,
      async () => normalizeKhoa(await khoa('KHOA_RIP_CURRENT',
        '/1192136/ripCurrent/GetRipCurrentApiService',
        { beachCode: code, reqDate: date }),
      { beachCode: 'obsvtrId', name: 'obsvtrNm', observedAt: 'obsrvnDt',
        riskIndex: 'lastScr', riskMessage: 'lastScrCn' }));
    for (const area of config.romsAreas) add('KHOA_ROMS', area.id, date,
      async () => normalizeKhoa(await khoa('KHOA_ROMS',
        '/1192136/roms/GetRomsApiService',
        { ymin: String(area.ymin), ymax: String(area.ymax),
          xmin: String(area.xmin), xmax: String(area.xmax) }),
      { forecastAt: 'predcDt', waterTempC: 'wtem',
        currentDirectionDeg: 'crdir', currentSpeed: 'crsp' }));
  }
  if (input.kwaterKey) {
    const kwater = (source: Source, path: string, params: Record<string, string>) =>
      fetchAllPages({ db, source, path, params, key: input.kwaterKey!, now, fetcher });
    const isoDate = koreanDate(now);
    for (const station of config.riverStations) add('KWATER_RIVER_LEVEL',
      `${station.damCode}:${station.stationCode}`, slot, async () =>
        (await kwater('KWATER_RIVER_LEVEL',
          '/B500001/dam/excllncobsrvt/hourwal/hourwallist',
          { damcode: station.damCode, wal: station.stationCode,
            sdate: isoDate, edate: isoDate, stime: '00', etime: '23' }))
          .map((row) => ({ observedAt: row.obsrdt ?? null,
            levelM: numberOrNull(row.flux), rainfallMm: numberOrNull(row.hourwal) })));
    const damCodes = new Set(config.dams);
    try {
      const cached = await getGridExtraSnapshot<Array<string | { damcode: string; damnm: string }>>(
        db, 'KWATER_DAM_CODES', 'ALL', isoDate);
      if (cached) {
        for (const item of cached) damCodes.add(typeof item === 'string' ? item : item.damcode);
      } else {
        const rows = await fetchAllPages({ db, source: 'KWATER_DAM_CODES',
          path: '/B500001/dam/damCode/damCodelist', params: {},
          key: input.kwaterKey, now, fetcher, dailyLimit: 80 });
        const codes = rows.map((row) => ({ damcode: String(row.damcode ?? ''),
          damnm: String(row.damnm ?? row.damcode ?? '') }))
          .filter((item) => /^\d{7,10}$/.test(item.damcode));
        if (codes.length === 0) throw new Error('GRID_EXTRA_NO_DAM_CODES');
        await saveGridExtraSnapshot(db, { source: 'KWATER_DAM_CODES', targetId: 'ALL',
          slot: isoDate, payload: codes, collectedAt: now });
        for (const item of codes) damCodes.add(item.damcode);
      }
    } catch (error) {
      console.error(JSON.stringify({ event: 'grid_extra_collection_failed',
        source: 'KWATER_DAM_CODES',
        reason: error instanceof Error && /^GRID_EXTRA_[A-Z0-9_]+$/.test(error.message)
          ? error.message : undefined,
        ...providerErrorDiagnostic(error) }));
    }
    for (const code of damCodes) add('KWATER_DAM', code, slot, async () =>
      (await kwater('KWATER_DAM', '/B500001/dam/sluicePresentCondition/hourlist',
        { damcode: code, stdt: isoDate, eddt: isoDate }))
        .map((row) => ({ observedAt: row.obsrdt ?? null,
          levelM: numberOrNull(row.lowlevel), inflowM3PerSec: numberOrNull(row.inflowqy),
          dischargeM3PerSec: numberOrNull(row.totdcwtrqy) })));
  }
  if (input.nifsKey && new Date(now.getTime() + 9 * 3_600_000).getUTCHours() % 6 === 0) {
    add('NIFS_JELLYFISH', 'ALL', slot, async () => {
      const list = await fetchNifs(db, input.nifsKey!, now, 'jellyList',
        { sdate: compactDate(new Date(now.getTime() - 7 * ONE_DAY_MS)), edate: date }, fetcher);
      const items = asItems(asRecord(list.body).item ?? list.Item ?? list.item ??
        asRecord(asRecord(asRecord(list.response).body).items).item);
      for (const item of items) {
        const documentId = String(item.board_idx ?? '');
        if (!/^\d{1,12}$/.test(documentId)) continue;
        const publishedDate = String(item.inpt_date ?? '').replaceAll(/\D/g, '').slice(0, 8);
        const documentSlot = /^20\d{6}$/.test(publishedDate)
          ? `${publishedDate.slice(0, 4)}-${publishedDate.slice(4, 6)}-${publishedDate.slice(6, 8)}`
          : date;
        await collectOne({ db, source: 'NIFS_JELLYFISH_DETAIL', targetId: documentId,
          slot: documentSlot, now, load: () => fetchNifs(db, input.nifsKey!, now,
            String(item.gbn) === '0' ? 'jellyDetail2' : 'jellyDetail',
            { srcode: documentId }, fetcher) });
      }
      return { items };
    });
  }
  // 외부 제공처의 초당 제한을 피하기 위해 기본적으로 순차 실행한다.
  for (const job of jobs) await job();
}

async function fetchNifs(db: D1Database, key: string, now: Date, id: string,
  params: Record<string, string>, fetcher: typeof fetch): Promise<RecordValue> {
  if (!await reserveGridExtraRequest(db, 'NIFS_JELLYFISH', 200, now))
    throw new Error('GRID_EXTRA_DAILY_BUDGET_EXHAUSTED');
  const url = new URL('https://www.nifs.go.kr/OpenAPI_json');
  url.searchParams.set('id', id);
  url.searchParams.set('key', key);
  for (const [name, value] of Object.entries(params)) url.searchParams.set(name, value);
  const response = await fetcher(url, { signal: AbortSignal.timeout(20_000) });
  if (!response.ok) throw new Error(`GRID_EXTRA_HTTP_${response.status}`);
  let payload: RecordValue;
  try { payload = asRecord(JSON.parse(await readText(response, 2_000_000))); }
  catch { throw new Error('GRID_EXTRA_INVALID_JSON'); }
  const header = asRecord(payload.Header ?? payload.header);
  const code = String(header.resultCode ?? '');
  if (code && code !== '00' && code !== '0') throw new Error(`GRID_EXTRA_PROVIDER_${code}`);
  return payload;
}

export function parseLightningText(text: string): RecordValue[] {
  const events: RecordValue[] = [];
  for (const line of text.split(/\r?\n/)) {
    const parts = line.trim().split(/\s+/);
    if (!/^\d{12,14}$/.test(parts[0] ?? '')) continue;
    const longitude = numberOrNull(parts[1]);
    const latitude = numberOrNull(parts[2]);
    if (longitude === null || latitude === null || longitude < 100 || longitude > 150 ||
      latitude < 20 || latitude > 50) continue;
    events.push({ observedAt: parts[0], longitude, latitude,
      intensity: numberOrNull(parts[3]), type: parts[4] ?? null,
      altitudeKm: numberOrNull(parts[5]) });
  }
  return events;
}

export async function collectGridRiverFlow(input: {
  db: D1Database; key: string; now: Date; fetcher?: typeof fetch;
}): Promise<void> {
  if (!input.key) return;
  await collectOne({ db: input.db, source: 'HRFCO_RIVER_FLOW', targetId: 'ALL',
    slot: hourSlot(input.now), now: input.now, load: async () => {
      if (!await reserveGridExtraRequest(input.db, 'HRFCO_RIVER_FLOW', 100, input.now))
        throw new Error('GRID_EXTRA_DAILY_BUDGET_EXHAUSTED');
      const url = new URL(`https://api.hrfco.go.kr/${encodeURIComponent(input.key)}/waterlevel/list/10M.json`);
      const response = await (input.fetcher ?? fetch)(url, { signal: AbortSignal.timeout(20_000) });
      if (!response.ok) throw new Error(`GRID_EXTRA_HTTP_${response.status}`);
      let payload: RecordValue;
      try { payload = asRecord(JSON.parse(await readText(response, 2_000_000))); }
      catch { throw new Error('GRID_EXTRA_INVALID_JSON'); }
      if (!Array.isArray(payload.content)) throw new Error('GRID_EXTRA_INVALID_RESPONSE');
      const stations = asItems(payload.content).map((row) => ({
        stationCode: row.wlobscd ?? null,
        observedAt: row.ymdhm ?? null,
        levelM: numberOrNull(row.wl),
        flowM3PerSec: numberOrNull(row.fw),
      })).filter((row) => row.flowM3PerSec !== null &&
        /^\d{7}$/.test(String(row.stationCode)) &&
        /^\d{12}$/.test(String(row.observedAt)));
      if (stations.length === 0) throw new Error('GRID_EXTRA_NO_FLOW_DATA');
      return { stations };
    } });
}

export async function collectGridLightning(input: {
  db: D1Database; key: string; now: Date; fetcher?: typeof fetch;
}): Promise<void> {
  if (!input.key) return;
  const newest = Math.floor((input.now.getTime() - 5 * 60_000) / 600_000) * 600_000 - 600_000;
  for (let missed = 2; missed >= 0; missed -= 1) {
    const slotStart = new Date(newest - missed * 600_000);
    const midpoint = new Date(slotStart.getTime() + 5 * 60_000);
    const local = new Date(midpoint.getTime() + 9 * 3_600_000).toISOString();
    const tm = local.slice(0, 16).replaceAll(/[-T:]/g, '');
    await collectOne({ db: input.db, source: 'KMA_LIGHTNING', targetId: 'ALL',
      slot: slotStart.toISOString(), now: input.now, load: async () => {
        const url = new URL('https://apihub.kma.go.kr/api/typ01/url/lgt_pnt.php');
        url.searchParams.set('tm', tm);
        url.searchParams.set('itv', '5');
        url.searchParams.set('authKey', input.key);
        const response = await apiHubBudgetedFetch({ db: input.db, provider: 'GRID_LIGHTNING',
          now: input.now, maxBytes: 2_000_000, sourceVersion: tm,
          fetcher: input.fetcher })(url, { signal: AbortSignal.timeout(20_000) });
        if (!response.ok) throw new Error(`GRID_LIGHTNING_HTTP_${response.status}`);
        const text = await response.text();
        if (/활용신청|인증키|초과|<html|<\?xml/i.test(text.slice(0, 300)))
          throw new Error('GRID_LIGHTNING_PROVIDER_ERROR');
        const events = parseLightningText(text);
        if (events.length === 0 && /^\d{12,14}\s/m.test(text))
          throw new Error('GRID_LIGHTNING_UNPARSEABLE_RESPONSE');
        return { windowStart: slotStart.toISOString(), windowEnd:
          new Date(slotStart.getTime() + 600_000).toISOString(), events };
      } });
  }
}
