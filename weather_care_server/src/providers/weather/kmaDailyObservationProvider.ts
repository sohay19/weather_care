import {
  kmaApiHubErrorReason,
  kmaApiHubErrorStatus,
} from '../kmaApiHubResponse';
import { DailyWeatherForecast } from './weatherProvider';
import { providerHttpFailureMessage } from '../providerHttpFailure';

const DAILY_OBSERVATION_URL =
  'https://apihub.kma.go.kr/api/typ01/url/sfc_aws_day.php';
const MAX_RANGE_DAYS = 7;

type DailyMetric = 'ta_min' | 'ta_max' | 'rn_day' | 'sd_day_max';
type Availability = 'AVAILABLE' | 'NO_RECORD' | 'UNAVAILABLE';
const DAILY_METRICS = ['ta_min','ta_max','rn_day','sd_day_max'] as const;
const METRIC_FIELDS = {ta_min:'minTemperature',ta_max:'maxTemperature',rn_day:'precipitationAmount',sd_day_max:'snowfallAmount'} as const;

export interface KmaDailyObservationRow {
  date: string;
  stationId: string;
  longitude: number;
  latitude: number;
  value: number;
}

interface KmaDailyObservationProviderOptions {
  serviceKey: string;
  fetcher?: typeof fetch;
  timeoutMs?: number;
}

export interface StationDay {
  date: string;
  stationId: string;
  latitude: number;
  longitude: number;
  minTemperature?: number;
  maxTemperature?: number;
  precipitationAmount?: number;
  snowfallAmount?: number;
}

export class KmaDailyObservationProviderError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'KmaDailyObservationProviderError';
  }
}

export class KmaDailyObservationProvider {
  private readonly serviceKey: string;
  private readonly fetcher: typeof fetch;
  private readonly timeoutMs: number;

  constructor(options: KmaDailyObservationProviderOptions) {
    this.serviceKey = normalizeServiceKey(options.serviceKey);
    this.fetcher =
      options.fetcher ?? ((input, init) => globalThis.fetch(input, init));
    this.timeoutMs = options.timeoutMs ?? 30_000;
  }

  async getDailyByLocation(
    latitude: number,
    longitude: number,
    startDate: string,
    endDate: string,
  ): Promise<DailyWeatherForecast[]> {
    const result = await this.getDailyByLocations(
      [{ latitude, longitude }],
      startDate,
      endDate,
    );
    return result[0] ?? [];
  }

  async getDailyByLocations(
    locations: readonly { latitude: number; longitude: number }[],
    startDate: string,
    endDate: string,
  ): Promise<DailyWeatherForecast[][]> {
    for (const location of locations) {
      validateLocation(location.latitude, location.longitude);
    }
    validateDateRange(startDate, endDate);
    if (!this.serviceKey) {
      throw new KmaDailyObservationProviderError(
        'KMA APIHub service key is not configured',
      );
    }
    if (locations.length === 0) return [];

    const snapshot = await this.getNationwide(startDate, endDate);
    return dailyObservationsAtLocations(snapshot, locations, startDate, endDate);
  }

  async getNationwide(startDate: string, endDate: string, seed?: NationwideDailySnapshot): Promise<NationwideDailySnapshot> {
    validateDateRange(startDate, endDate);
    if (!this.serviceKey) throw new KmaDailyObservationProviderError('KMA APIHub key is not configured');
    const metrics = await Promise.allSettled(
      DAILY_METRICS.map(async (metric) => {
        const reused = seed && calendarDates(startDate,endDate).every(date =>
          seed.metricAvailability?.[date]?.[metric] && seed.metricAvailability[date][metric] !== 'UNAVAILABLE');
        const rows = reused ? seed.stations.filter(station => station.date >= startDate && station.date <= endDate &&
          station[METRIC_FIELDS[metric]] !== undefined).map(station => ({ date:station.date,stationId:station.stationId,
          latitude:station.latitude,longitude:station.longitude,value:station[METRIC_FIELDS[metric]]! }))
          : await this.fetchMetric(metric, startDate, endDate);
        return {metric,rows};
      }),
    );
    const available = metrics.flatMap((result) =>
      result.status === 'fulfilled' ? [result.value] : [],
    );
    if (available.length === 0) {
      const firstFailure = metrics.find(
        (result): result is PromiseRejectedResult => result.status === 'rejected',
      );
      throw new KmaDailyObservationProviderError(
        firstFailure?.reason instanceof Error
          ? firstFailure.reason.message
          : 'KMA daily observation is unavailable',
      );
    }
    const snowfallMetricAvailable = available.some(
      ({ metric }) => metric === 'sd_day_max',
    );

    const byStationDay = new Map<string, StationDay>();
    for (const { metric, rows } of available) {
      for (const row of rows) {
        const key = `${row.date}:${row.stationId}`;
        const station = byStationDay.get(key) ?? {
          date: row.date,
          stationId: row.stationId,
          latitude: row.latitude,
          longitude: row.longitude,
        };
        if (metric === 'ta_min' && validTemperature(row.value)) {
          station.minTemperature = row.value;
        } else if (metric === 'ta_max' && validTemperature(row.value)) {
          station.maxTemperature = row.value;
        } else if (metric === 'rn_day' && validAmount(row.value)) {
          station.precipitationAmount = row.value;
        } else if (metric === 'sd_day_max' && validAmount(row.value)) {
          station.snowfallAmount = row.value;
        }
        byStationDay.set(key, station);
      }
    }

    const stations = [...byStationDay.values()];
    if (!stations.length) throw new KmaDailyObservationProviderError('KMA daily observation has no usable station rows');
    const metricAvailability = Object.fromEntries(calendarDates(startDate,endDate).map(date => [date,
      Object.fromEntries(DAILY_METRICS.map(metric => {
        const received = available.find(item => item.metric === metric);
        const hasValue = stations.some(station => station.date === date && station[METRIC_FIELDS[metric]] !== undefined);
        const state:Availability = !received ? 'UNAVAILABLE' : hasValue ? 'AVAILABLE' : 'NO_RECORD';
        console.log(JSON.stringify({event:'daily_observation_metric_availability',date,metric,state,
          validStationCount:stations.filter(station=>station.date===date && station[METRIC_FIELDS[metric]]!==undefined).length}));
        return [metric,state];
      }))]));
    return { stations, snowfallMetricAvailable,metricAvailability,
      completedDates: calendarDates(startDate,endDate).filter(date =>
        ['ta_min','ta_max','rn_day'].every(metric => metricAvailability[date][metric] === 'AVAILABLE') &&
        stations.some(station=>station.date===date && station.minTemperature!==undefined && station.maxTemperature!==undefined)),
      settledDates: calendarDates(startDate,endDate).filter(date =>
        DAILY_METRICS.every(metric => metricAvailability[date][metric] !== 'UNAVAILABLE') &&
        ['ta_min','ta_max','rn_day'].every(metric => metricAvailability[date][metric] === 'AVAILABLE') &&
        stations.some(station=>station.date===date && station.minTemperature!==undefined && station.maxTemperature!==undefined)) };
  }

  private async fetchMetric(
    metric: DailyMetric,
    startDate: string,
    endDate: string,
  ): Promise<KmaDailyObservationRow[]> {
    const query = new URLSearchParams({
      tm1: startDate.replaceAll('-', ''),
      tm2: endDate.replaceAll('-', ''),
      obs: metric,
      stn: '0',
      disp: '1',
      help: '0',
      authKey: this.serviceKey,
    });
    const response = await this.fetcher(`${DAILY_OBSERVATION_URL}?${query}`, {
      headers: { Accept: 'text/plain' },
      signal: AbortSignal.timeout(this.timeoutMs),
      cf: { cacheEverything: true, cacheTtl: 86_400 },
    });
    const bytes = await response.arrayBuffer();
    const utf8 = new TextDecoder().decode(bytes);
    const payload = /^\s*[\[{]/.test(utf8) || /json|utf-8/i.test(response.headers.get('Content-Type') ?? '')
      ? utf8 : new TextDecoder('euc-kr').decode(bytes);
    if (!response.ok) {
      throw new KmaDailyObservationProviderError(
        await providerHttpFailureMessage(
          response,
          'KMA daily observation request',
          payload,
        ),
      );
    }
    return parseKmaDailyObservationRows(payload);
  }
}

export function parseKmaDailyObservationRows(
  payload: string,
): KmaDailyObservationRow[] {
  const apiHubStatus = kmaApiHubErrorStatus(payload);
  if (apiHubStatus !== undefined) {
    const reason = kmaApiHubErrorReason(payload);
    throw new KmaDailyObservationProviderError(
      `KMA daily observation response failed with status ${apiHubStatus}${
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
    const timeIndex = tokens.findIndex((token) => /^\d{8}(?:\d{4})?$/.test(token));
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
    ) {
      return [];
    }
    return [{
      date: `${tokens[timeIndex].slice(0, 4)}-${tokens[timeIndex].slice(4, 6)}-${tokens[timeIndex].slice(6, 8)}`,
      stationId,
      longitude,
      latitude,
      value,
    }];
  });
}

function toDailyForecast(
  station: StationDay,
  distanceKm: number,
  rain: number | undefined,
  snow: number | undefined,
  availability: DailyWeatherForecast['observationAvailability'],
): DailyWeatherForecast {
  const hasRain = rain !== undefined && rain > 0;
  const hasSnow = snow !== undefined && snow > 0;
  const skyCondition = hasRain && hasSnow
    ? '비/눈'
    : hasSnow
      ? '눈'
      : hasRain
        ? '비'
        : rain === 0 && snow === 0
          ? '강수 관측 없음'
          : '하늘 상태 관측 없음';
  return {
    date: station.date.replaceAll('-', ''),
    forecastSource: 'KMA_OBSERVATION',
    historical: true,
    observationStationId: station.stationId,
    observationDistanceKm: Number(distanceKm.toFixed(1)),
    minTemperature: station.minTemperature,
    maxTemperature: station.maxTemperature,
    minTemperatureSource: 'DAILY',
    maxTemperatureSource: 'DAILY',
    snowfallDataAvailable: snow !== undefined,
    observationAvailability: availability,
    weatherDataComplete:
      station.minTemperature !== undefined &&
      station.maxTemperature !== undefined &&
      rain !== undefined,
    precipitationDetail: {
      kind: 'OBSERVATION',
      hours: [],
      observedAmount: rain,
    },
    skyCondition,
    precipitationProbability: 0,
    precipitationAmount: rain ?? 0,
    snowProbability: 0,
    snowfallAmount: snow ?? 0,
  };
}

function nearestMetric(
  stations: StationDay[],
  latitude: number,
  longitude: number,
  value: (station: StationDay) => number | undefined,
): number | undefined {
  return stations
    .flatMap((station) => {
      const metric = value(station);
      return metric === undefined
        ? []
        : [{
            metric,
            distanceMetres: distanceMetres(
              latitude,
              longitude,
              station.latitude,
              station.longitude,
            ),
          }];
    })
    .sort((left, right) => left.distanceMetres - right.distanceMetres)[0]
    ?.metric;
}

function validateDateRange(startDate: string, endDate: string): void {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(startDate) ||
      !/^\d{4}-\d{2}-\d{2}$/.test(endDate)) {
    throw new KmaDailyObservationProviderError('Observation date is invalid');
  }
  const parsedStart = new Date(`${startDate}T00:00:00Z`);
  const parsedEnd = new Date(`${endDate}T00:00:00Z`);
  if (
    !Number.isFinite(parsedStart.getTime()) ||
    !Number.isFinite(parsedEnd.getTime()) ||
    parsedStart.toISOString().slice(0, 10) !== startDate ||
    parsedEnd.toISOString().slice(0, 10) !== endDate
  ) {
    throw new KmaDailyObservationProviderError('Observation date is invalid');
  }
  const dates = calendarDates(startDate, endDate);
  if (dates.length === 0 || dates.length > MAX_RANGE_DAYS) {
    throw new KmaDailyObservationProviderError('Observation date range is invalid');
  }
}

function calendarDates(startDate: string, endDate: string): string[] {
  const start = new Date(`${startDate}T00:00:00Z`);
  const end = new Date(`${endDate}T00:00:00Z`);
  if (!Number.isFinite(start.getTime()) || !Number.isFinite(end.getTime()) || start > end) {
    return [];
  }
  const result: string[] = [];
  for (let cursor = start.getTime(); cursor <= end.getTime(); cursor += 86_400_000) {
    result.push(new Date(cursor).toISOString().slice(0, 10));
    if (result.length > MAX_RANGE_DAYS) break;
  }
  return result;
}

function validTemperature(value: number): boolean {
  return Number.isFinite(value) && value >= -90 && value <= 60;
}

function validAmount(value: number): boolean {
  return Number.isFinite(value) && value >= 0 && value <= 2_000;
}

function validateLocation(latitude: number, longitude: number): void {
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < 30 ||
    latitude > 44 ||
    longitude < 120 ||
    longitude > 134
  ) {
    throw new KmaDailyObservationProviderError(
      'Location is outside the supported Korean observation area',
    );
  }
}

function distanceMetres(
  latitudeA: number,
  longitudeA: number,
  latitudeB: number,
  longitudeB: number,
): number {
  const radians = (degrees: number) => degrees * Math.PI / 180;
  const latitudeDelta = radians(latitudeB - latitudeA);
  const longitudeDelta = radians(longitudeB - longitudeA);
  const startLatitude = radians(latitudeA);
  const endLatitude = radians(latitudeB);
  const haversine = Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(startLatitude) * Math.cos(endLatitude) *
    Math.sin(longitudeDelta / 2) ** 2;
  return 6_371_008.8 * 2 * Math.atan2(Math.sqrt(haversine), Math.sqrt(1 - haversine));
}

function normalizeServiceKey(value: string): string {
  const trimmed = value.trim();
  try {
    return decodeURIComponent(trimmed);
  } catch {
    return trimmed;
  }
}

export interface NationwideDailySnapshot { stations: StationDay[]; snowfallMetricAvailable: boolean; completedDates?: string[];
  settledDates?: string[]; metricAvailability?: Record<string,Partial<Record<DailyMetric,Availability>>> }
export function dailyObservationsAtLocations(snapshot: NationwideDailySnapshot, locations: readonly { latitude: number; longitude: number }[], startDate: string, endDate: string): DailyWeatherForecast[][] {
  return locations.map(({ latitude, longitude }) => {
      const days: DailyWeatherForecast[] = [];
      for (const date of calendarDates(startDate, endDate)) {
        const stationDays = snapshot.stations.filter(
          (station) => station.date === date,
        );
        const candidates = stationDays
          .filter((station) =>
            station.minTemperature !== undefined &&
            station.maxTemperature !== undefined,
          )
          .map((station) => ({
            station,
            distanceKm:
              distanceMetres(
                latitude,
                longitude,
                station.latitude,
                station.longitude,
              ) / 1_000,
          }))
          .sort((left, right) => left.distanceKm - right.distanceKm);
        const nearest = candidates[0];
        const rain = nearestMetric(
          stationDays,
          latitude,
          longitude,
          (station) => station.precipitationAmount,
        );
        // 눈이 기록된 먼 지점을 전국에 확대하지 않고 선택한 기온 관측소의 실측만 사용한다.
        const snow = nearest?.station.snowfallAmount;
        if (nearest) {
          const state = (metric:DailyMetric,value:number|undefined):Availability => value !== undefined ? 'AVAILABLE'
            : snapshot.metricAvailability?.[date]?.[metric] === 'UNAVAILABLE' ? 'UNAVAILABLE'
            : snapshot.metricAvailability?.[date]?.[metric] || metric === 'sd_day_max' && snapshot.snowfallMetricAvailable
              ? 'NO_RECORD' : 'UNAVAILABLE';
          days.push(toDailyForecast(
            nearest.station,
            nearest.distanceKm,
            rain,
            snow,
            { minTemperature:state('ta_min',nearest.station.minTemperature),
              maxTemperature:state('ta_max',nearest.station.maxTemperature),
              precipitationAmount:state('rn_day',rain),snowfallAmount:state('sd_day_max',snow) },
          ));
        }
      }
      return days;
    });
  }
