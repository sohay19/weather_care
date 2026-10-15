import { kmaApiHubErrorStatus } from '../kmaApiHubResponse';

export interface UvObservationStation {
  stationId: string;
  stationName: string;
  latitude: number;
  longitude: number;
}
export interface UvObservation {
  stationId: string;
  observedAt: string;
  uvIndex?: number;
}
export const UV_OBSERVATION_MAX_BYTES = 32_000;

export function uvObservationRequestTime(now: Date): string {
  const completeSlot = Math.floor((now.getTime() - 600_000) / 600_000) * 600_000;
  return new Date(completeSlot + 9 * 3_600_000).toISOString().replace(/[-:T]/g, '').slice(0, 12);
}

function dataRows(text: string): string[][] {
  const status = kmaApiHubErrorStatus(text);
  if (status !== undefined) throw new Error(`KMA UV request status ${status}`);
  if (!text.includes('#START7777') || !text.includes('#7777END')) {
    throw new Error('KMA UV response incomplete');
  }
  return text.split(/\r?\n/).map(line => line.trim())
    .filter(line => line && !line.startsWith('#')).map(line => line.split(/\s+/));
}

export function parseUvObservationStations(text: string): UvObservationStation[] {
  const ids = new Set<string>();
  const stations = dataRows(text).map(fields => {
    const [stationId, lon, lat] = fields;
    const nameIndex = fields.findIndex((value, index) => index >= 3 && /[가-힣]/.test(value));
    let nameEnd = nameIndex;
    while (nameEnd >= 0 && nameEnd < fields.length && /[가-힣]/.test(fields[nameEnd])) nameEnd++;
    const longitude = Number(lon), latitude = Number(lat);
    if (!/^\d{1,6}$/.test(stationId) || ids.has(stationId) || nameIndex < 0 ||
        !Number.isFinite(longitude) || longitude < 120 || longitude > 135 ||
        !Number.isFinite(latitude) || latitude < 30 || latitude > 45) {
      throw new Error('KMA UV station row invalid');
    }
    ids.add(stationId);
    return { stationId, longitude, latitude, stationName: fields.slice(nameIndex, nameEnd).join(' ') };
  });
  if (!stations.length) throw new Error('KMA UV station list empty');
  return stations;
}

export function parseUvObservations(text: string, now: Date): UvObservation[] {
  const ids = new Set<string>();
  const observations = dataRows(text).map(fields => {
    const [time, stationId] = fields;
    if (fields.length !== 9 || !/^\d{12}$/.test(time) || !/^\d{1,6}$/.test(stationId) ||
        ids.has(stationId) || !fields.slice(2).every(value => /^-?\d+(?:\.\d+)?$/.test(value))) {
      throw new Error('KMA UV observation row invalid');
    }
    const observedAt = `${time.slice(0, 4)}-${time.slice(4, 6)}-${time.slice(6, 8)}T${time.slice(8, 10)}:${time.slice(10, 12)}:00+09:00`;
    const instant = Date.parse(observedAt);
    const normalized = Number.isFinite(instant)
      ? new Date(instant + 9 * 3_600_000).toISOString().replace(/[-:T]/g, '').slice(0, 12) : '';
    if (normalized !== time || instant > now.getTime() || instant % 600_000 !== 0) {
      throw new Error('KMA UV observation time invalid');
    }
    ids.add(stationId);
    // UVB(3열)는 복사량이다. 앱의 지수에는 UV-B(6열)를 사용한다.
    const value = Number(fields[5]);
    return { stationId, observedAt, ...(value >= 0 && value <= 30 ? { uvIndex: value } : {}) };
  });
  if (!observations.length) throw new Error('KMA UV observations empty');
  return observations;
}

export class KmaUvObservationProvider {
  constructor(private readonly key: string, private readonly fetcher: typeof fetch = globalThis.fetch) {}

  private async read(path: string, parameters: Record<string, string>): Promise<string> {
    if (!this.key.trim()) throw new Error('KMA APIHub UV key is not configured');
    const query = new URLSearchParams({ ...parameters, stn: '0', help: '0', authKey: this.key.trim() });
    const response = await this.fetcher(`https://apihub.kma.go.kr/api/typ01/url/${path}?${query}`,
      { signal: AbortSignal.timeout(30_000) });
    if (!response.ok) throw new Error(`KMA UV request status ${response.status}`);
    const bytes = await response.arrayBuffer();
    if (bytes.byteLength > UV_OBSERVATION_MAX_BYTES) throw new Error('KMA UV response too large');
    try { return new TextDecoder('utf-8', { fatal: true, ignoreBOM: false }).decode(bytes); }
    catch { return new TextDecoder('euc-kr', { fatal: true, ignoreBOM: false }).decode(bytes); }
  }

  async getStations(): Promise<UvObservationStation[]> {
    return parseUvObservationStations(await this.read('stn_inf.php', { inf: 'UV' }));
  }
  async getObservations(now: Date): Promise<UvObservation[]> {
    // tm 생략 시 정시 자료가 반환되므로 완료된 직전 10분 슬롯을 명시한다.
    return parseUvObservations(await this.read('kma_sfctm_uv.php', { tm: uvObservationRequestTime(now) }), now);
  }
}
