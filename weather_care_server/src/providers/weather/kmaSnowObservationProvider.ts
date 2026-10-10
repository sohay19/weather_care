import { kmaApiHubErrorStatus } from '../kmaApiHubResponse';

export const SNOW_MAX_AGE_MS = 3 * 3_600_000;
export const SNOW_RESPONSE_MAX_BYTES = 512_000;
export interface SnowStation {
  observedAt: string;
  stationId: string;
  stationName: string;
  longitude: number;
  latitude: number;
  stationKind: string;
  depthCm?: number;
}
export interface SnowSnapshot {
  requestedAt: string;
  stations: SnowStation[];
  invalidCoordinateRows?: number;
}

export function snowRequestTime(now: Date): string {
  const clock = new Date(now.getTime() + 9 * 3_600_000 - 10 * 60_000);
  clock.setUTCMinutes(Math.floor(clock.getUTCMinutes() / 10) * 10, 0, 0);
  return clock.toISOString().replace(/[-:T]/g, '').slice(0, 12);
}

// 실제 승인 응답은 7개 값 뒤의 '=' 종료 표식을 포함한 8열이다.
export function parseSnowSnapshot(text: string, requestedAt: string, now: Date): SnowSnapshot {
  const status = kmaApiHubErrorStatus(text);
  if (status !== undefined) throw new Error(`KMA snow request status ${status}`);
  const stations: SnowStation[] = [];
  let invalidCoordinateRows = 0;
  const ids = new Set<string>();
  for (const line of text.split(/\r?\n/)) {
    if (!line.trim() || line.trim().startsWith('#')) continue;
    const fields = line.split(',').map((field) => field.trim());
    if (fields.length !== 8 || fields[7] !== '=' || !/^\d{12}$/.test(fields[0]) ||
        !/^\d{1,6}$/.test(fields[1]) || !fields[2] || fields[2].length > 100 ||
        !/^[\dA-Za-z-]{1,16}$/.test(fields[5]) ||
        ![fields[3], fields[4], fields[6]].every((field) => /^-?\d+(?:\.\d+)?$/.test(field))) {
      throw new Error('KMA snow response row invalid');
    }
    const time = fields[0];
    const observedAt = `${time.slice(0,4)}-${time.slice(4,6)}-${time.slice(6,8)}T${time.slice(8,10)}:${time.slice(10,12)}:00+09:00`;
    const instant = Date.parse(observedAt);
    const normalized = Number.isFinite(instant)
      ? new Date(instant + 9 * 3_600_000).toISOString().replace(/[-:T]/g, '').slice(0,12) : '';
    const longitude = Number(fields[3]), latitude = Number(fields[4]), depth = Number(fields[6]);
    if (normalized !== time || instant > now.getTime() || ids.has(fields[1]) || depth > 1000) {
      throw new Error('KMA snow response value invalid');
    }
    ids.add(fields[1]);
    // 일부 지점의 원본 좌표 오류를 임의 보정하거나 전국 정상 자료까지 버리지 않는다.
    if (longitude < 120 || longitude > 135 || latitude < 30 || latitude > 45) {
      invalidCoordinateRows++;
      continue;
    }
    stations.push({observedAt, stationId:fields[1], stationName:fields[2], longitude, latitude,
      stationKind:fields[5], ...(depth >= 0 ? {depthCm:depth} : {})});
  }
  if (!stations.length) throw new Error('KMA snow has no usable data');
  return {requestedAt, stations, ...(invalidCoordinateRows ? {invalidCoordinateRows} : {})};
}

export class KmaSnowObservationProvider {
  constructor(private readonly key: string, private readonly fetcher: typeof fetch = globalThis.fetch) {}

  async getSnapshot(now: Date): Promise<SnowSnapshot> {
    if (!this.key.trim()) throw new Error('KMA APIHub snow key is not configured');
    const requestedAt = snowRequestTime(now);
    const query = new URLSearchParams({sd:'tot', tm:requestedAt, snow:'0', help:'1', authKey:this.key.trim()});
    const response = await this.fetcher(`https://apihub.kma.go.kr/api/typ01/url/kma_snow1.php?${query}`,
      {signal:AbortSignal.timeout(30_000)});
    if (!response.ok) throw new Error(`KMA snow request status ${response.status}`);
    const bytes = await response.arrayBuffer();
    if (bytes.byteLength > SNOW_RESPONSE_MAX_BYTES) throw new Error('KMA snow response size invalid');
    let text: string;
    try { text = new TextDecoder('utf-8', {fatal:true,ignoreBOM:false}).decode(bytes); }
    catch { text = new TextDecoder('euc-kr', {fatal:true,ignoreBOM:false}).decode(bytes); }
    return parseSnowSnapshot(text, requestedAt, now);
  }
}

export function snowStationIsFresh(station: SnowStation, now: Date): boolean {
  const age = now.getTime() - Date.parse(station.observedAt);
  return Number.isFinite(age) && age >= 0 && age <= SNOW_MAX_AGE_MS &&
    typeof station.depthCm === 'number' && Number.isFinite(station.depthCm) && station.depthCm >= 0 && station.depthCm <= 1000 &&
    Number.isFinite(station.latitude) && station.latitude >= 30 && station.latitude <= 45 &&
    Number.isFinite(station.longitude) && station.longitude >= 120 && station.longitude <= 135;
}
