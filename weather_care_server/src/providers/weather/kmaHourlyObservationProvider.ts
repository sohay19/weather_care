import {
  kmaApiHubErrorReason,
  kmaApiHubErrorStatus,
} from '../kmaApiHubResponse';
import { calculateKmaApparentTemperature } from './kmaWeatherProvider';
import { providerHttpFailureMessage } from '../providerHttpFailure';

const HOURLY_OBSERVATION_URL =
  'https://apihub.kma.go.kr/api/typ01/url/kma_sfctm5.php';
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

type HourlyMetric = 'TA' | 'HM' | 'WS';

export interface KmaHourlyObservationRow {
  observedAt: string;
  stationId: string;
  longitude: number;
  latitude: number;
  value: number;
}

export interface KmaHourlyComparison {
  stationId: string;
  distanceKm: number;
  currentObservedAt: string;
  comparisonObservedAt: string;
  current: {
    temperature: number;
    apparentTemperature?: number;
  };
  comparison: {
    temperature: number;
    apparentTemperature?: number;
  };
}

export interface HourlyComparisonLocation {
  latitude: number;
  longitude: number;
}

interface ProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  timeoutMs?: number;
  now?: () => Date;
}

interface StationHour {
  observedAt: string;
  stationId: string;
  longitude: number;
  latitude: number;
  temperature?: number;
  humidity?: number;
  windSpeed?: number;
}

export class KmaHourlyObservationProviderError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'KmaHourlyObservationProviderError';
  }
}

export class KmaHourlyObservationProvider {
  private readonly serviceKey: string;
  private readonly fetcher: typeof fetch;
  private readonly timeoutMs: number;
  private readonly now: () => Date;

  constructor(options: ProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher =
      options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.timeoutMs = options.timeoutMs ?? 7_500;
    this.now = options.now ?? (() => new Date());
  }

  async getYesterdayComparison(
    latitude: number,
    longitude: number,
  ): Promise<KmaHourlyComparison> {
    const result = await this.getYesterdayComparisons([{ latitude, longitude }]);
    if (!result[0]) {
      throw new KmaHourlyObservationProviderError(
        'No station has both comparison hours',
      );
    }
    return result[0];
  }

  async getYesterdayComparisons(
    locations: readonly HourlyComparisonLocation[],
  ): Promise<Array<KmaHourlyComparison | undefined>> {
    if (!this.serviceKey) {
      throw new KmaHourlyObservationProviderError(
        'KMA APIHub service key is not configured',
      );
    }
    for (const location of locations) {
      if (!Number.isFinite(location.latitude) || !Number.isFinite(location.longitude)) {
        throw new KmaHourlyObservationProviderError('Location is invalid');
      }
    }
    if (locations.length === 0) return [];

    const currentTime = latestCompletedKoreanHour(this.now());
    const comparisonTime = new Date(currentTime.getTime() - 24 * 60 * 60 * 1000);
    const start = formatKmaHour(comparisonTime);
    const end = formatKmaHour(currentTime);
    const metrics = await Promise.allSettled(
      (['TA', 'HM', 'WS'] as const).map(async (metric) => ({
        metric,
        rows: await this.fetchMetric(metric, start, end),
      })),
    );
    const temperatureResult = metrics[0];
    if (temperatureResult.status === 'rejected') {
      throw temperatureResult.reason;
    }

    const stationHours = new Map<string, StationHour>();
    for (const result of metrics) {
      if (result.status !== 'fulfilled') continue;
      for (const row of result.value.rows) {
        if (row.observedAt !== start && row.observedAt !== end) continue;
        const key = `${row.stationId}:${row.observedAt}`;
        const station = stationHours.get(key) ?? {
          observedAt: row.observedAt,
          stationId: row.stationId,
          longitude: row.longitude,
          latitude: row.latitude,
        };
        if (result.value.metric === 'TA' && validTemperature(row.value)) {
          station.temperature = row.value;
        } else if (result.value.metric === 'HM' && validHumidity(row.value)) {
          station.humidity = row.value;
        } else if (result.value.metric === 'WS' && validWindSpeed(row.value)) {
          station.windSpeed = row.value;
        }
        stationHours.set(key, station);
      }
    }

    const currentObservedAt = toKoreanIso(end);
    const comparisonObservedAt = toKoreanIso(start);
    const comparableStations = [...stationHours.values()].filter((station) =>
      station.observedAt === end &&
      station.temperature !== undefined &&
      stationHours.get(`${station.stationId}:${start}`)?.temperature !== undefined,
    );
    return locations.map(({ latitude, longitude }) => {
      const nearest = comparableStations
        .map((station) => ({
          current: station,
          comparison: stationHours.get(`${station.stationId}:${start}`)!,
          distanceKm: distanceKm(
            latitude,
            longitude,
            station.latitude,
            station.longitude,
          ),
        }))
        .sort((left, right) => left.distanceKm - right.distanceKm)[0];
      if (!nearest) return undefined;
      return {
        stationId: nearest.current.stationId,
        distanceKm: Number(nearest.distanceKm.toFixed(1)),
        currentObservedAt,
        comparisonObservedAt,
        current: {
          temperature: nearest.current.temperature!,
          apparentTemperature: apparentTemperature(
            nearest.current,
            currentObservedAt,
          ),
        },
        comparison: {
          temperature: nearest.comparison.temperature!,
          apparentTemperature: apparentTemperature(
            nearest.comparison,
            comparisonObservedAt,
          ),
        },
      };
    });
  }

  private async fetchMetric(
    metric: HourlyMetric,
    start: string,
    end: string,
  ): Promise<KmaHourlyObservationRow[]> {
    const query = new URLSearchParams({
      tm1: start,
      tm2: end,
      obs: metric,
      stn: '0',
      disp: '1',
      help: '0',
      authKey: this.serviceKey,
    });
    const response = await this.fetcher(`${HOURLY_OBSERVATION_URL}?${query}`, {
      headers: { Accept: 'text/plain' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 300 },
    });
    const payload = await response.text();
    if (!response.ok) {
      throw new KmaHourlyObservationProviderError(
        await providerHttpFailureMessage(
          response,
          'KMA hourly observation request',
          payload,
        ),
      );
    }
    return parseKmaHourlyObservationRows(payload);
  }
}

export function parseKmaHourlyObservationRows(
  payload: string,
): KmaHourlyObservationRow[] {
  const apiHubStatus = kmaApiHubErrorStatus(payload);
  if (apiHubStatus !== undefined) {
    const reason = kmaApiHubErrorReason(payload);
    throw new KmaHourlyObservationProviderError(
      `KMA hourly observation response failed with status ${apiHubStatus}${
        reason ? `: ${reason}` : ''
      }`,
    );
  }
  return payload.split(/\r?\n/).flatMap((line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return [];
    const tokens = trimmed.includes(',')
      ? trimmed.split(',').map((token) => token.trim())
      : trimmed.split(/\s+/).filter(Boolean);
    const timeIndex = tokens.findIndex((token) => /^\d{12}$/.test(token));
    if (timeIndex < 0 || tokens.length < timeIndex + 6) return [];
    const stationId = tokens[timeIndex + 1];
    const longitude = Number(tokens[timeIndex + 2]);
    const latitude = Number(tokens[timeIndex + 3]);
    const valueToken = tokens[timeIndex + 5];
    const value = valueToken === '' ? Number.NaN : Number(valueToken);
    if (
      !/^\d{1,4}$/.test(stationId) ||
      !Number.isFinite(longitude) ||
      !Number.isFinite(latitude) ||
      !Number.isFinite(value)
    ) return [];
    return [{
      observedAt: tokens[timeIndex],
      stationId,
      longitude,
      latitude,
      value,
    }];
  });
}

export function latestCompletedKoreanHour(now: Date): Date {
  const effective = new Date(now.getTime() + KST_OFFSET_MS - 90 * 60 * 1000);
  effective.setUTCMinutes(0, 0, 0);
  return effective;
}

function formatKmaHour(koreanClock: Date): string {
  return `${koreanClock.getUTCFullYear()}${String(koreanClock.getUTCMonth() + 1).padStart(2, '0')}${String(koreanClock.getUTCDate()).padStart(2, '0')}${String(koreanClock.getUTCHours()).padStart(2, '0')}00`;
}

function toKoreanIso(value: string): string {
  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}T${value.slice(8, 10)}:${value.slice(10, 12)}:00+09:00`;
}

function apparentTemperature(
  station: StationHour,
  observedAt: string,
): number | undefined {
  const month = Number(observedAt.slice(5, 7));
  if (month >= 5 && month <= 9 && station.humidity === undefined) {
    return undefined;
  }
  if (
    (month >= 10 || month <= 4) &&
    station.temperature! <= 10 &&
    (station.windSpeed === undefined || station.windSpeed < 1.3)
  ) {
    return station.temperature;
  }
  return calculateKmaApparentTemperature(
    station.temperature!,
    station.humidity,
    station.windSpeed,
    observedAt,
  );
}

function validTemperature(value: number): boolean {
  return value >= -80 && value <= 60;
}

function validHumidity(value: number): boolean {
  return value >= 0 && value <= 100;
}

function validWindSpeed(value: number): boolean {
  return value >= 0 && value <= 100;
}

function normalizeServiceKey(value: string): string {
  const trimmed = value.trim();
  if (!trimmed) return '';
  try {
    return decodeURIComponent(trimmed);
  } catch {
    return trimmed;
  }
}

function distanceKm(
  latitude1: number,
  longitude1: number,
  latitude2: number,
  longitude2: number,
): number {
  const radians = Math.PI / 180;
  const latitudeDelta = (latitude2 - latitude1) * radians;
  const longitudeDelta = (longitude2 - longitude1) * radians;
  const left = Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(latitude1 * radians) * Math.cos(latitude2 * radians) *
    Math.sin(longitudeDelta / 2) ** 2;
  return 6_371.0088 * 2 * Math.atan2(Math.sqrt(left), Math.sqrt(1 - left));
}
