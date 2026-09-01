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
import { AirKoreaAirQualityProvider } from '../air/airKoreaAirQualityProvider';
import { AirQualitySnapshot } from '../air/airQualityProvider';
import { WeatherForecast } from '../weather/weatherProvider';
import { KmaUvProvider } from '../uv/kmaUvProvider';
import { UvForecast } from '../uv/uvProvider';
import { providerErrorDiagnostic } from '../../observability/providerErrorDiagnostics';

const UV_FRESH_MS = 2 * 60 * 60 * 1000;
const UV_MAX_STALE_MS = 8 * 60 * 60 * 1000;
const AIR_FRESH_MS = 30 * 60 * 1000;
const AIR_MAX_STALE_MS = 3 * 60 * 60 * 1000;

export interface EnvironmentalDataBundle {
  uv?: UvForecast;
  airQuality?: AirQualitySnapshot;
  sources: {
    uv: EnvironmentalSourceStatus;
    airQuality: EnvironmentalSourceStatus;
  };
}

interface ResolveOptions<T> {
  db?: D1Database;
  cacheKey: string;
  cacheType: 'UV' | 'AIR_QUALITY';
  nx: number;
  ny: number;
  provider: string;
  freshMs: number;
  maxStaleMs: number;
  observedAt: (value: T) => string;
  load: () => Promise<T>;
  now: Date;
}

interface ResolvedValue<T> {
  value?: T;
  source: EnvironmentalSourceStatus;
}

export async function loadEnvironmentalData(
  env: ServerEnv,
  region: RegionMetadata | undefined,
  options: { now?: Date } = {},
): Promise<EnvironmentalDataBundle> {
  if (!region) {
    return {
      sources: {
        uv: unsupportedSource('KMA_LIVING_INDEX_V5'),
        airQuality: unsupportedSource('AIRKOREA'),
      },
    };
  }

  const now = options.now ?? new Date();
  const serviceKey = env.KMA_SERVICE_KEY;
  const [uv, airQuality] = await Promise.all([
    resolveEnvironmentalValue<UvForecast>({
      db: env.DB,
      cacheKey: `UV_${region.nx}_${region.ny}`,
      cacheType: 'UV',
      nx: region.nx,
      ny: region.ny,
      provider: 'KMA_LIVING_INDEX_V5',
      freshMs: UV_FRESH_MS,
      maxStaleMs: UV_MAX_STALE_MS,
      observedAt: (value) => value.issuedAt,
      load: () =>
        new KmaUvProvider({ serviceKey }).getForecast(region.uvAreaNo),
      now,
    }),
    resolveEnvironmentalValue<AirQualitySnapshot>({
      db: env.DB,
      cacheKey: `AIR_${region.nx}_${region.ny}`,
      cacheType: 'AIR_QUALITY',
      nx: region.nx,
      ny: region.ny,
      provider: 'AIRKOREA',
      freshMs: AIR_FRESH_MS,
      maxStaleMs: AIR_MAX_STALE_MS,
      observedAt: (value) => value.observedAt,
      load: () =>
        new AirKoreaAirQualityProvider({
          serviceKey,
          now: () => now,
        }).getByRegion(
          region.nx,
          region.ny,
          region.airKoreaStationName,
        ),
      now,
    }),
  ]);

  return {
    uv: uv.value,
    airQuality: airQuality.value,
    sources: {
      uv: uv.source,
      airQuality: airQuality.source,
    },
  };
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
  const providers = [snapshot.provider];
  const providerFields = [snapshot.providerField];
  if (uvIndex !== undefined) {
    providers.push('KMA_LIVING_INDEX_V5');
    providerFields.push('UV_INDEX');
  }
  if (airQuality) {
    providers.push('AIRKOREA');
    providerFields.push('PM10,PM25,O3');
  }
  const qualityFlags = [...(snapshot.qualityFlags ?? [])];
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
    pm10: airQuality?.pm10 ?? snapshot.pm10,
    pm25: airQuality?.pm25 ?? snapshot.pm25,
    airQualityStationName:
      airQuality?.stationName ?? snapshot.airQualityStationName,
    airQualityObservedAt:
      airQuality?.observedAt ?? snapshot.airQualityObservedAt,
    airQualityGrade:
      airQuality?.airQualityGrade ?? snapshot.airQualityGrade,
    ozone: airQuality?.ozone ?? snapshot.ozone,
    ozoneGrade: airQuality?.ozoneGrade ?? snapshot.ozoneGrade,
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
  const sources = [base];
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
