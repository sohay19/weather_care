import {
  kmaApiHubErrorReason,
  kmaApiHubErrorStatus,
} from '../kmaApiHubResponse';
import { providerHttpFailureMessage } from '../providerHttpFailure';
import type { UltraShortObservation } from './kmaUltraShortObservationProvider';

const AWS_MINUTE_URL =
  'https://apihub.kma.go.kr/api/typ01/cgi-bin/url/nph-aws2_min';
const AWS_STATION_URL =
  'https://apihub.kma.go.kr/api/typ02/openApi/AwsMtlyInfoService/getAwsStnLstTbl';
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
const MAX_AGE_MS = 30 * 60 * 1000;

export interface AwsFallbackLocation {
  latitude: number;
  longitude: number;
}

interface AwsObservationRow {
  observedAt: string;
  stationId: string;
  temperature: number;
  humidity: number;
  windSpeed: number;
  windDirection?: number;
  rainDetected: boolean;
  precipitationAmount?: number;
}

interface AwsStation {
  stationId: string;
  stationName: string;
  latitude: number;
  longitude: number;
}

interface ProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  timeoutMs?: number;
  now?: () => Date;
}

export class KmaAwsMinuteObservationProviderError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'KmaAwsMinuteObservationProviderError';
  }
}

export class KmaAwsMinuteObservationProvider {
  private readonly serviceKey: string;
  private readonly fetcher: typeof fetch;
  private readonly timeoutMs: number;
  private readonly now: () => Date;

  constructor(options: ProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher = options.fetcher ?? globalThis.fetch.bind(globalThis);
    this.timeoutMs = options.timeoutMs ?? 15_000;
    this.now = options.now ?? (() => new Date());
  }

  async getCurrentByLocations(
    locations: readonly AwsFallbackLocation[],
  ): Promise<Array<UltraShortObservation | undefined>> {
    if (!this.serviceKey) {
      throw new KmaAwsMinuteObservationProviderError(
        'KMA APIHub service key is not configured',
      );
    }
    for (const location of locations) validateLocation(location);
    if (locations.length === 0) return [];

    const now = this.now();
    const end = latestAwsQueryTime(now);
    const start = new Date(end.getTime() - 9 * 60 * 1000);
    const [rows, stations] = await Promise.all([
      this.fetchRows(formatKoreanTime(start), formatKoreanTime(end)),
      this.fetchStations(end),
    ]);
    const stationById = new Map(stations.map((station) => [station.stationId, station]));
    const latestByStation = new Map<string, AwsObservationRow>();
    for (const row of rows) {
      const observedInstant = Date.parse(row.observedAt);
      if (
        !stationById.has(row.stationId) ||
        !Number.isFinite(observedInstant) ||
        now.getTime() - observedInstant > MAX_AGE_MS ||
        observedInstant - now.getTime() > 5 * 60 * 1000
      ) continue;
      const previous = latestByStation.get(row.stationId);
      if (!previous || previous.observedAt < row.observedAt) {
        latestByStation.set(row.stationId, row);
      }
    }
    const available = [...latestByStation.values()].map((row) => ({
      row,
      station: stationById.get(row.stationId)!,
    }));

    return locations.map((location) => {
      const nearest = available
        .map((value) => ({
          ...value,
          distanceKm: distanceKm(
            location.latitude,
            location.longitude,
            value.station.latitude,
            value.station.longitude,
          ),
        }))
        .sort((left, right) => left.distanceKm - right.distanceKm)[0];
      if (!nearest) return undefined;
      return {
        observedAt: nearest.row.observedAt,
        rainDetected: nearest.row.rainDetected,
        precipitationAmount: nearest.row.precipitationAmount,
        precipitationTypeCode: nearest.row.rainDetected ? 1 : 0,
        temperature: nearest.row.temperature,
        humidity: nearest.row.humidity,
        windSpeed: nearest.row.windSpeed,
        windDirection: nearest.row.windDirection,
        provider: 'KMA_AWS_OBSERVATION',
        sourceLocation: {
          type: 'STATION',
          stationId: nearest.station.stationId,
          stationName: nearest.station.stationName,
          distanceKm: roundOne(nearest.distanceKm),
          locationMatch: 'NEAREST_STATION',
        },
        qualityFlags: ['LOCATION_FALLBACK'],
      } satisfies UltraShortObservation;
    });
  }

  private async fetchRows(start: string, end: string): Promise<AwsObservationRow[]> {
    const query = new URLSearchParams({
      tm1: start,
      tm2: end,
      stn: '0',
      disp: '1',
      help: '0',
      authKey: this.serviceKey,
    });
    const response = await this.fetcher(`${AWS_MINUTE_URL}?${query}`, {
      headers: { Accept: 'text/plain' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 120 },
    });
    const payload = await response.text();
    if (!response.ok) {
      throw new KmaAwsMinuteObservationProviderError(
        await providerHttpFailureMessage(response, 'KMA AWS minute request', payload),
      );
    }
    return parseKmaAwsMinuteRows(payload);
  }

  private async fetchStations(koreanClock: Date): Promise<AwsStation[]> {
    for (const candidate of stationPublicationMonths(koreanClock)) {
      const stations = await this.fetchStationMonth(candidate);
      if (stations.length > 0) return stations;
    }
    throw new KmaAwsMinuteObservationProviderError(
      'KMA AWS station response has no usable stations',
    );
  }

  private async fetchStationMonth(koreanClock: Date): Promise<AwsStation[]> {
    const query = new URLSearchParams({
      pageNo: '1',
      numOfRows: '1000',
      dataType: 'JSON',
      year: String(koreanClock.getUTCFullYear()),
      month: String(koreanClock.getUTCMonth() + 1).padStart(2, '0'),
      authKey: this.serviceKey,
    });
    const response = await this.fetcher(`${AWS_STATION_URL}?${query}`, {
      headers: { Accept: 'application/json' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 86_400 },
    });
    const payload = await response.text();
    if (!response.ok) {
      throw new KmaAwsMinuteObservationProviderError(
        await providerHttpFailureMessage(response, 'KMA AWS station request', payload),
      );
    }
    return parseKmaAwsStations(payload);
  }
}

export function parseKmaAwsMinuteRows(payload: string): AwsObservationRow[] {
  const apiHubStatus = kmaApiHubErrorStatus(payload);
  if (apiHubStatus !== undefined) {
    const reason = kmaApiHubErrorReason(payload);
    throw new KmaAwsMinuteObservationProviderError(
      `KMA AWS minute response failed with status ${apiHubStatus}${
        reason ? `: ${reason}` : ''
      }`,
    );
  }
  const lines = payload.split(/\r?\n/);
  const header = lines
    .filter((line) => line.trim().startsWith('#'))
    .map((line) => splitTokens(line.replace(/^\s*#+\s*/, '')))
    .find((tokens) =>
      findColumn(tokens, ['TM', 'YYMMDDHHMI']) >= 0 &&
      findColumn(tokens, ['STN', 'STN_ID']) >= 0 &&
      findColumn(tokens, ['TA']) >= 0 &&
      findColumn(tokens, ['HM']) >= 0 &&
      findColumn(tokens, ['WS', 'WS1', 'WS_1', 'WS_10M']) >= 0,
    );
  if (!header) {
    throw new KmaAwsMinuteObservationProviderError(
      'KMA AWS minute response has no usable header',
    );
  }
  const columns = {
    time: findColumn(header, ['TM', 'YYMMDDHHMI']),
    station: findColumn(header, ['STN', 'STN_ID']),
    temperature: findColumn(header, ['TA']),
    humidity: findColumn(header, ['HM']),
    windSpeed: findColumn(header, ['WS', 'WS1', 'WS_1', 'WS_10M']),
    windDirection: findColumn(header, ['WD', 'WD1', 'WD_1', 'WD_10M']),
    rainFlag: findColumn(header, ['RE', 'RN_OX']),
    precipitation: findColumn(header, ['RN_60M', 'RN_HR1', 'RN_1H']),
  };
  return lines.flatMap((line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return [];
    const tokens = splitTokens(trimmed);
    const compactTime = tokens[columns.time];
    const stationId = tokens[columns.station];
    const temperature = numericValue(tokens[columns.temperature]);
    const humidity = numericValue(tokens[columns.humidity]);
    const windSpeed = numericValue(tokens[columns.windSpeed]);
    if (
      !/^\d{12}$/.test(compactTime ?? '') ||
      !/^\d{1,4}$/.test(stationId ?? '') ||
      !validTemperature(temperature) ||
      !validHumidity(humidity) ||
      !validWindSpeed(windSpeed)
    ) return [];
    const windDirection = numericValue(tokens[columns.windDirection]);
    const rainFlag = numericValue(tokens[columns.rainFlag]);
    const precipitation = numericValue(tokens[columns.precipitation]);
    return [{
      observedAt: compactKoreanTimeToIso(compactTime),
      stationId,
      temperature,
      humidity,
      windSpeed,
      windDirection: validWindDirection(windDirection) ? windDirection : undefined,
      rainDetected: (rainFlag !== undefined && rainFlag > 0) ||
        (validPrecipitation(precipitation) && precipitation > 0),
      precipitationAmount: validPrecipitation(precipitation)
        ? precipitation
        : undefined,
    }];
  });
}

export function parseKmaAwsStations(payload: string): AwsStation[] {
  let body: unknown;
  try {
    body = JSON.parse(payload);
  } catch {
    throw new KmaAwsMinuteObservationProviderError(
      'KMA AWS station response is not valid JSON',
    );
  }
  const response = body as {
    response?: {
      header?: { resultCode?: string; resultMsg?: string };
      body?: { items?: { item?: unknown } };
    };
  };
  const code = response.response?.header?.resultCode;
  const message = response.response?.header?.resultMsg ?? '';
  if (code === '99' && message.includes('발간되지 않은 기간')) return [];
  if (code !== '00' && code !== '0000') {
    throw new KmaAwsMinuteObservationProviderError(
      `KMA AWS station response failed: ${code ?? 'INVALID_RESPONSE'}`,
    );
  }
  const raw = response.response?.body?.items?.item;
  const containers = Array.isArray(raw) ? raw : raw ? [raw] : [];
  const items = containers.flatMap((value) => {
    if (!value || typeof value !== 'object') return [];
    const info = (value as { stn_aws?: { info?: unknown } }).stn_aws?.info;
    return Array.isArray(info) ? info : [value];
  });
  return items.flatMap((value) => {
    const item = value as Record<string, unknown>;
    const stationId = String(item.stn_id ?? item.stnId ?? '').trim();
    const stationName = String(item.stn_ko ?? item.stnKo ?? '').trim();
    const latitude = Number(item.lat);
    const longitude = Number(item.lon);
    return /^\d{1,4}$/.test(stationId) && stationName &&
        Number.isFinite(latitude) && Number.isFinite(longitude)
      ? [{ stationId, stationName, latitude, longitude }]
      : [];
  });
}

function stationPublicationMonths(koreanClock: Date): Date[] {
  const firstDay = Date.UTC(
    koreanClock.getUTCFullYear(),
    koreanClock.getUTCMonth(),
    1,
  );
  return Array.from({ length: 13 }, (_, monthsAgo) => {
    const candidate = new Date(firstDay);
    candidate.setUTCMonth(candidate.getUTCMonth() - monthsAgo);
    return candidate;
  });
}

function latestAwsQueryTime(now: Date): Date {
  const koreanClock = new Date(now.getTime() + KST_OFFSET_MS - 2 * 60 * 1000);
  koreanClock.setUTCSeconds(0, 0);
  return koreanClock;
}

function formatKoreanTime(koreanClock: Date): string {
  return `${koreanClock.getUTCFullYear()}${String(koreanClock.getUTCMonth() + 1).padStart(2, '0')}${String(koreanClock.getUTCDate()).padStart(2, '0')}${String(koreanClock.getUTCHours()).padStart(2, '0')}${String(koreanClock.getUTCMinutes()).padStart(2, '0')}`;
}

function compactKoreanTimeToIso(value: string): string {
  return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}T${value.slice(8, 10)}:${value.slice(10, 12)}:00+09:00`;
}

function splitTokens(line: string): string[] {
  return (line.includes(',') ? line.split(',') : line.split(/\s+/))
    .map((token) => token.trim())
    .filter(Boolean);
}

function normalizeColumn(value: string): string {
  return value.trim().toUpperCase().replace(/[^A-Z0-9]+/g, '_');
}

function findColumn(columns: string[], aliases: string[]): number {
  const normalized = columns.map(normalizeColumn);
  return aliases.map(normalizeColumn).reduce(
    (found, alias) => found >= 0 ? found : normalized.indexOf(alias),
    -1,
  );
}

function numericValue(value: string | undefined): number | undefined {
  if (value === undefined || value === '') return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > -900 ? parsed : undefined;
}

function validTemperature(value: number | undefined): value is number {
  return value !== undefined && value >= -80 && value <= 60;
}

function validHumidity(value: number | undefined): value is number {
  return value !== undefined && value >= 0 && value <= 100;
}

function validWindSpeed(value: number | undefined): value is number {
  return value !== undefined && value >= 0 && value <= 100;
}

function validWindDirection(value: number | undefined): value is number {
  return value !== undefined && value >= 0 && value <= 360;
}

function validPrecipitation(value: number | undefined): value is number {
  return value !== undefined && value >= 0 && value <= 500;
}

function validateLocation(location: AwsFallbackLocation): void {
  if (
    !Number.isFinite(location.latitude) ||
    !Number.isFinite(location.longitude) ||
    location.latitude < 30 || location.latitude > 45 ||
    location.longitude < 120 || location.longitude > 135
  ) {
    throw new KmaAwsMinuteObservationProviderError('Location is invalid');
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

function roundOne(value: number): number {
  return Math.round(value * 10) / 10;
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
