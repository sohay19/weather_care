import { calculateKmaApparentTemperature } from './kmaWeatherProvider';

const ULTRA_SHORT_OBSERVATION_URL =
  'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst';
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

export interface UltraShortObservation {
  observedAt: string;
  rainDetected: boolean;
  precipitationAmount?: number;
  precipitationTypeCode?: number;
  temperature?: number;
  humidity?: number;
  windSpeed?: number;
  windDirection?: number;
  provider:
    | 'KMA_APIHUB_GRID_OBSERVATION'
    | 'KMA_AWS_OBSERVATION'
    | 'KMA_ULTRA_SHORT_OBSERVATION';
  sourceLocation?: {
    type: 'GRID' | 'STATION';
    nx?: number;
    ny?: number;
    stationId?: string;
    stationName?: string;
    distanceKm?: number;
    locationMatch: 'EXACT_GRID' | 'NEAREST_STATION';
  };
  qualityFlags?: string[];
}

interface ProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  now?: () => Date;
  timeoutMs?: number;
}

export class KmaUltraShortObservationProvider {
  private readonly serviceKey: string;
  private readonly fetcher: typeof fetch;
  private readonly now: () => Date;
  private readonly timeoutMs: number;

  constructor(options: ProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher = options.fetcher ?? globalThis.fetch.bind(globalThis);
    this.now = options.now ?? (() => new Date());
    this.timeoutMs = options.timeoutMs ?? 7_500;
  }

  async getCurrent(nx: number, ny: number): Promise<UltraShortObservation> {
    const base = latestUltraShortPublishedHour(this.now());
    return this.getAt(nx, ny, base);
  }

  async getAt(
    nx: number,
    ny: number,
    koreanClock: Date,
  ): Promise<UltraShortObservation> {
    if (!this.serviceKey) throw new Error('KMA service key is not configured');
    if (!Number.isInteger(nx) || nx < 1 || nx > 149 ||
        !Number.isInteger(ny) || ny < 1 || ny > 253) {
      throw new Error('KMA ultra-short grid is invalid');
    }
    const query = new URLSearchParams({
      serviceKey: this.serviceKey,
      pageNo: '1',
      numOfRows: '20',
      dataType: 'JSON',
      base_date: formatDate(koreanClock),
      base_time: `${String(koreanClock.getUTCHours()).padStart(2, '0')}00`,
      nx: String(nx),
      ny: String(ny),
    });
    const response = await this.fetcher(`${ULTRA_SHORT_OBSERVATION_URL}?${query}`, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 3_000 },
    });
    if (!response.ok) throw new Error(`KMA ultra-short observation status ${response.status}`);
    const body = await response.json<{
      response?: {
        header?: { resultCode?: string; resultMsg?: string };
        body?: { items?: { item?: Array<{ category?: string; obsrValue?: string | number }> } };
      };
    }>();
    const code = body.response?.header?.resultCode;
    if (code !== '00') {
      throw new Error(`KMA ultra-short observation failed: ${code ?? 'INVALID_RESPONSE'}`);
    }
    const values = new Map(
      (body.response?.body?.items?.item ?? [])
        .filter((item) => item.category)
        .map((item) => [item.category!, Number(item.obsrValue)]),
    );
    const precipitationType = values.get('PTY');
    if (precipitationType === undefined || !Number.isFinite(precipitationType)) {
      throw new Error('KMA ultra-short observation has no PTY');
    }
    return {
      observedAt: ultraShortKoreanIso(koreanClock),
      rainDetected: precipitationType > 0,
      precipitationAmount: finiteOrUndefined(values.get('RN1')),
      temperature: finiteOrUndefined(values.get('T1H')),
      humidity: finiteOrUndefined(values.get('REH')),
      windSpeed: finiteOrUndefined(values.get('WSD')),
      provider: 'KMA_ULTRA_SHORT_OBSERVATION',
    };
  }
}

export function ultraShortApparentTemperature(
  observation: UltraShortObservation,
): number | undefined {
  if (observation.temperature === undefined) return undefined;
  const month = Number(observation.observedAt.slice(5, 7));
  if (month >= 5 && month <= 9 && observation.humidity === undefined) {
    return undefined;
  }
  return calculateKmaApparentTemperature(
    observation.temperature,
    observation.humidity,
    observation.windSpeed,
    observation.observedAt,
  );
}

export function latestUltraShortPublishedHour(now: Date): Date {
  const koreanClock = new Date(now.getTime() + KST_OFFSET_MS - 50 * 60 * 1000);
  koreanClock.setUTCMinutes(0, 0, 0);
  return koreanClock;
}

function formatDate(koreanClock: Date): string {
  return `${koreanClock.getUTCFullYear()}${String(koreanClock.getUTCMonth() + 1).padStart(2, '0')}${String(koreanClock.getUTCDate()).padStart(2, '0')}`;
}

export function ultraShortKoreanIso(koreanClock: Date): string {
  return `${formatDate(koreanClock).slice(0, 4)}-${formatDate(koreanClock).slice(4, 6)}-${formatDate(koreanClock).slice(6, 8)}T${String(koreanClock.getUTCHours()).padStart(2, '0')}:00:00+09:00`;
}

function finiteOrUndefined(value: number | undefined): number | undefined {
  return value !== undefined && Number.isFinite(value) ? value : undefined;
}

function normalizeServiceKey(value: string): string {
  const trimmed = value.trim();
  try {
    return decodeURIComponent(trimmed);
  } catch {
    return trimmed;
  }
}
