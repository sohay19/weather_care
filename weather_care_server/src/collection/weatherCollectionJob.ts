import type {
  CurrentPrecipitationObservation,
  OfficialRoadControl,
  RoadIceRisk,
  ServerEnv,
} from '../types';
import {
  KmaWeatherProvider,
  latestBaseDateTimes,
} from '../providers/weather/kmaWeatherProvider';
import type { WeatherForecast } from '../providers/weather/weatherProvider';
import {
  enrichForecastWithEnvironmentalData,
  loadEnvironmentalData,
  type EnvironmentalDataBundle,
} from '../providers/environmental/environmentalDataService';
import {
  ultraShortKoreanIso,
  type UltraShortObservation,
} from '../providers/weather/kmaUltraShortObservationProvider';
import {
  GRID_OBSERVATION_VARIABLES,
  gridObservationKoreanIso,
  KmaGridObservationProvider,
  latestGridObservationTime,
} from '../providers/weather/kmaGridObservationProvider';
import { KmaAwsMinuteObservationProvider } from '../providers/weather/kmaAwsMinuteObservationProvider';
import { KmaPrecipitationObservationProvider } from '../providers/precipitation/precipitationObservationProvider';
import {
  KmaWarningProvider,
  type KmaWarningRegionMatch,
} from '../providers/warnings/kmaWarningProvider';
import {
  isRoadIceSeason,
  KmaRoadIceProvider,
  ROAD_ICE_ROAD_NUMBERS,
} from '../providers/road/kmaRoadIceProvider';
import { itsRoadControlProviderFromEnvironment } from '../providers/traffic/itsRoadControlProvider';
import {
  KmaHourlyObservationProvider,
  latestCompletedKoreanHour,
  nearestVisibilityObservations,
} from '../providers/weather/kmaHourlyObservationProvider';
import { KmaDailyObservationProvider } from '../providers/weather/kmaDailyObservationProvider';
import {
  latestMidTermIssueTimes,
} from '../providers/weather/kmaMidTermProvider';
import { KmaUvProvider, latestUvPublicationTimes } from '../providers/uv/kmaUvProvider';
import { AirKoreaForecastProvider } from '../providers/air/airKoreaForecastProvider';
import {
  resolveKmaMidTermRegionIds,
  supportedKmaMidTermRegionIds,
} from '../regions/kmaMidTermRegionCatalog';
import { uvAreaNoForGrid } from '../regions/kmaUvAreaGridCatalog';
import { regionMetadataForGrid } from '../regions/regionCatalog';
import { kmaGridCoordinates } from '../regions/kmaGridCoordinates';
import {
  NATIONWIDE_FORECAST_GRIDS,
  nationwideForecastGridShard,
  scheduledNationwideForecastGridShard,
} from '../regions/nationwideForecastGridCatalog';
import { mapWithConcurrency } from '../utils/concurrencyLimiter';
import {
  cacheRecordIsFresh,
  collectedSourceVersionIsCurrent,
  collectedCacheKey,
  getCollectedCache,
  locationCacheKey,
  saveCollectedCache,
  saveCollectedSourceVersion,
  type CollectedCacheRecord,
} from '../database/collectedWeatherRepository';
import { reserveApiHubBudget } from '../database/apiUsageRepository';
import { saveCurrentWeather } from '../database/weatherCacheRepository';
import {
  currentKoreanCalendarWeek,
} from '../database/weeklyForecastRepository';
import { providerErrorDiagnostic, safeErrorName } from '../observability/providerErrorDiagnostics';
import {
  compactIssueToIso,
  latestAirKoreaForecastIssue,
  latestRadarProductVersion,
  pollingWindowVersion,
  previousKoreanDate,
} from './sourcePublicationSchedule';
import type {
  CollectedRegionBundle,
  CollectedWarningBundle,
  CollectedWeeklyBundle,
  CollectionTarget,
} from './collectionTypes';
import {
  hydrateMidTermForecast,
  hydrateResolvedMidTermForecast,
} from '../services/midTermForecastCache';

const ENVIRONMENTAL_MAX_AGE_MS = 60 * 60 * 1000;
const ENVIRONMENTAL_RETRY_INTERVAL_MS = 10 * 60 * 1000;
const RADAR_BYTES = 13_281_414;
const ANALYSIS_VALIDATION_LIMIT = 40;

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
  const collectActiveDetails = options.collectActiveDetails !== false;
  const forceSourceRefresh = options.forceSourceRefresh === true;
  const precollectNationwide = env.NATIONWIDE_PRECOLLECT_ENABLED === 'true';
  const nationwideShard = precollectNationwide
    ? options.nationwideShardIndex === undefined
      ? scheduledNationwideForecastGridShard(now)
      : {
          shardIndex: options.nationwideShardIndex,
          grids: nationwideForecastGridShard(options.nationwideShardIndex),
        }
    : undefined;
  const regions = distinctRegions([
    ...(nationwideShard?.grids ?? []),
    ...(collectActiveDetails ? activeRegions : []),
  ]);
  if (precollectNationwide && options.collectCore !== false &&
      options.nationwideShardIndex === undefined) {
    await collectSupportedMidTermForecasts(env, now);
  }
  if (regions.length === 0) return;
  const locations = distinctLocations(targets);
  const activeRegionKeys = new Set(
    (collectActiveDetails ? activeRegions : [])
      .map(({ nx, ny }) => `${nx}_${ny}`),
  );
  const allForecastTargets: CollectionTarget[] = precollectNationwide
    ? [...NATIONWIDE_FORECAST_GRIDS]
    : activeRegions;

  console.log(JSON.stringify({
    event: 'weather_collection_targets_loaded',
    activeRegions: activeRegions.length,
    nationwideShard: nationwideShard?.shardIndex,
    nationwideRegions: nationwideShard?.grids.length ?? 0,
    totalRegions: regions.length,
  }));

  if (options.dailyObservationLookbackDays !== undefined) {
    await collectDailyObservations(env, allForecastTargets, now, {
      candidateDates: recentCompletedKoreanDates(
        now,
        options.dailyObservationLookbackDays,
      ),
      ignoreSourceVersion: true,
    });
  }

  if (options.collectHourlyObservations === true) {
    await collectCurrentVisibility(
      env,
      allForecastTargets,
      now,
      forceSourceRefresh,
    );
  }

  if (options.collectCore !== false) {
    await collectRegionForecasts(env, regions, activeRegionKeys, now);
    if (collectActiveDetails) {
      await collectWarnings(env, activeRegions, now, forceSourceRefresh);
      await collectUltraShortObservations(env, activeRegions, now);
      await collectRoadControls(env, locations, now, forceSourceRefresh);
      if (options.collectHourlyObservations !== true) {
        await collectCurrentVisibility(
          env,
          allForecastTargets,
          now,
          forceSourceRefresh,
        );
      }
      if (koreanHour(now) === 2) {
        await collectDailyObservations(env, allForecastTargets, now);
      }
    }
  }
  if (options.collectRadar === true) {
    await collectCurrentPrecipitation(
      env,
      targets,
      locations,
      now,
      forceSourceRefresh,
    );
  }
  if (options.collectRoadIce === true) {
    await collectRoadIce(env, locations, now, forceSourceRefresh);
  }
}

export async function collectSupportedMidTermForecasts(
  env: ServerEnv,
  now = new Date(),
): Promise<void> {
  const expectedIssue = latestMidTermIssueTimes(now, 1)[0];
  if (!expectedIssue || await collectedSourceVersionIsCurrent(
    env.DB,
    'KMA_MID_TERM_SUPPORTED_REGIONS',
    expectedIssue,
  )) return;

  const regions = supportedKmaMidTermRegionIds();
  let completed = 0;
  await mapWithConcurrency(regions, 4, async (region) => {
    const hydrated = await hydrateResolvedMidTermForecast({
      db: env.DB,
      serviceKey: env.KMA_SERVICE_KEY,
      apiHubKey: env.KMA_APIHUB_KEY,
      region,
      now,
    });
    if (hydrated.issueTime === expectedIssue && hydrated.days.length > 0) {
      completed += 1;
    }
  });
  console.log(JSON.stringify({
    event: 'mid_term_supported_regions_collected',
    expectedIssue,
    completed,
    total: regions.length,
  }));
  if (completed === regions.length) {
    await saveCollectedSourceVersion(
      env.DB,
      'KMA_MID_TERM_SUPPORTED_REGIONS',
      expectedIssue,
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

async function collectRegionForecasts(
  env: ServerEnv,
  regions: CollectionTarget[],
  activeRegionKeys: ReadonlySet<string>,
  now: Date,
): Promise<void> {
  await mapWithConcurrency(regions, 2, async ({ nx, ny }) => {
    try {
      const includeSupplemental = activeRegionKeys.has(`${nx}_${ny}`);
      let forecastRecord = await getCollectedCache<WeatherForecast>(
        env.DB,
        collectedCacheKey.forecast(nx, ny),
      );
      const latestForecastIssue = latestBaseDateTimes(now, 1)[0];
      if (!forecastRecord ||
          forecastRecord.value.baseDate !== latestForecastIssue?.baseDate ||
          forecastRecord.value.baseTime !== latestForecastIssue?.baseTime) {
        const provider = new KmaWeatherProvider({
          serviceKey: env.KMA_SERVICE_KEY,
          now: () => now,
        });
        const value = includeSupplemental
          ? await provider.getForecastByRegion(nx, ny)
          : await provider.getLatestForecastByRegion(nx, ny);
        await saveCollectedCache(env.DB, {
          key: collectedCacheKey.forecast(nx, ny),
          type: 'COLLECTED_FORECAST',
          value,
          nx,
          ny,
          updatedAt: now,
        });
        await saveCurrentWeather(env.DB, nx, ny, value.current);
        forecastRecord = { value, status: 'AVAILABLE', updatedAt: now.toISOString() };
      }

      let environmentalRecord = await getCollectedCache<EnvironmentalDataBundle>(
        env.DB,
        collectedCacheKey.environmental(nx, ny),
      );
      if (includeSupplemental && shouldRefreshEnvironmentalRecord(environmentalRecord, now)) {
        const environmental = await loadEnvironmentalData(
          env,
          regionMetadataForGrid(nx, ny),
          { now, nx, ny, coordinates: kmaGridCoordinates(nx, ny), providerTimeoutMs: 7_500 },
        );
        await saveCollectedCache(env.DB, {
          key: collectedCacheKey.environmental(nx, ny),
          type: 'COLLECTED_ENVIRONMENTAL',
          value: environmental,
          nx,
          ny,
          updatedAt: now,
        });
        environmentalRecord = { value: environmental, status: 'AVAILABLE', updatedAt: now.toISOString() };
      }

      if (forecastRecord) {
        const environmental = environmentalRecord?.value ?? nationwideBaseEnvironmentalData();
        const bundle: CollectedRegionBundle = {
          forecast: enrichForecastWithEnvironmentalData(
            forecastRecord.value,
            environmental,
          ),
          environmental,
        };
        await saveCollectedCache(env.DB, {
          key: `COLLECTED_REGION_${nx}_${ny}`,
          type: 'COLLECTED_REGION',
          value: bundle,
          nx,
          ny,
          updatedAt: now,
        });
      }
      await collectWeekly(
        env,
        nx,
        ny,
        forecastRecord?.value,
        now,
        includeSupplemental,
      );
    } catch (error) {
      logCollectionFailure('region', error, { nx, ny });
    }
  });
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

async function collectWeekly(
  env: ServerEnv,
  nx: number,
  ny: number,
  forecast: WeatherForecast | undefined,
  now: Date,
  includeSupplemental: boolean,
): Promise<void> {
  const key = collectedCacheKey.weekly(nx, ny);
  const cached = await getCollectedCache<CollectedWeeklyBundle>(env.DB, key);
  const sameForecastIssue = cached?.value.forecast?.baseDate === forecast?.baseDate &&
    cached?.value.forecast?.baseTime === forecast?.baseTime;
  if (!includeSupplemental) {
    if (sameForecastIssue) return;
    await saveCollectedCache(env.DB, {
      key,
      type: 'COLLECTED_WEEKLY',
      value: {
        forecast,
        midTermDays: cached?.value.midTermDays ?? [],
        observedDays: cached?.value.observedDays ?? [],
        uv: cached?.value.uv,
        airQuality: cached?.value.airQuality ?? [],
        midTermIssue: cached?.value.midTermIssue,
        midTermTaRegId: cached?.value.midTermTaRegId,
        midTermLandRegId: cached?.value.midTermLandRegId,
        uvIssue: cached?.value.uvIssue,
        airQualityIssue: cached?.value.airQualityIssue,
        collectedAt: now.toISOString(),
      } satisfies CollectedWeeklyBundle,
      nx,
      ny,
      updatedAt: now,
    });
    return;
  }
  const midRegion = resolveKmaMidTermRegionIds(undefined, undefined, nx, ny);
  const uvAreaNo = uvAreaNoForGrid(nx, ny);
  const midTermIssue = latestMidTermIssueTimes(now, 1)[0];
  const uvIssue = latestUvPublicationTimes(now, 1)[0];
  const expectedMidTermIssue = compactIssueToIso(midTermIssue);
  const expectedUvIssue = compactIssueToIso(uvIssue);
  const airQualityIssue = latestAirKoreaForecastIssue(now);
  const needsMidTerm = cached?.value.midTermIssue !== expectedMidTermIssue ||
    (midRegion !== undefined && (cached?.value.midTermDays.length ?? 0) === 0);
  const needsUv = cached?.value.uvIssue !== expectedUvIssue;
  const needsAirQuality = cached?.value.airQualityIssue !== airQualityIssue;
  if (sameForecastIssue && !needsMidTerm && !needsUv && !needsAirQuality) return;

  let midTermDays = cached?.value.midTermDays ?? [];
  let resolvedMidTermIssue = cached?.value.midTermIssue;
  let midTermTaRegId = cached?.value.midTermTaRegId;
  let midTermLandRegId = cached?.value.midTermLandRegId;
  if (needsMidTerm) {
    if (!midRegion) {
      resolvedMidTermIssue = expectedMidTermIssue;
    } else {
      try {
        const hydrated = await hydrateMidTermForecast({
          db: env.DB,
          serviceKey: env.KMA_SERVICE_KEY,
          apiHubKey: env.KMA_APIHUB_KEY,
          location: { nx, ny },
          now,
        });
        if (hydrated.days.length > 0) {
          midTermDays = hydrated.days;
          resolvedMidTermIssue = hydrated.issuedAt;
          midTermTaRegId = hydrated.region.temperatureRegionId;
          midTermLandRegId = hydrated.region.landRegionId;
        }
      } catch (error) {
        logCollectionFailure('mid_term', error, { nx, ny });
      }
    }
  }

  let uv = cached?.value.uv;
  let resolvedUvIssue = cached?.value.uvIssue;
  if (needsUv) {
    if (!uvAreaNo) {
      resolvedUvIssue = expectedUvIssue;
    } else {
      try {
        uv = await new KmaUvProvider({
          serviceKey: env.KMA_SERVICE_KEY,
          now: () => now,
        }).getForecast(uvAreaNo);
        resolvedUvIssue = uv.issuedAt;
      } catch (error) {
        logCollectionFailure('weekly_uv', error, { nx, ny });
      }
    }
  }

  let airQuality = cached?.value.airQuality ?? [];
  let resolvedAirQualityIssue = cached?.value.airQualityIssue;
  if (needsAirQuality) {
    try {
      airQuality = await new AirKoreaForecastProvider({
        serviceKey: env.KMA_SERVICE_KEY,
        now: () => now,
      }).getForecast(undefined, nx, ny);
      resolvedAirQualityIssue = airQualityIssue;
    } catch (error) {
      logCollectionFailure('air_quality_forecast', error, { nx, ny });
    }
  }
  await saveCollectedCache(env.DB, {
    key,
    type: 'COLLECTED_WEEKLY',
    value: {
      forecast,
      midTermDays,
      observedDays: cached?.value.observedDays ?? [],
      uv,
      airQuality,
      midTermIssue: resolvedMidTermIssue,
      midTermTaRegId,
      midTermLandRegId,
      uvIssue: resolvedUvIssue,
      airQualityIssue: resolvedAirQualityIssue,
      collectedAt: now.toISOString(),
    } satisfies CollectedWeeklyBundle,
    nx,
    ny,
    updatedAt: now,
  });
}

function nationwideBaseEnvironmentalData(): EnvironmentalDataBundle {
  return {
    sources: {
      uv: {
        provider: 'KMA_LIVING_INDEX_V5',
        state: 'UNAVAILABLE',
        reason: 'PROVIDER_UNAVAILABLE',
      },
      airQuality: {
        provider: 'AIRKOREA',
        state: 'UNAVAILABLE',
        reason: 'PROVIDER_UNAVAILABLE',
      },
    },
  };
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
    env.DB,
    'WARNING_30_MINUTES',
    sourceVersion,
  )) return;
  const metadata: Array<{
    region: CollectionTarget;
    value: { name: string; warningRegionIds: string[] };
  }> = regions.flatMap((region) => {
    const value = regionMetadataForGrid(region.nx, region.ny);
    return value ? [{
      region,
      value: { name: value.name, warningRegionIds: [...value.warningRegionIds] },
    }] : [];
  });
  const unresolved: Array<{
    region: CollectionTarget;
    coordinates: { latitude: number; longitude: number };
  }> = [];
  for (const region of regions) {
    if (regionMetadataForGrid(region.nx, region.ny)) continue;
    const cached = await getCollectedCache<KmaWarningRegionMatch>(
      env.DB,
      collectedCacheKey.warningRegion(region.nx, region.ny),
    );
    if (cacheRecordIsFresh(cached, 24 * 60 * 60 * 1000, now)) {
      metadata.push({
        region,
        value: {
          name: cached!.value.regionName,
          warningRegionIds: [cached!.value.regionId],
        },
      });
      continue;
    }
    const coordinates = region.latitude !== undefined && region.longitude !== undefined
      ? { latitude: region.latitude, longitude: region.longitude }
      : kmaGridCoordinates(region.nx, region.ny);
    if (coordinates) unresolved.push({ region, coordinates });
  }
  const provider = new KmaWarningProvider({ serviceKey: env.KMA_APIHUB_KEY });
  const mappingRefresh = await getCollectedCache<{ refreshedAt: string }>(
    env.DB,
    'COLLECTED_WARNING_MAPPING_REFRESH',
  );
  if (unresolved.length > 0 &&
      !cacheRecordIsFresh(mappingRefresh, 24 * 60 * 60 * 1000, now) &&
      await reserveApiHubBudget(
    env.DB,
    'WARNING_REGION_MAPPING',
    1,
    1_000_000,
    now,
  )) {
    try {
      const matches = await provider.resolveRegionsByLocations(
        unresolved.map(({ coordinates }) => coordinates),
      );
      for (const [index, { region }] of unresolved.entries()) {
        const match = matches[index];
        metadata.push({
          region,
          value: { name: match.regionName, warningRegionIds: [match.regionId] },
        });
        await saveCollectedCache(env.DB, {
          key: collectedCacheKey.warningRegion(region.nx, region.ny),
          type: 'COLLECTED_WARNING_REGION',
          value: match,
          nx: region.nx,
          ny: region.ny,
          updatedAt: now,
        });
      }
      await saveCollectedCache(env.DB, {
        key: 'COLLECTED_WARNING_MAPPING_REFRESH',
        type: 'COLLECTED_WARNING_MAPPING_REFRESH',
        value: { refreshedAt: now.toISOString() },
        updatedAt: now,
      });
    } catch (error) {
      logCollectionFailure('warning_region_mapping', error);
    }
  }
  const ids = [...new Set(metadata.flatMap(({ value }) => value.warningRegionIds))];
  if (ids.length === 0 || !await reserveApiHubBudget(env.DB, 'WARNING', 1, 256_000, now)) return;
  try {
    const warnings = await provider.getActiveForRegions(ids);
    await Promise.all(metadata.map(({ region, value }) =>
      saveCollectedCache(env.DB, {
        key: collectedCacheKey.warning(region.nx, region.ny),
        type: 'COLLECTED_WARNING',
        value: {
          warnings: warnings.filter((warning) =>
            value.warningRegionIds.includes(warning.regionId),
          ),
          regionName: value.name,
        } satisfies CollectedWarningBundle,
        nx: region.nx,
        ny: region.ny,
        updatedAt: now,
      }),
    ));
    await saveCollectedSourceVersion(
      env.DB,
      'WARNING_30_MINUTES',
      sourceVersion,
      now,
    );
  } catch (error) {
    logCollectionFailure('warning', error);
  }
}

async function collectUltraShortObservations(
  env: ServerEnv,
  regions: CollectionTarget[],
  now: Date,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY || regions.length === 0) return;
  const targetClock = latestGridObservationTime(now);
  const expectedObservedAt = gridObservationKoreanIso(targetClock);
  const pending: CollectionTarget[] = [];
  for (const region of regions) {
    const record = await getCollectedCache<UltraShortObservation>(
      env.DB,
      collectedCacheKey.ultraShortObservation(region.nx, region.ny),
    );
    if (record?.status !== 'AVAILABLE' ||
        record.value.observedAt < expectedObservedAt) {
      pending.push(region);
    }
  }
  if (pending.length === 0) return;

  const observations = new Map<string, UltraShortObservation>();
  if (await reserveApiHubBudget(
    env.DB,
    'GRID_OBSERVATION_10_MINUTES',
    GRID_OBSERVATION_VARIABLES.length,
    6_000_000,
    now,
  )) {
    try {
      const exact = await new KmaGridObservationProvider({
        serviceKey: env.KMA_APIHUB_KEY,
      }).getAt(pending, targetClock);
      for (const [key, value] of exact) observations.set(key, value);
    } catch (error) {
      logCollectionFailure('grid_observation', error);
    }
  }

  const missing = pending.filter(
    (region) => !observations.has(`${region.nx}:${region.ny}`),
  );
  const fallbackTargets = missing.flatMap((region) => {
    const coordinates = region.latitude !== undefined &&
        region.longitude !== undefined
      ? { latitude: region.latitude, longitude: region.longitude }
      : kmaGridCoordinates(region.nx, region.ny);
    return coordinates ? [{ region, coordinates }] : [];
  });
  if (fallbackTargets.length > 0 && await reserveApiHubBudget(
    env.DB,
    'AWS_CURRENT_FALLBACK',
    3,
    3_000_000,
    now,
  )) {
    try {
      const fallback = await new KmaAwsMinuteObservationProvider({
        serviceKey: env.KMA_APIHUB_KEY,
        now: () => now,
      }).getCurrentByLocations(fallbackTargets.map(({ coordinates }) => coordinates));
      fallback.forEach((value, index) => {
        if (!value) return;
        const region = fallbackTargets[index].region;
        observations.set(`${region.nx}:${region.ny}`, value);
      });
    } catch (error) {
      logCollectionFailure('aws_current_fallback', error);
    }
  }

  await Promise.all(pending.flatMap((region) => {
    const value = observations.get(`${region.nx}:${region.ny}`);
    if (!value) return [];
    return [saveCollectedCache(env.DB, {
      key: collectedCacheKey.ultraShortObservation(region.nx, region.ny),
      type: 'COLLECTED_ULTRA_SHORT',
      value,
      nx: region.nx,
      ny: region.ny,
      updatedAt: now,
    })];
  }));
}

async function collectCurrentPrecipitation(
  env: ServerEnv,
  targets: CollectionTarget[],
  locations: Array<{ latitude: number; longitude: number }>,
  now: Date,
  forceSourceRefresh = false,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY || locations.length === 0) return;
  const ultraByGrid = new Map<string, UltraShortObservation>();
  for (const region of distinctRegions(targets)) {
    const key = collectedCacheKey.ultraShortObservation(region.nx, region.ny);
    const record = await getCollectedCache<UltraShortObservation>(env.DB, key);
    if (record) ultraByGrid.set(`${region.nx}_${region.ny}`, record.value);
  }

  const targetByLocation = new Map(
    targets.flatMap((target) =>
      target.latitude === undefined || target.longitude === undefined
        ? []
        : [[locationCacheKey(target.latitude, target.longitude), target] as const],
    ),
  );
  const inputs = locations.flatMap((location) => {
    const target = targetByLocation.get(locationCacheKey(location.latitude, location.longitude));
    const reference = target && ultraByGrid.get(`${target.nx}_${target.ny}`);
    return reference ? [{ ...location, referenceRainDetected: reference.rainDetected,
      referenceObservedAt: reference.observedAt }] : [];
  });
  if (inputs.length === 0) return;
  const sourceVersion = latestRadarProductVersion(now);
  if (!forceSourceRefresh && await collectedSourceVersionIsCurrent(
    env.DB,
    'RADAR_15_MINUTES',
    sourceVersion,
  )) return;
  const reserved = await reserveApiHubBudget(
    env.DB,
    'RADAR_AND_POINT_VALIDATION',
    1 + ANALYSIS_VALIDATION_LIMIT,
    RADAR_BYTES + ANALYSIS_VALIDATION_LIMIT * 4_096,
    now,
  );
  if (!reserved) return;
  try {
    const observations = await new KmaPrecipitationObservationProvider({
      serviceKey: env.KMA_APIHUB_KEY,
      now: () => now,
      timeoutMs: 12_000,
      attempts: 1,
    }).getCurrentByLocations(inputs, ANALYSIS_VALIDATION_LIMIT);
    await Promise.all(observations.map((value) => saveCollectedCache(env.DB, {
      key: collectedCacheKey.precipitation(value.latitude, value.longitude),
      type: 'COLLECTED_PRECIPITATION',
      value,
      updatedAt: now,
    })));
    await saveCollectedSourceVersion(
      env.DB,
      'RADAR_15_MINUTES',
      sourceVersion,
      now,
    );
  } catch (error) {
    logCollectionFailure('precipitation', error);
  }
}

async function collectRoadIce(
  env: ServerEnv,
  locations: Array<{ latitude: number; longitude: number }>,
  now: Date,
  forceSourceRefresh = false,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY || locations.length === 0 || !isRoadIceSeason(now)) return;
  const sourceVersion = pollingWindowVersion(now, 30);
  if (!forceSourceRefresh && await collectedSourceVersionIsCurrent(
    env.DB,
    'ROAD_ICE_30_MINUTES',
    sourceVersion,
  )) return;
  if (!await reserveApiHubBudget(
    env.DB,
    'ROAD_ICE',
    ROAD_ICE_ROAD_NUMBERS.length,
    ROAD_ICE_ROAD_NUMBERS.length * 2_100_000,
    now,
  )) return;
  try {
    const values = await new KmaRoadIceProvider({
      serviceKey: env.KMA_APIHUB_KEY,
      now: () => now,
    }).getNearestRisksByLocations(locations);
    await Promise.all(locations.map((location, index) => saveCollectedCache<RoadIceRisk | null>(
      env.DB,
      {
        key: collectedCacheKey.roadIce(location.latitude, location.longitude),
        type: 'COLLECTED_ROAD_ICE',
        value: values[index] ?? null,
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
  if (!provider || locations.length === 0) return;
  const sourceVersion = pollingWindowVersion(now, 30);
  if (!forceSourceRefresh && await collectedSourceVersionIsCurrent(
    env.DB,
    'ROAD_CONTROL_30_MINUTES',
    sourceVersion,
  )) return;
  let failed = false;
  await mapWithConcurrency(locations, 2, async (location) => {
    try {
      const value = await provider.getNearestActiveControl(
        location.latitude,
        location.longitude,
      );
      await saveCollectedCache<OfficialRoadControl | null>(env.DB, {
        key: collectedCacheKey.roadControl(location.latitude, location.longitude),
        type: 'COLLECTED_ROAD_CONTROL',
        value: value ?? null,
        updatedAt: now,
      });
    } catch (error) {
      failed = true;
      logCollectionFailure('road_control', error);
    }
  });
  if (!failed) {
    await saveCollectedSourceVersion(
      env.DB,
      'ROAD_CONTROL_30_MINUTES',
      sourceVersion,
      now,
    );
  }
}

async function collectCurrentVisibility(
  env: ServerEnv,
  targets: CollectionTarget[],
  now: Date,
  forceSourceRefresh = false,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY) return;
  const regions = distinctRegions(targets).flatMap((target) => {
    const coordinates = kmaGridCoordinates(target.nx, target.ny);
    return coordinates ? [{ target, coordinates }] : [];
  });
  if (regions.length === 0) return;
  const currentHour = latestCompletedKoreanHour(now);
  const sourceVersion = ultraShortKoreanIso(currentHour);
  if (!forceSourceRefresh && await collectedSourceVersionIsCurrent(
    env.DB,
    'ASOS_VISIBILITY_HOURLY',
    sourceVersion,
  )) return;
  if (!await reserveApiHubBudget(
    env.DB,
    'ASOS_VISIBILITY',
    4,
    4 * 128_000,
    now,
  )) return;
  try {
    const provider = new KmaHourlyObservationProvider({
      serviceKey: env.KMA_APIHUB_KEY,
      now: () => now,
    });
    const current = await provider.getObservationsAt(currentHour, {
      includeVisibility: true,
    });
    const visibility = nearestVisibilityObservations(
      current,
      regions.map(({ coordinates }) => coordinates),
    );
    const missingCount = visibility.filter((value) => value === undefined).length;
    await Promise.all(regions.flatMap(({ target }, index) => {
      const value = visibility[index];
      if (!value) return [];
      return [saveCollectedCache(env.DB, {
        key: collectedCacheKey.visibility(target.nx, target.ny),
        type: 'COLLECTED_VISIBILITY',
        value,
        nx: target.nx,
        ny: target.ny,
        updatedAt: now,
      })];
    }));
    if (missingCount > 0) {
      throw new Error(`VISIBILITY_COLLECTION_INCOMPLETE:${missingCount}`);
    }
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

async function collectDailyObservations(
  env: ServerEnv,
  targets: CollectionTarget[],
  now: Date,
  options: {
    candidateDates?: string[];
    ignoreSourceVersion?: boolean;
  } = {},
): Promise<void> {
  if (!env.KMA_APIHUB_KEY) return;
  const calendarWeek = currentKoreanCalendarWeek(now);
  const endDate = previousKoreanDate(now);
  const candidateDates = options.candidateDates ?? calendarWeek.dates.filter(
    (date) => date <= endDate,
  );
  if (candidateDates.length === 0) return;
  if (!options.ignoreSourceVersion && await collectedSourceVersionIsCurrent(
    env.DB,
    'AWS_DAILY',
    endDate,
  )) return;
  const regions = distinctRegions(targets).flatMap((target) => {
    const coordinates = kmaGridCoordinates(target.nx, target.ny);
    return coordinates ? [{ target, coordinates }] : [];
  });
  const missingRegions: typeof regions = [];
  const cachedByRegion = new Map<string, CollectedCacheRecord<CollectedWeeklyBundle> | null>();
  let startDate = endDate;
  for (const region of regions) {
    const { target } = region;
    const regionKey = `${target.nx}_${target.ny}`;
    const cached = await getCollectedCache<CollectedWeeklyBundle>(
      env.DB,
      collectedCacheKey.weekly(target.nx, target.ny),
    );
    if (!cached) continue;
    const observedDates = new Set(
      cached?.value.observedDays
        .filter((day) => day.weatherDataComplete === true)
        .map((day) => compactCalendarDate(day.date)) ?? [],
    );
    const earliestMissing = candidateDates.find((date) => !observedDates.has(date));
    if (earliestMissing) {
      missingRegions.push(region);
      cachedByRegion.set(regionKey, cached);
      if (earliestMissing < startDate) startDate = earliestMissing;
    }
  }
  if (missingRegions.length === 0 || !await reserveApiHubBudget(
    env.DB,
    'AWS_DAILY',
    4,
    2_048_000,
    now,
  )) return;
  try {
    const values = await new KmaDailyObservationProvider({
      serviceKey: env.KMA_APIHUB_KEY,
    }).getDailyByLocations(
      missingRegions.map(({ coordinates }) => coordinates),
      startDate,
      endDate,
    );
    await Promise.all(missingRegions.flatMap(({ target }, index) => {
      const key = collectedCacheKey.weekly(target.nx, target.ny);
      const cached = cachedByRegion.get(`${target.nx}_${target.ny}`);
      if (!cached) return [];
      const incoming = values[index] ?? [];
      const incomingDates = new Set(incoming.map((day) => day.date));
      return [saveCollectedCache(env.DB, {
        key,
        type: 'COLLECTED_WEEKLY',
        value: {
          ...cached.value,
          observedDays: [
            ...cached.value.observedDays.filter(
              (day) => !incomingDates.has(day.date),
            ),
            ...incoming,
          ].sort((left, right) => left.date.localeCompare(right.date)),
          collectedAt: now.toISOString(),
        },
        nx: target.nx,
        ny: target.ny,
        updatedAt: now,
      })];
    }));
    await saveCollectedSourceVersion(env.DB, 'AWS_DAILY', endDate, now);
  } catch (error) {
    logCollectionFailure('daily_observation', error);
  }
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

function distinctLocations(
  targets: CollectionTarget[],
): Array<{ latitude: number; longitude: number }> {
  return [...new Map(targets.flatMap((target) =>
    target.latitude === undefined || target.longitude === undefined
      ? []
      : [[locationCacheKey(target.latitude, target.longitude), {
          latitude: target.latitude,
          longitude: target.longitude,
        }] as const],
  )).values()];
}

function koreanHour(now: Date): number {
  return new Date(now.getTime() + 9 * 60 * 60 * 1000).getUTCHours();
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
