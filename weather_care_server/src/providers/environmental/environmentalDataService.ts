import {
  getEnvironmentalCache,
  saveEnvironmentalCache,
} from '../../database/environmentalCacheRepository';
import { RegionMetadata } from '../../regions/regionCatalog';
import {
  EnvironmentalSourceState,
  EnvironmentalSourceStatus,
  ServerEnv,
  WeatherSnapshot,
} from '../../types';
import {
  AirKoreaAirQualityProvider, AirStationCatalog, airStationCatalogSchema,
  isRecentAirObservation, nearestAirStations,
} from '../air/airKoreaAirQualityProvider';
import { AirQualitySnapshot } from '../air/airQualityProvider';
import { WeatherForecast } from '../weather/weatherProvider';
import { KmaUvProvider } from '../uv/kmaUvProvider';
import { UvForecast } from '../uv/uvProvider';
import { providerErrorDiagnostic } from '../../observability/providerErrorDiagnostics';
import { uvAreaNoForGrid } from '../../regions/kmaUvAreaGridCatalog';
import { kmaGridCoordinates } from '../../regions/kmaGridCoordinates';
import { collectedCacheKey, getCollectedCache } from '../../database/collectedWeatherRepository';
import { administrativeAreaForLocation, type NationwideLocation } from '../../regions/nationwideLocation';
import { resolveSavedLocation } from '../../regions/resolvedLocation';

const UV_FRESH_MS = 3 * 60 * 60 * 1000;
const UV_MAX_STALE_MS = 8 * 60 * 60 * 1000;
const AIR_FRESH_MS = 60 * 60 * 1000;
const AIR_MAX_STALE_MS = 3 * 60 * 60 * 1000;
const AIR_STATIONS_FRESH_MS = 24 * 60 * 60 * 1000;

export interface EnvironmentalDataBundle {
  uv?: UvForecast;
  airQuality?: AirQualitySnapshot;
  providerTimeouts?: {
    uv: boolean;
    airQuality: boolean;
  };
  sources: {
    uv: EnvironmentalSourceStatus;
    airQuality: EnvironmentalSourceStatus;
  };
}

interface EnvironmentalLoadOptions {
  now?: Date;
  nx?: number;
  ny?: number;
  coordinates?: { latitude: number; longitude: number };
  providerTimeoutMs?: number;
  uvFreshMs?: number;
  nationwideAir?: NationwideAirQualitySnapshot | null;
}

export interface NationwideAirQualitySnapshot {
  catalog: AirStationCatalog;
  observations: AirQualitySnapshot[];
  collectedAt: string;
}

export function nearestNationwideAirQuality(
  snapshot: NationwideAirQualitySnapshot,
  latitude: number,
  longitude: number,
  now = new Date(),
): AirQualitySnapshot | undefined {
  const observations = new Map(snapshot.observations.map((item) => [item.stationName, item]));
  const nearby = nearestAirStations(snapshot.catalog, latitude, longitude)
    .map((station) => observations.get(station.stationName))
    .filter((item): item is AirQualitySnapshot =>
      !!item && isRecentAirObservation(item.observedAt, now) &&
      now.getTime()-Date.parse(item.observedAt) >= 0 && now.getTime()-Date.parse(item.observedAt) <= AIR_MAX_STALE_MS);
  return nearby.find((item) =>
    [item.pm10, item.pm25, item.ozone].every((value) => Number.isFinite(value))) ?? nearby[0];
}

// 요청 중에는 제공처를 호출하지 않고, 수집된 원본의 실제 시각을 기준으로 판정한다.
export function currentEnvironmentalData(
  bundle: EnvironmentalDataBundle,
  now = new Date(),
  nationwideAir?: NationwideAirQualitySnapshot,
  coordinates?: { latitude: number; longitude: number },
): EnvironmentalDataBundle {
  const result: EnvironmentalDataBundle = { ...bundle, sources: { ...bundle.sources } };
  if (nationwideAir && coordinates &&
      ageMs(nationwideAir.collectedAt, now) <= AIR_MAX_STALE_MS) {
    const observation = nearestNationwideAirQuality(
      nationwideAir, coordinates.latitude, coordinates.longitude, now,
    );
    if (observation) {
      result.airQuality = observation;
      result.sources.airQuality = availableSource(
        'AIRKOREA', 'CACHED', observation.observedAt, nationwideAir.collectedAt,
      );
    }
  }
  for (const type of ['uv', 'airQuality'] as const) {
    const source = result.sources[type];
    const value = result[type];
    if (source.state === 'UNSUPPORTED_REGION') {
      if (type === 'uv') result.uv = undefined;
      else result.airQuality = undefined;
      continue;
    }
    const observedAt = type === 'uv' ? result.uv?.issuedAt : result.airQuality?.observedAt;
    const maxAge = type === 'uv' ? UV_MAX_STALE_MS : AIR_MAX_STALE_MS;
    if (!value || !observedAt || !Number.isFinite(Date.parse(observedAt)) ||
        !source.cachedAt || ageMs(source.cachedAt, now) > maxAge ||
        (type === 'uv' ? ageMs(observedAt, now) > UV_MAX_STALE_MS
          : !isRecentAirObservation(observedAt, now)) ||
        source.state === 'UNAVAILABLE') {
      if (type === 'uv') result.uv = undefined;
      else result.airQuality = undefined;
      result.sources[type] = unavailableSource(source.provider, source.reason);
    } else if (ageMs(source.cachedAt, now) > (type === 'uv' ? UV_FRESH_MS : AIR_FRESH_MS) ||
               (type === 'airQuality' && ageMs(observedAt, now) > 2 * AIR_FRESH_MS)) {
      result.sources[type] = { ...source, state: 'STALE', observedAt };
    }
  }
  return result;
}

export function environmentalDataIssues(
  bundle: EnvironmentalDataBundle,
  now = new Date(),
): string[] {
  const current = currentEnvironmentalData(bundle, now);
  const issues: string[] = [];
  if (!current.uv || uvForTime(current.uv, now.toISOString()) === undefined) issues.push('UV');
  for (const [name, value] of [
    ['PM10', current.airQuality?.pm10], ['PM25', current.airQuality?.pm25],
    ['O3', current.airQuality?.ozone],
  ] as const) {
    if (!Number.isFinite(value)) issues.push(name);
  }
  return issues;
}

export async function readCollectedEnvironmentalData(
  db: D1Database | undefined,
  nx: number,
  ny: number,
  fallback: EnvironmentalDataBundle,
  now = new Date(),
  coordinates = kmaGridCoordinates(nx, ny),
  location: NationwideLocation = { nx, ny },
): Promise<EnvironmentalDataBundle> {
  location = await resolveSavedLocation(db, location, now);
  const [environmental, nationwide, nationwideUv] = await Promise.all([
    getCollectedCache<EnvironmentalDataBundle>(db, collectedCacheKey.environmental(nx, ny)),
    getCollectedCache<NationwideAirQualitySnapshot>(db, collectedCacheKey.nationwideAir),
    getCollectedCache<{ forecasts: Record<string, UvForecast> }>(db, 'COLLECTED_NATIONWIDE_UV'),
  ]);
  let base = environmental?.status === 'AVAILABLE' ? environmental.value : fallback;
  const area = administrativeAreaForLocation(location);
  if (base.uv && ((area && base.uv.areaNo !== area[0]) || (!area && location.boundaryChecked))) {
    base = { ...base, uv: undefined, sources: { ...base.sources, uv: unavailableSource('KMA_LIVING_INDEX_V5') } };
  }
  if (nationwideUv?.status === 'AVAILABLE') {
    const uv = area ? nationwideUv.value.forecasts[area[0]] : undefined;
    base = { ...base, uv, sources: { ...base.sources,
      uv: uv ? availableSource('KMA_LIVING_INDEX_V5', 'CACHED', uv.issuedAt, nationwideUv.updatedAt)
        : unavailableSource('KMA_LIVING_INDEX_V5', area ? 'UPSTREAM_AREA_MISSING'
          : location.boundaryChecked && !location.coordinates ? 'LOCATION_COORDINATES_REQUIRED' : 'LOCATION_UNRESOLVED') } };
    if (!area) console.warn(JSON.stringify({ event: 'weather_location_unresolved',
      hasRegionName: Boolean(location.regionName), hasAdminCode: Boolean(location.adminCode),
      hasCoordinates: Boolean(location.coordinates),
      reason: location.boundaryChecked && !location.coordinates ? 'LOCATION_COORDINATES_REQUIRED'
        : location.regionName || location.adminCode ? 'IDENTITY_NOT_MATCHED' : 'IDENTITY_MISSING' }));
  }
  return currentEnvironmentalData(
    base,
    now,
    nationwide?.status === 'AVAILABLE' ? nationwide.value : undefined,
    coordinates,
  );
}

interface ResolveOptions<T> {
  db?: D1Database;
  cacheKey: string;
  cacheType: 'UV' | 'AIR_QUALITY' | 'AIR_STATIONS';
  nx: number;
  ny: number;
  provider: string;
  freshMs: number;
  maxStaleMs: number;
  observedAt: (value: T) => string;
  load: () => Promise<T>;
  now: Date;
  usableCachedValue?: (value: T) => boolean;
}

interface ResolvedValue<T> {
  value?: T;
  source: EnvironmentalSourceStatus;
}

export async function loadEnvironmentalData(
  env: ServerEnv,
  region: RegionMetadata | undefined,
  options: EnvironmentalLoadOptions = {},
): Promise<EnvironmentalDataBundle> {
  const now = options.now ?? new Date();
  const serviceKey = env.KMA_SERVICE_KEY;
  const nx = options.nx ?? region?.nx;
  const ny = options.ny ?? region?.ny;
  const uvAreaNo =
    nx === undefined || ny === undefined
      ? undefined
      : uvAreaNoForGrid(nx, ny);
  const uvPromise =
    uvAreaNo !== undefined && nx !== undefined && ny !== undefined
      ? resolveEnvironmentalValue<UvForecast>({
          db: env.DB,
          cacheKey: `UV_${nx}_${ny}`,
          cacheType: 'UV',
          nx,
          ny,
          provider: 'KMA_LIVING_INDEX_V5',
          freshMs: options.uvFreshMs ?? UV_FRESH_MS,
          maxStaleMs: UV_MAX_STALE_MS,
          observedAt: (value) => value.issuedAt,
          load: () =>
            new KmaUvProvider({
              serviceKey,
              now: () => now,
              timeoutMs: options.providerTimeoutMs,
            }).getForecast(uvAreaNo),
          now,
        })
      : Promise.resolve<ResolvedValue<UvForecast>>({
          source: unsupportedSource('KMA_LIVING_INDEX_V5'),
        });
  const airQualityPromise = options.nationwideAir !== undefined
    ? Promise.resolve<ResolvedValue<AirQualitySnapshot>>((() => {
        const coordinates = options.coordinates ??
          (nx !== undefined && ny !== undefined ? kmaGridCoordinates(nx, ny) : undefined);
        const value = coordinates && options.nationwideAir
          ? nearestNationwideAirQuality(
              options.nationwideAir, coordinates.latitude, coordinates.longitude, now,
            )
          : undefined;
        return value && options.nationwideAir
          ? { value, source: availableSource(
              'AIRKOREA', 'CACHED', value.observedAt, options.nationwideAir.collectedAt,
            ) }
          : { source: unavailableSource('AIRKOREA') };
      })())
    :
    nx !== undefined && ny !== undefined && kmaGridCoordinates(nx, ny)
      ? loadAirQuality(
          env,
          nx,
          ny,
          options.coordinates,
          now,
          options.providerTimeoutMs,
        )
      : Promise.resolve<ResolvedValue<AirQualitySnapshot>>({
          source: unsupportedSource('AIRKOREA'),
        });
  const [uv, airQuality] = await Promise.all([
    settleEnvironmentalWithin(
      uvPromise,
      'KMA_LIVING_INDEX_V5',
      options.providerTimeoutMs,
    ),
    settleEnvironmentalWithin(
      airQualityPromise,
      'AIRKOREA',
      options.providerTimeoutMs,
    ),
  ]);

  return {
    uv: uv.value,
    airQuality: airQuality.value,
    providerTimeouts: {
      uv: uv.timedOut,
      airQuality: airQuality.timedOut,
    },
    sources: {
      uv: uv.source,
      airQuality: airQuality.source,
    },
  };
}

async function settleEnvironmentalWithin<T>(
  promise: Promise<ResolvedValue<T>>,
  provider: string,
  timeoutMs: number | undefined,
): Promise<ResolvedValue<T> & { timedOut: boolean }> {
  if (timeoutMs === undefined) {
    return { ...(await promise), timedOut: false };
  }
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      promise.then((value) => ({ ...value, timedOut: false })),
      new Promise<ResolvedValue<T> & { timedOut: boolean }>((resolve) => {
        timeoutId = setTimeout(
          () => resolve({ source: unavailableSource(provider), timedOut: true }),
          timeoutMs,
        );
      }),
    ]);
  } finally {
    if (timeoutId !== undefined) clearTimeout(timeoutId);
  }
}

async function loadAirQuality(
  env: ServerEnv,
  nx: number,
  ny: number,
  coordinates: EnvironmentalLoadOptions['coordinates'],
  now: Date,
  providerTimeoutMs?: number,
): Promise<ResolvedValue<AirQualitySnapshot>> {
  const unavailable: ResolvedValue<AirQualitySnapshot> = {
    source: { provider: 'AIRKOREA', state: 'UNAVAILABLE', reason: 'PROVIDER_UNAVAILABLE' },
  };
  const target = coordinates ?? kmaGridCoordinates(nx, ny);
  if (!target) return unavailable;
  const signal = AbortSignal.timeout(
    Math.min(6_000, providerTimeoutMs ?? 6_000),
  );
  const provider = new AirKoreaAirQualityProvider({
    serviceKey: env.KMA_SERVICE_KEY,
    now: () => now,
    signal,
  });
  // One validated national catalog shared across grids; never cache portal error bodies.
  // Coordinates here belong to official stations, not to an installation/user.
  const catalog = await resolveEnvironmentalValue<AirStationCatalog>({
    db: env.DB, cacheKey: 'AIR_STATIONS_V1', cacheType: 'AIR_STATIONS', nx: 0, ny: 0,
    provider: 'AIRKOREA', freshMs: AIR_STATIONS_FRESH_MS, maxStaleMs: AIR_STATIONS_FRESH_MS,
    observedAt: (value) => value.fetchedAt,
    usableCachedValue: (value) => airStationCatalogSchema.safeParse(value).success,
    load: () => provider.getStationCatalog(), now,
  });
  if (!catalog.value) return unavailable;

  try {
    for (const station of nearestAirStations(catalog.value, target.latitude, target.longitude)) {
      if (signal.aborted) {
        if (!env.DB) break;
        try {
          const cached = await getEnvironmentalCache<AirQualitySnapshot>(
            env.DB, `AIR_STATION_V1_${station.stationName}`,
          );
          if (cached && cached.value.stationName === station.stationName &&
              isRecentAirObservation(cached.value.observedAt, now) &&
              ageMs(cached.updatedAt, now) <= AIR_MAX_STALE_MS) {
            return {
              value: cached.value,
              source: availableSource(
                'AIRKOREA',
                ageMs(cached.updatedAt, now) <= AIR_FRESH_MS ? 'CACHED' : 'STALE',
                cached.value.observedAt,
                cached.updatedAt,
              ),
            };
          }
        } catch (error) {
          logEnvironmentalError('cache_read_failed', 'AIRKOREA', error);
        }
        continue;
      }
      const observation = await resolveEnvironmentalValue<AirQualitySnapshot>({
        db: env.DB, cacheKey: `AIR_STATION_V1_${station.stationName}`,
        cacheType: 'AIR_QUALITY', nx, ny, provider: 'AIRKOREA',
        freshMs: AIR_FRESH_MS, maxStaleMs: AIR_MAX_STALE_MS,
        observedAt: (value) => value.observedAt,
        usableCachedValue: (value) => value?.stationName === station.stationName &&
          isRecentAirObservation(value.observedAt, now),
        load: () => provider.getByStation(station.stationName), now,
      });
      if (observation.value) return observation;
    }
  } catch (error) {
    logEnvironmentalError('provider_failed', 'AIRKOREA', error);
  }
  return unavailable;
}

export function enrichForecastWithEnvironmentalData(
  forecast: WeatherForecast,
  bundle: EnvironmentalDataBundle,
): WeatherForecast {
  const hourly = forecast.hourly.map((snapshot, index) => {
    const uvIndex = uvForTime(bundle.uv, snapshot.forecastAt ?? snapshot.observedAt);
    const airQuality = index === 0 ? bundle.airQuality : undefined;
    return enrichSnapshot(snapshot, uvIndex, airQuality, bundle, index === 0);
  });
  const enrichedHourlyByTime = new Map(
    hourly.map((snapshot) => [
      snapshot.forecastAt ?? snapshot.observedAt,
      snapshot,
    ]),
  );
  const timelineHourly = forecast.timelineHourly?.map((snapshot) =>
    enrichedHourlyByTime.get(snapshot.forecastAt ?? snapshot.observedAt) ??
    enrichSnapshot(
      snapshot,
      uvForTime(bundle.uv, snapshot.forecastAt ?? snapshot.observedAt),
      undefined,
      bundle,
      false,
    ),
  );
  const first = hourly[0];
  const current = first
    ? {
        ...first,
        minTemperature: forecast.current.minTemperature,
        maxTemperature: forecast.current.maxTemperature,
      }
    : enrichSnapshot(
        forecast.current,
        uvForTime(
          bundle.uv,
          forecast.current.forecastAt ?? forecast.current.observedAt,
        ),
        bundle.airQuality,
        bundle,
        true,
      );

  return {
    ...forecast,
    current,
    hourly,
    timelineHourly,
    dataSource: dataSourceLabel(forecast.dataSource, bundle),
  };
}

async function resolveEnvironmentalValue<T>(
  options: ResolveOptions<T>,
): Promise<ResolvedValue<T>> {
  let cached: Awaited<ReturnType<typeof getEnvironmentalCache<T>>> = null;
  if (options.db) {
    try {
      cached = await getEnvironmentalCache<T>(options.db, options.cacheKey);
      if (cached && options.usableCachedValue && !options.usableCachedValue(cached.value)) {
        cached = null;
      }
      if (
        cached &&
        ageMs(cached.updatedAt, options.now) <= options.freshMs
      ) {
        return {
          value: cached.value,
          source: availableSource(
            options.provider,
            'CACHED',
            options.observedAt(cached.value),
            cached.updatedAt,
          ),
        };
      }
    } catch (error) {
      logEnvironmentalError('cache_read_failed', options.provider, error);
    }
  }

  try {
    const value = await options.load();
    const updatedAt = options.now.toISOString();
    if (options.db) {
      try {
        await saveEnvironmentalCache(options.db, {
          cacheKey: options.cacheKey,
          cacheType: options.cacheType,
          nx: options.nx,
          ny: options.ny,
          value,
          updatedAt,
        });
      } catch (error) {
        logEnvironmentalError('cache_write_failed', options.provider, error);
      }
    }
    return {
      value,
      source: availableSource(
        options.provider,
        'AVAILABLE',
        options.observedAt(value),
        updatedAt,
      ),
    };
  } catch (error) {
    logEnvironmentalError('provider_failed', options.provider, error);
    if (
      cached &&
      ageMs(cached.updatedAt, options.now) <= options.maxStaleMs
    ) {
      return {
        value: cached.value,
        source: availableSource(
          options.provider,
          'STALE',
          options.observedAt(cached.value),
          cached.updatedAt,
        ),
      };
    }
    return {
      source: {
        provider: options.provider,
        state: 'UNAVAILABLE',
        reason: 'PROVIDER_UNAVAILABLE',
      },
    };
  }
}

function enrichSnapshot(
  snapshot: WeatherSnapshot,
  uvIndex: number | undefined,
  airQuality: AirQualitySnapshot | undefined,
  bundle: EnvironmentalDataBundle,
  includeAvailabilityFlags: boolean,
): WeatherSnapshot {
  const providers = snapshot.provider?.split('+').filter((provider) =>
    provider !== 'KMA_LIVING_INDEX_V5' && provider !== 'AIRKOREA') ?? [];
  const providerFields = snapshot.providerField?.split(',').filter((field) =>
    !['UV_INDEX', 'PM10', 'PM25', 'O3'].includes(field)) ?? [];
  if (uvIndex !== undefined) {
    providers.push('KMA_LIVING_INDEX_V5');
    providerFields.push('UV_INDEX');
  }
  if (airQuality) {
    providers.push('AIRKOREA');
    providerFields.push('PM10,PM25,O3');
  }
  const qualityFlags = (snapshot.qualityFlags ?? []).filter((flag) =>
    !/^(UV_|AIR_QUALITY_|STALE_UV$|STALE_AIR_QUALITY$)/.test(flag));
  if (includeAvailabilityFlags && uvIndex === undefined) {
    qualityFlags.push(`UV_${bundle.sources.uv.state}`);
  }
  if (includeAvailabilityFlags && !airQuality) {
    qualityFlags.push(`AIR_QUALITY_${bundle.sources.airQuality.state}`);
  }
  if (bundle.sources.uv.state === 'STALE') qualityFlags.push('STALE_UV');
  if (bundle.sources.airQuality.state === 'STALE') {
    qualityFlags.push('STALE_AIR_QUALITY');
  }

  return {
    ...snapshot,
    uvIndex,
    pm10: airQuality?.pm10,
    pm25: airQuality?.pm25,
    airQualityStationName: airQuality?.stationName,
    airQualityObservedAt: airQuality?.observedAt,
    airQualityGrade: airQuality?.airQualityGrade,
    ozone: airQuality?.ozone,
    ozoneGrade: airQuality?.ozoneGrade,
    provider: unique(providers).join('+'),
    providerField: unique(providerFields).join(','),
    qualityFlags: unique(qualityFlags),
  };
}

function uvForTime(
  forecast: UvForecast | undefined,
  targetIso: string,
): number | undefined {
  if (!forecast) return undefined;
  const target = Date.parse(targetIso);
  if (!Number.isFinite(target)) return undefined;
  const candidates = forecast.points
    .map((point) => ({ ...point, timestamp: Date.parse(point.forecastAt) }))
    .filter(
      (point) =>
        Number.isFinite(point.timestamp) &&
        point.timestamp <= target &&
        target - point.timestamp < 3 * 60 * 60 * 1000,
    )
    .sort((left, right) => right.timestamp - left.timestamp);
  return candidates[0]?.uvIndex;
}

function dataSourceLabel(
  base: string,
  bundle: EnvironmentalDataBundle,
): string {
  const sources = base.split(' · ').filter((source) =>
    source !== '기상청 생활기상지수' && source !== '에어코리아');
  if (bundle.uv) sources.push('기상청 생활기상지수');
  if (bundle.airQuality) sources.push('에어코리아');
  return unique(sources).join(' · ');
}

function availableSource(
  provider: string,
  state: Extract<EnvironmentalSourceState, 'AVAILABLE' | 'CACHED' | 'STALE'>,
  observedAt: string,
  cachedAt: string,
): EnvironmentalSourceStatus {
  return { provider, state, observedAt, cachedAt };
}

function unsupportedSource(provider: string): EnvironmentalSourceStatus {
  return {
    provider,
    state: 'UNSUPPORTED_REGION',
    reason: 'UNSUPPORTED_REGION',
  };
}

function unavailableSource(provider: string, reason: EnvironmentalSourceStatus['reason'] = 'PROVIDER_UNAVAILABLE'): EnvironmentalSourceStatus {
  return {
    provider,
    state: 'UNAVAILABLE',
    reason,
  };
}

function ageMs(updatedAt: string, now: Date): number {
  const timestamp = Date.parse(updatedAt);
  return Number.isFinite(timestamp) ? Math.max(0, now.getTime() - timestamp) : Infinity;
}

function unique(values: Array<string | undefined>): string[] {
  return [...new Set(values.filter((value): value is string => Boolean(value)))];
}

function logEnvironmentalError(
  event: 'cache_read_failed' | 'cache_write_failed' | 'provider_failed',
  provider: string,
  error: unknown,
): void {
  console.error(
    JSON.stringify({
      event,
      provider,
      ...providerErrorDiagnostic(error),
    }),
  );
}
