import { collectNationwideAirQuality } from '../services/nationwideAirCache';
import { collectNationwideForecast } from '../services/nationwideForecastCache';
import { collectPointForecasts } from '../services/pointForecastCache';
import { collectNationwideUv, NATIONAL_VISIBILITY_KEY, NATIONAL_DAILY_KEY } from '../services/nationwideWeatherCache';
import { apiHubBudgetedFetch } from '../services/apiHubFetch';
import type {
  OfficialRoadControl,
  RoadIceRisk,
  ServerEnv,
} from '../types';
import {
  type EnvironmentalDataBundle,
  type NationwideAirQualitySnapshot,
} from '../providers/environmental/environmentalDataService';
import {
  AIRKOREA_PROVINCES,
  AirKoreaAirQualityProvider,
} from '../providers/air/airKoreaAirQualityProvider';
import {
  ultraShortKoreanIso,
  type UltraShortObservation,
} from '../providers/weather/kmaUltraShortObservationProvider';
import {
  observationsFromGridSnapshot,
  gridObservationKoreanIso,
  latestGridObservationTime,
} from '../providers/weather/kmaGridObservationProvider';
import {
  KmaPrecipitationObservationProvider,
  nationwidePrecipitationAtPoint,
} from '../providers/precipitation/precipitationObservationProvider';
import {
  getNationwidePrecipitation,
  saveNationwidePrecipitation,
} from '../database/nationwidePrecipitationRepository';
import {
  KmaWarningProvider,
  nearestWarningRegion,
  type KmaWarningRegionStation,
} from '../providers/warnings/kmaWarningProvider';
import {
  isRoadIceSeason,
  KmaRoadIceProvider,
  nearestRoadIceRisk,
  type RoadIceSegment,
} from '../providers/road/kmaRoadIceProvider';
import {
  itsRoadControlProviderFromEnvironment,
  nearestRoadControl,
  type RoadControlSnapshotItem,
} from '../providers/traffic/itsRoadControlProvider';
import {
  KmaHourlyObservationProvider,
} from '../providers/weather/kmaHourlyObservationProvider';
import { latestVisibilityKoreanHour } from '../providers/weather/visibility';
import { KmaDailyObservationProvider } from '../providers/weather/kmaDailyObservationProvider';
import {
  latestMidTermIssueTimes,
} from '../providers/weather/kmaMidTermProvider';
import {
  AirKoreaForecastProvider,
  nationwideAirForecastIsUsable,
  type NationwideAirForecast,
} from '../providers/air/airKoreaForecastProvider';
import {
  supportedKmaMidTermRegionIds,
} from '../regions/kmaMidTermRegionCatalog';
import { kmaGridCoordinates } from '../regions/kmaGridCoordinates';
import { mapWithConcurrency } from '../utils/concurrencyLimiter';
import {
  cacheRecordIsFresh,
  collectedSourceVersionIsCurrent,
  collectedCacheKey,
  getCollectedCache,
  saveCollectedCache,
  saveCollectedSourceVersion,
  type CollectedCacheRecord,
} from '../database/collectedWeatherRepository';
import {
  reserveMonthlyRequestBudget,
} from '../database/apiUsageRepository';
import { collectGridObservationSnapshot, backfillGridObservationHistory } from '../services/gridObservationCache';
import { readCurrentGridObservation } from '../database/gridObservationRepository';
import { providerErrorDiagnostic, safeErrorName } from '../observability/providerErrorDiagnostics';
import {
  compactIssueToIso,
  latestAirKoreaForecastIssue,
  latestRadarProductVersion,
  pollingWindowVersion,
  previousKoreanDate,
} from './sourcePublicationSchedule';
import type {
  CollectedWarningBundle,
  CollectionTarget,
} from './collectionTypes';
import {
  hydrateResolvedMidTermForecast,
} from '../services/midTermForecastCache';

const ENVIRONMENTAL_MAX_AGE_MS = 60 * 60 * 1000;
const ENVIRONMENTAL_RETRY_INTERVAL_MS = 10 * 60 * 1000;
const RADAR_BYTES = 13_281_414;
const NATIONWIDE_ANALYSIS_BYTES = 16_793_608;
const ITS_MONTHLY_REQUEST_LIMIT = 9_000;

export interface WeatherCollectionOptions {
  now?: Date;
  collectCore?: boolean;
  collectRadar?: boolean;
  collectRoadIce?: boolean;
  collectActiveDetails?: boolean;
  collectHourlyObservations?: boolean;
  dailyObservationLookbackDays?: number;
  nationwideShardIndex?: number;
  forceSourceRefresh?: boolean;
}

export async function runWeatherCollectionJob(
  env: ServerEnv,
  options: WeatherCollectionOptions = {},
): Promise<void> {
  if (!env.DB) return;
  const now = options.now ?? new Date();
  const targets = await loadActiveCollectionTargets(env.DB);
  const activeRegions = distinctRegions(targets);
  // 수집 단위는 전국 원본이다. 등록된 설치나 대표 격자 목록의 유무와 무관하다.
  if (options.collectCore !== false) {
    await collectUltraShortObservations(env, activeRegions, now, activeRegions);
    await backfillGridObservationHistory(env.DB, env.KMA_APIHUB_KEY, now);
    await collectNationwideAirQuality(env, now);
    await collectNationwideAirForecast(env, now);
    try { await collectNationwideUv(env.DB, env.KMA_SERVICE_KEY, now); }
    catch (error) { logCollectionFailure('national_uv', error); }
    await collectSupportedMidTermForecasts(env, now);
    await collectWarnings(env, [], now);
    await collectRoadControls(env, [], now);
    await collectCurrentVisibility(env, [], now);
    await collectNationalDailyObservations(env, now, options.dailyObservationLookbackDays ?? 7);
    await collectNationwideForecast(env.DB, env.KMA_APIHUB_KEY, now);
    try { await collectPointForecasts(env.DB, env.KMA_SERVICE_KEY, now); }
    catch (error) { logCollectionFailure('point_forecast', error); }
  } else {
    if (options.collectHourlyObservations) await collectCurrentVisibility(env, [], now);
    if (options.dailyObservationLookbackDays !== undefined) await collectNationalDailyObservations(env, now, options.dailyObservationLookbackDays);
  }
  if (options.collectRadar) await collectNationwidePrecipitation(env, [], now, false);
  if (options.collectRoadIce) await collectRoadIce(env, [], now, false);
}

export async function runCurrentObservationCollectionJob(
  env: ServerEnv,
  now = new Date(),
): Promise<void> {
  if (!env.DB) return;
  const activeRegions = distinctRegions(await loadActiveCollectionTargets(env.DB));
  await collectUltraShortObservations(env, activeRegions, now, activeRegions, true);
}

export async function collectSupportedMidTermForecasts(
  env: ServerEnv,
  now = new Date(),
): Promise<void> {
  const expectedIssue = latestMidTermIssueTimes(now, 1)[0];
  const sourceVersion = `DATA_GO_KR:${expectedIssue}`;
  if (!expectedIssue || await collectedSourceVersionIsCurrent(
    env.DB,
    'KMA_MID_TERM_SUPPORTED_REGIONS',
    sourceVersion,
  )) return;

  const regions = supportedKmaMidTermRegionIds();
  let completed = 0;
  let stopped = false;
  await mapWithConcurrency(regions, 4, async (region) => {
    if (stopped) return;
    try {
      const hydrated = await hydrateResolvedMidTermForecast({
        db: env.DB,
        serviceKey: env.KMA_SERVICE_KEY,
        region,
        now,
      });
      if (hydrated.issueTime === expectedIssue && hydrated.days.length > 0) {
        completed += 1;
      }
    } catch (error) {
      const diagnostic = providerErrorDiagnostic(error);
      if (['NOT_CONFIGURED', 'AUTHORIZATION_FAILED', 'QUOTA_EXCEEDED', 'RATE_LIMITED', 'BUDGET_EXHAUSTED'].includes(diagnostic.failureReason)) stopped = true;
      console.error(JSON.stringify({ event: 'mid_term_region_collection_failed',
        regionId: region.temperatureRegionId, ...diagnostic }));
    }
  });
  console.log(JSON.stringify({
    event: 'mid_term_supported_regions_collected',
    expectedIssue,
    completed,
    total: regions.length,
    provider: 'KMA_DATA_GO_KR',
    stopped,
  }));
  if (completed === regions.length) {
    await saveCollectedSourceVersion(
      env.DB,
      'KMA_MID_TERM_SUPPORTED_REGIONS',
      sourceVersion,
      now,
    );
  }
}

async function loadActiveCollectionTargets(db: D1Database): Promise<CollectionTarget[]> {
  const result = await db.prepare(
    `SELECT nx, ny, latitude, longitude
     FROM installations
     GROUP BY nx, ny, latitude, longitude`,
  ).all<{
    nx: number;
    ny: number;
    latitude: number | null;
    longitude: number | null;
  }>();
  return result.results.map((row) => ({
    nx: Number(row.nx),
    ny: Number(row.ny),
    latitude: row.latitude ?? undefined,
    longitude: row.longitude ?? undefined,
  }));
}

async function collectNationwideAirForecast(
  env: ServerEnv,
  now: Date,
  forceRefresh = false,
): Promise<NationwideAirForecast | null> {
  const key = collectedCacheKey.nationwideAirForecast;
  const cached = await getCollectedCache<NationwideAirForecast>(env.DB, key);
  const issue = latestAirKoreaForecastIssue(now);
  if (!forceRefresh && cached?.status === 'AVAILABLE' &&
      nationwideAirForecastIsUsable(cached.value, now)) return cached.value;
  try {
    const areas = await new AirKoreaForecastProvider({
      serviceKey: env.KMA_SERVICE_KEY, now: () => now,
    }).getForecastsByAreas();
    if (Object.values(areas).every((value) => value.length === 0)) {
      throw new Error('AirKorea returned no nationwide forecast');
    }
    const snapshot = { issue, areas };
    await saveCollectedCache(env.DB, {
      key, type: 'COLLECTED_NATIONWIDE_AIR_FORECAST',
      value: snapshot, updatedAt: now,
    });
    return snapshot;
  } catch (error) {
    logCollectionFailure('nationwide_air_forecast', error);
    return cached?.value ?? null;
  }
}

export function shouldRefreshEnvironmentalRecord(
  record: CollectedCacheRecord<EnvironmentalDataBundle> | null,
  now = new Date(),
): boolean {
  if (!record) return true;
  const updatedAt = Date.parse(record.updatedAt);
  if (!Number.isFinite(updatedAt)) return true;
  const hasTemporaryFailure = Object.values(record.value.sources ?? {}).some(
    ({ state }) => state === 'STALE' || state === 'UNAVAILABLE',
  );
  const maxAgeMs = hasTemporaryFailure
    ? ENVIRONMENTAL_RETRY_INTERVAL_MS
    : ENVIRONMENTAL_MAX_AGE_MS;
  return now.getTime() - updatedAt >= maxAgeMs;
}

async function collectWarnings(
  env: ServerEnv,
  regions: CollectionTarget[],
  now: Date,
  forceSourceRefresh = false,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY) return;
  const sourceVersion = pollingWindowVersion(now, 30);
  if (!forceSourceRefresh && await collectedSourceVersionIsCurrent(
    env.DB, 'WARNING_30_MINUTES', sourceVersion,
  )) return;

  const provider = new KmaWarningProvider({ serviceKey: env.KMA_APIHUB_KEY, timeoutMs: 30_000,
    fetcher: apiHubBudgetedFetch({ clock: () => new Date(), db: env.DB, provider: 'WARNING', now, maxBytes: 1_000_000, sourceVersion }) });
  try {
    const cachedStations = await getCollectedCache<KmaWarningRegionStation[]>(
      env.DB, collectedCacheKey.warningStations,
    );
    let stations = cachedStations?.value;
    if (!cacheRecordIsFresh(cachedStations, 24 * 60 * 60 * 1000, now)) {
      stations = await provider.getRegionStations();
      await saveCollectedCache(env.DB, {
        key: collectedCacheKey.warningStations,
        type: 'COLLECTED_WARNING_STATIONS',
        value: stations,
        updatedAt: now,
      });
    }
    if (!stations?.length) throw new Error('KMA warning region mapping is empty');
    const ids = [...new Set(stations.map((station) => station.regionId))];
    const warnings = await provider.getActiveForRegions(ids);
    await saveCollectedCache(env.DB, {
      key: collectedCacheKey.warningSnapshot,
      type: 'COLLECTED_WARNING_SNAPSHOT',
      value: { stations, warnings },
      updatedAt: now,
    });
    await mapWithConcurrency(regions, 12, async (region) => {
      const coordinates = region.latitude !== undefined && region.longitude !== undefined
        ? { latitude: region.latitude, longitude: region.longitude }
        : kmaGridCoordinates(region.nx, region.ny);
      if (!coordinates) return;
      const match = nearestWarningRegion(
        stations, coordinates.latitude, coordinates.longitude,
      );
      await saveCollectedCache(env.DB, {
        key: collectedCacheKey.warning(region.nx, region.ny),
        type: 'COLLECTED_WARNING',
        value: {
          warnings: warnings.filter((warning) => warning.regionId === match.regionId),
          regionName: match.regionName,
        } satisfies CollectedWarningBundle,
        nx: region.nx,
        ny: region.ny,
        updatedAt: now,
      });
    });
    await saveCollectedSourceVersion(
      env.DB, 'WARNING_30_MINUTES', sourceVersion, now,
    );
  } catch (error) {
    logCollectionFailure('warning', error);
  }
}

async function collectUltraShortObservations(
  env: ServerEnv,
  regions: readonly CollectionTarget[],
  now: Date,
  activeRegions: readonly CollectionTarget[] = [],
  fastRetry = false,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY) return;
  const targetClock = latestGridObservationTime(now);
  const expectedObservedAt = gridObservationKoreanIso(targetClock);
  const latest = await collectGridObservationSnapshot({
    db: env.DB, serviceKey: env.KMA_APIHUB_KEY, clock: targetClock, now,
    requiredOnly: fastRetry, fastRetry,
  });
  const exact = latest ? observationsFromGridSnapshot(latest, regions) : new Map<string, UltraShortObservation>();
  const pending = regions.filter(({ nx, ny }) => !exact.has(`${nx}:${ny}`));
  // 원본/핵심값이 없으면 이전 회차의 같은 격자만 쓴다. 관측소 대체는 하지 않는다.
  const previous = pending.length > 0 || !latest ? await collectGridObservationSnapshot({
    db: env.DB, serviceKey: env.KMA_APIHUB_KEY,
    clock: new Date(targetClock.getTime() - 10 * 60 * 1000), now,
    requiredOnly: fastRetry, fastRetry,
  }) : null;
  const previousValues = previous ? observationsFromGridSnapshot(previous, pending) : new Map<string, UltraShortObservation>();
  const historicalClocks = new Set<number>();
  let stored = 0;
  const missing: string[] = [];
  const expiredActive: string[] = [];
  const activeKeys = new Set(activeRegions.map(({ nx, ny }) => `${nx}:${ny}`));
  for (const region of regions) {
    const key = `${region.nx}:${region.ny}`;
    const value = exact.get(key) ?? previousValues.get(key);
    const record = value ? { value, status: 'AVAILABLE' as const, updatedAt: now.toISOString() }
      : await readCurrentGridObservation(env.DB, region.nx, region.ny, now);
    if (!record) {
      missing.push(key);
      if (activeKeys.has(key)) expiredActive.push(key);
      continue;
    }
    // 기존 키는 알림·프리워밍과의 호환용이다. 모든 GPS 조회의 원본은 전국 스냅샷이다.
    await saveCollectedCache(env.DB, {
      key: collectedCacheKey.ultraShortObservation(region.nx, region.ny),
      type: 'COLLECTED_ULTRA_SHORT', value: record.value,
      nx: region.nx, ny: region.ny, updatedAt: now,
    });
    stored += 1;
    historicalClocks.add(Date.parse(record.value.observedAt) - 24 * 60 * 60 * 1000);
  }
  if (latest) historicalClocks.add(Date.parse(latest.observedAt) - 24 * 60 * 60 * 1000);
  // 어제 원본은 중앙에서 회차당 한 번만 보충한다. 앱 요청에서는 외부 API를 호출하지 않는다.
  for (const instant of historicalClocks) {
    await collectGridObservationSnapshot({ db: env.DB, serviceKey: env.KMA_APIHUB_KEY,
      clock: new Date(instant + 9 * 60 * 60 * 1000), now, requiredOnly: true, historical: true });
  }
  console.log(JSON.stringify({ event: 'current_observation_collection_completed',
    targetObservedAt: expectedObservedAt, regions: regions.length, pending: pending.length,
    latestGridCount: exact.size, previousGridCount: previousValues.size, stored,
    missing: missing.length, missingSample: missing.slice(0, 10),
    activeMissing: missing.filter((key) => activeKeys.has(key)).slice(0, 50) }));
  if (expiredActive.length > 0) console.error(JSON.stringify({
    event: 'current_observation_freshness_breached', targetObservedAt: expectedObservedAt,
    count: expiredActive.length, grids: expiredActive.slice(0, 50) }));
}

async function collectNationwidePrecipitation(
  env: ServerEnv,
  locations: Array<{ latitude: number; longitude: number }>,
  now: Date,
  forceSourceRefresh: boolean,
): Promise<boolean> {
  // Winter road-ice archives share the same daily APIHub byte allowance.
  if (!forceSourceRefresh &&
      now.getUTCMinutes() % 30 < 15 &&
      await getNationwidePrecipitation(env.DB, now) !== null) return true;
  const sourceVersion = latestRadarProductVersion(
    new Date(now.getTime() - 5 * 60 * 1000),
  );
  if (!forceSourceRefresh && await collectedSourceVersionIsCurrent(
    env.DB,
    'NATIONWIDE_PRECIPITATION_15_MINUTES',
    sourceVersion,
  )) return await getNationwidePrecipitation(env.DB, now) !== null;
  try {
    const snapshot = await new KmaPrecipitationObservationProvider({
      serviceKey: env.KMA_APIHUB_KEY!,
      fetcher: apiHubBudgetedFetch({ clock: () => new Date(), db: env.DB, provider: 'NATIONWIDE_ANALYSIS_AND_RADAR', now, sourceVersion,
        maxBytes: NATIONWIDE_ANALYSIS_BYTES + RADAR_BYTES }),
      now: () => now,
      timeoutMs: 30_000,
      attempts: 1,
    }).getNationwideSnapshot(new Date(compactIssueToIso(sourceVersion)));
    await saveNationwidePrecipitation(env.DB, snapshot, now);
    for (const location of locations) {
      try {
        const value = nationwidePrecipitationAtPoint(
          snapshot,
          location.latitude,
          location.longitude,
        );
        await saveCollectedCache(env.DB, {
          key: collectedCacheKey.precipitation(location.latitude, location.longitude),
          type: 'COLLECTED_PRECIPITATION',
          value,
          updatedAt: now,
        });
      } catch (error) {
        logCollectionFailure('precipitation_location', error);
      }
    }
    await saveCollectedSourceVersion(
      env.DB,
      'NATIONWIDE_PRECIPITATION_15_MINUTES',
      sourceVersion,
      now,
    );
    return true;
  } catch (error) {
    logCollectionFailure('nationwide_precipitation', error);
    return false;
  }
}

async function collectRoadIce(
  env: ServerEnv,
  locations: Array<{ latitude: number; longitude: number }>,
  now: Date,
  forceSourceRefresh = false,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY || !isRoadIceSeason(now)) return;
  const sourceVersion = pollingWindowVersion(now, 30);
  if (!forceSourceRefresh && await collectedSourceVersionIsCurrent(
    env.DB,
    'ROAD_ICE_30_MINUTES',
    sourceVersion,
  )) return;
  try {
    const segments = await new KmaRoadIceProvider({
      serviceKey: env.KMA_APIHUB_KEY, timeoutMs: 30_000,
      fetcher: apiHubBudgetedFetch({ clock: () => new Date(), db: env.DB, provider: 'ROAD_ICE', now, sourceVersion, maxBytes: 2_100_000 }),
      now: () => now,
    }).getRiskSegments();
    await saveCollectedCache<RoadIceSegment[]>(env.DB, {
      key: collectedCacheKey.roadIceSnapshot,
      type: 'COLLECTED_ROAD_ICE_SNAPSHOT',
      value: segments,
      updatedAt: now,
    });
    await Promise.all(locations.map((location, index) => saveCollectedCache<RoadIceRisk | null>(
      env.DB,
      {
        key: collectedCacheKey.roadIce(location.latitude, location.longitude),
        type: 'COLLECTED_ROAD_ICE',
        value: nearestRoadIceRisk(segments, location.latitude, location.longitude) ?? null,
        updatedAt: now,
      },
    )));
    await saveCollectedSourceVersion(
      env.DB,
      'ROAD_ICE_30_MINUTES',
      sourceVersion,
      now,
    );
  } catch (error) {
    logCollectionFailure('road_ice', error);
  }
}

async function collectRoadControls(
  env: ServerEnv,
  locations: Array<{ latitude: number; longitude: number }>,
  now: Date,
  forceSourceRefresh = false,
): Promise<void> {
  const provider = itsRoadControlProviderFromEnvironment(env);
  if (!provider) return;
  const sourceVersion = pollingWindowVersion(now, 10);
  if (!forceSourceRefresh && await collectedSourceVersionIsCurrent(
    env.DB,
    'ROAD_CONTROL_10_MINUTES',
    sourceVersion,
  )) return;
  if (!await reserveMonthlyRequestBudget(
    env.DB,
    'ITS_ROAD_CONTROL',
    1,
    ITS_MONTHLY_REQUEST_LIMIT,
    now,
  )) return;
  try {
    const snapshot = await provider.getActiveControlSnapshot();
    await saveCollectedCache<RoadControlSnapshotItem[]>(env.DB, {
      key: collectedCacheKey.roadControlSnapshot,
      type: 'COLLECTED_ROAD_CONTROL_SNAPSHOT',
      value: snapshot,
      updatedAt: now,
    });
    await Promise.all(locations.map((location) => {
      const value = nearestRoadControl(snapshot, location);
      return saveCollectedCache<OfficialRoadControl | null>(env.DB, {
        key: collectedCacheKey.roadControl(location.latitude, location.longitude),
        type: 'COLLECTED_ROAD_CONTROL',
        value: value ?? null,
        updatedAt: now,
      });
    }));
    await saveCollectedSourceVersion(
      env.DB,
      'ROAD_CONTROL_10_MINUTES',
      sourceVersion,
      now,
    );
  } catch (error) {
    logCollectionFailure('road_control', error);
  }
}

async function collectCurrentVisibility(
  env: ServerEnv,
  targets: CollectionTarget[],
  now: Date,
  forceSourceRefresh = false,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY) return;
  const currentHour = latestVisibilityKoreanHour(now);
  const sourceVersion = ultraShortKoreanIso(currentHour);
  if (!forceSourceRefresh && await collectedSourceVersionIsCurrent(
    env.DB,
    'ASOS_VISIBILITY_HOURLY',
    sourceVersion,
  )) return;
  try {
    const provider = new KmaHourlyObservationProvider({
      serviceKey: env.KMA_APIHUB_KEY,
      timeoutMs: 30_000,
      fetcher: apiHubBudgetedFetch({ clock: () => new Date(), db: env.DB, provider: 'ASOS_VISIBILITY', now, sourceVersion, maxBytes: 512_000 }),
      now: () => now,
    });
    const current = await provider.getObservationsAt(currentHour, {
      includeVisibility: true,
    });
    await saveCollectedCache(env.DB, { key: NATIONAL_VISIBILITY_KEY,
      type: 'COLLECTED_NATIONWIDE_VISIBILITY', value: current, updatedAt: now });
    await saveCollectedSourceVersion(
      env.DB,
      'ASOS_VISIBILITY_HOURLY',
      sourceVersion,
      now,
    );
  } catch (error) {
    logCollectionFailure('visibility', error);
  }
}

async function collectNationalDailyObservations(env: ServerEnv, now: Date, lookbackDays: number): Promise<void> {
  if (!env.KMA_APIHUB_KEY) return;
  const dates = recentCompletedKoreanDates(now, Math.min(7, lookbackDays));
  if (!dates.length) return;
  const end = dates[dates.length - 1];
  if (await collectedSourceVersionIsCurrent(env.DB, 'AWS_DAILY', end)) return;
  try {
    const cached = await getCollectedCache<import('../providers/weather/kmaDailyObservationProvider').NationwideDailySnapshot>(env.DB, NATIONAL_DAILY_KEY);
    const knownDates = new Set(cached?.value.settledDates ?? cached?.value.completedDates ?? []);
    const missingDates = dates.filter((date) => !knownDates.has(date));
    if (!missingDates.length) return;
    const dailyProvider = new KmaDailyObservationProvider({ serviceKey: env.KMA_APIHUB_KEY, timeoutMs: 30_000,
      fetcher: apiHubBudgetedFetch({ clock: () => new Date(), db: env.DB, provider: 'AWS_DAILY', now, sourceVersion: end, maxBytes: 2_048_000 })
    });
    const startDate = compactCalendarDate(missingDates[0]);
    const endDate = compactCalendarDate(end);
    const incoming = cached?.value.metricAvailability
      ? await dailyProvider.getNationwide(startDate,endDate,cached.value)
      : await dailyProvider.getNationwide(startDate,endDate);
    const stations = new Map((cached?.value.stations ?? []).filter((station) => dates.includes(station.date))
      .map((station) => [`${station.date}:${station.stationId}`, station]));
    for (const station of incoming.stations) {
      const id = `${station.date}:${station.stationId}`;
      stations.set(id, { ...stations.get(id), ...station });
    }
    const completedDates = [...new Set([...(cached?.value.completedDates ?? []), ...(incoming.completedDates ?? [])])].filter((date) => dates.includes(date));
    const settledDates = [...new Set([...knownDates,...(incoming.settledDates ?? incoming.completedDates ?? [])])].filter(date => dates.includes(date));
    const metricAvailability = {...cached?.value.metricAvailability,...incoming.metricAvailability};
    const value = { ...incoming, stations: [...stations.values()], completedDates,settledDates,metricAvailability };
    await saveCollectedCache(env.DB, { key: NATIONAL_DAILY_KEY, type: 'COLLECTED_NATIONWIDE_DAILY', value, updatedAt: now });
    if (dates.every((date) => settledDates.includes(compactCalendarDate(date)))) {
      await saveCollectedSourceVersion(env.DB, 'AWS_DAILY', end, now);
    }
  } catch (error) { logCollectionFailure('national_daily_observation', error); }
}

function recentCompletedKoreanDates(now: Date, lookbackDays: number): string[] {
  if (!Number.isInteger(lookbackDays) || lookbackDays < 1 || lookbackDays > 7) {
    throw new RangeError('Daily observation lookback must be between 1 and 7 days');
  }
  const endDate = previousKoreanDate(now);
  const end = new Date(`${endDate}T00:00:00Z`).getTime();
  return Array.from({ length: lookbackDays }, (_, index) =>
    new Date(end - (lookbackDays - index - 1) * 86_400_000)
      .toISOString()
      .slice(0, 10),
  );
}

function compactCalendarDate(value: string): string {
  return /^\d{8}$/.test(value)
    ? `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`
    : value;
}

function distinctRegions(targets: CollectionTarget[]): CollectionTarget[] {
  return [...new Map(targets.map((target) => [
    `${target.nx}_${target.ny}`,
    { ...target },
  ])).values()];
}

function logCollectionFailure(
  source: string,
  error: unknown,
  context: Record<string, unknown> = {},
): void {
  console.error(JSON.stringify({
    event: 'weather_collection_failed',
    source,
    ...context,
    error: safeErrorName(error),
    ...providerErrorDiagnostic(error),
  }));
}
