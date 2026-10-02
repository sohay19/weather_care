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
  GRID_OBSERVATION_VARIABLES,
  REQUIRED_GRID_OBSERVATION_VARIABLES,
  gridObservationKoreanIso,
  KmaGridObservationProvider,
  latestGridObservationTime,
} from '../providers/weather/kmaGridObservationProvider';
import { KmaAwsMinuteObservationProvider } from '../providers/weather/kmaAwsMinuteObservationProvider';
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
  ROAD_ICE_ROAD_NUMBERS,
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
  latestCompletedKoreanHour,
  nearestVisibilityObservations,
} from '../providers/weather/kmaHourlyObservationProvider';
import { KmaDailyObservationProvider } from '../providers/weather/kmaDailyObservationProvider';
import {
  latestMidTermIssueTimes,
} from '../providers/weather/kmaMidTermProvider';
import { KmaUvProvider, latestUvPublicationTimes } from '../providers/uv/kmaUvProvider';
import {
  AirKoreaForecastProvider,
  airKoreaForecastAreaForGrid,
  type DailyAirQualityForecastAtDate,
} from '../providers/air/airKoreaForecastProvider';
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
import {
  reserveApiHubBudget,
  reserveMonthlyRequestBudget,
} from '../database/apiUsageRepository';
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
const NATIONWIDE_ANALYSIS_BYTES = 16_793_608;
const ANALYSIS_VALIDATION_LIMIT = 40;
const ITS_MONTHLY_REQUEST_LIMIT = 9_000;
const FAST_OBSERVATION_DAILY_BYTE_LIMIT = 1_000_000_000;

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
    const nationwideAir = precollectNationwide
      ? await collectNationwideAirQuality(env, now)
      : undefined;
    const nationwideAirForecast = precollectNationwide
      ? await collectNationwideAirForecast(env, now)
      : undefined;
    if (collectActiveDetails) {
      await collectUltraShortObservations(env, allForecastTargets, now, activeRegions);
    }
    await collectRegionForecasts(
      env, regions, activeRegionKeys, now, nationwideAir, nationwideAirForecast,
    );
    if (collectActiveDetails) {
      await collectWarnings(env, allForecastTargets, now, forceSourceRefresh);
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

async function collectNationwideAirQuality(
  env: ServerEnv,
  now: Date,
): Promise<NationwideAirQualitySnapshot | null> {
  const key = collectedCacheKey.nationwideAir;
  const cached = await getCollectedCache<NationwideAirQualitySnapshot>(env.DB, key);
  if (cacheRecordIsFresh(cached, 2 * 60 * 60 * 1000, now)) return cached!.value;
  try {
    const provider = new AirKoreaAirQualityProvider({
      serviceKey: env.KMA_SERVICE_KEY, now: () => now, timeoutMs: 10_000,
    });
    const catalog = await provider.getStationCatalog();
    const provinces = await mapWithConcurrency(
      AIRKOREA_PROVINCES, 3,
      (province) => provider.getProvinceMeasurements(province),
    );
    const observations = provinces.flat();
    if (observations.length === 0) throw new Error('AirKorea returned no national measurements');
    const snapshot = { catalog, observations, collectedAt: now.toISOString() };
    await saveCollectedCache(env.DB, {
      key, type: 'COLLECTED_NATIONWIDE_AIR', value: snapshot, updatedAt: now,
    });
    return snapshot;
  } catch (error) {
    logCollectionFailure('nationwide_air', error);
    return cacheRecordIsFresh(cached, 3 * 60 * 60 * 1000, now)
      ? cached!.value
      : null;
  }
}

interface NationwideAirForecast {
  issue: string;
  areas: Record<string, DailyAirQualityForecastAtDate[]>;
}

async function collectNationwideAirForecast(
  env: ServerEnv,
  now: Date,
): Promise<NationwideAirForecast | null> {
  const key = collectedCacheKey.nationwideAirForecast;
  const cached = await getCollectedCache<NationwideAirForecast>(env.DB, key);
  const issue = latestAirKoreaForecastIssue(now);
  if (cached?.value.issue === issue) return cached.value;
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

async function collectRegionForecasts(
  env: ServerEnv,
  regions: CollectionTarget[],
  activeRegionKeys: ReadonlySet<string>,
  now: Date,
  nationwideAir?: NationwideAirQualitySnapshot | null,
  nationwideAirForecast?: NationwideAirForecast | null,
): Promise<void> {
  await mapWithConcurrency(regions, nationwideAir === undefined ? 2 : 6, async ({ nx, ny }) => {
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
      if (shouldRefreshEnvironmentalRecord(environmentalRecord, now)) {
        const environmental = await loadEnvironmentalData(
          env,
          regionMetadataForGrid(nx, ny),
          {
            now, nx, ny, coordinates: kmaGridCoordinates(nx, ny),
            providerTimeoutMs: 7_500,
            uvFreshMs: includeSupplemental ? undefined : 6 * 60 * 60 * 1000,
            nationwideAir,
          },
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
        environmentalRecord?.value,
        nationwideAirForecast,
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
  environmental?: EnvironmentalDataBundle,
  nationwideAirForecast?: NationwideAirForecast | null,
): Promise<void> {
  const key = collectedCacheKey.weekly(nx, ny);
  const cached = await getCollectedCache<CollectedWeeklyBundle>(env.DB, key);
  const sameForecastIssue = cached?.value.forecast?.baseDate === forecast?.baseDate &&
    cached?.value.forecast?.baseTime === forecast?.baseTime;
  if (!includeSupplemental) {
    if (sameForecastIssue &&
        cached?.value.uvIssue === (environmental?.uv?.issuedAt ?? cached?.value.uvIssue) &&
        cached?.value.airQualityIssue === (nationwideAirForecast?.issue ?? cached?.value.airQualityIssue)) {
      return;
    }
    const area = airKoreaForecastAreaForGrid(nx, ny);
    await saveCollectedCache(env.DB, {
      key,
      type: 'COLLECTED_WEEKLY',
      value: {
        forecast,
        midTermDays: cached?.value.midTermDays ?? [],
        observedDays: cached?.value.observedDays ?? [],
        uv: environmental?.uv ?? cached?.value.uv,
        airQuality: area
          ? nationwideAirForecast?.areas[area] ?? cached?.value.airQuality ?? []
          : cached?.value.airQuality ?? [],
        midTermIssue: cached?.value.midTermIssue,
        midTermTaRegId: cached?.value.midTermTaRegId,
        midTermLandRegId: cached?.value.midTermLandRegId,
        uvIssue: environmental?.uv?.issuedAt ?? cached?.value.uvIssue,
        airQualityIssue: nationwideAirForecast?.issue ?? cached?.value.airQualityIssue,
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
    if (environmental?.uv) {
      uv = environmental.uv;
      resolvedUvIssue = uv.issuedAt;
    } else if (!uvAreaNo) {
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
      const area = airKoreaForecastAreaForGrid(nx, ny);
      if (area && nationwideAirForecast?.areas[area]) {
        airQuality = nationwideAirForecast.areas[area];
        resolvedAirQualityIssue = nationwideAirForecast.issue;
      } else {
        airQuality = await new AirKoreaForecastProvider({
          serviceKey: env.KMA_SERVICE_KEY,
          now: () => now,
        }).getForecast(undefined, nx, ny);
        resolvedAirQualityIssue = airQualityIssue;
      }
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
    env.DB, 'WARNING_30_MINUTES', sourceVersion,
  )) return;

  const provider = new KmaWarningProvider({ serviceKey: env.KMA_APIHUB_KEY });
  try {
    const cachedStations = await getCollectedCache<KmaWarningRegionStation[]>(
      env.DB, collectedCacheKey.warningStations,
    );
    let stations = cachedStations?.value;
    if (!cacheRecordIsFresh(cachedStations, 24 * 60 * 60 * 1000, now)) {
      if (!await reserveApiHubBudget(
        env.DB, 'WARNING_REGION_MAPPING', 1, 1_000_000, now,
      )) return;
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
    if (!await reserveApiHubBudget(env.DB, 'WARNING', 1, 256_000, now)) return;
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
  if (!env.KMA_APIHUB_KEY || regions.length === 0) {
    console.warn(JSON.stringify({
      event: 'current_observation_collection_skipped',
      reason: !env.KMA_APIHUB_KEY ? 'APIHUB_KEY_MISSING' : 'NO_REGIONS',
    }));
    return;
  }
  // 발표가 빠른 회차는 현재 10분 구간에서 먼저 받고, 미발표면 직전 구간을 쓴다.
  const targetClock = new Date(
    latestGridObservationTime(now).getTime() + 10 * 60 * 1000,
  );
  const expectedObservedAt = gridObservationKoreanIso(targetClock);
  const activeKeys = new Set(activeRegions.map(({ nx, ny }) => `${nx}:${ny}`));
  const cached = new Map<string, CollectedCacheRecord<UltraShortObservation> | null>();
  const pending: CollectionTarget[] = [];
  for (const region of regions) {
    const record = await getCollectedCache<UltraShortObservation>(
      env.DB,
      collectedCacheKey.ultraShortObservation(region.nx, region.ny),
    );
    cached.set(`${region.nx}:${region.ny}`, record);
    if (record?.status !== 'AVAILABLE' ||
        record.value.observedAt < expectedObservedAt) {
      pending.push(region);
    }
  }
  const observations = new Map<string, UltraShortObservation>();
  let stored = 0;
  let latestGridCount = 0;
  let previousGridCount = 0;
  let awsCount = 0;
  const gridProvider = new KmaGridObservationProvider({
    serviceKey: env.KMA_APIHUB_KEY,
  });
  const fetchGrid = async (
    targets: CollectionTarget[],
    clock: Date,
    slot: 'LATEST' | 'PREVIOUS',
  ): Promise<void> => {
    if (targets.length === 0) return;
    const variableCount = fastRetry
      ? REQUIRED_GRID_OBSERVATION_VARIABLES.length
      : GRID_OBSERVATION_VARIABLES.length;
    const reserved = await reserveApiHubBudget(
      env.DB,
      fastRetry ? 'GRID_OBSERVATION_FAST_RETRY' : 'GRID_OBSERVATION_10_MINUTES',
      variableCount,
      variableCount * 1_000_000,
      now,
      fastRetry ? {
        providerDailyByteLimit: FAST_OBSERVATION_DAILY_BYTE_LIMIT,
        dailyByteLimit: 3_500_000_000,
      } : undefined,
    );
    if (!reserved) {
      console.warn(JSON.stringify({
        event: 'current_observation_budget_denied',
        source: 'GRID',
        slot,
      }));
      return;
    }
    try {
      const exact = await gridProvider.getAt(targets, clock, {
        requiredOnly: fastRetry,
      });
      if (slot === 'LATEST') latestGridCount = exact.size;
      else previousGridCount = exact.size;
      for (const [key, value] of exact) observations.set(key, value);
    } catch (error) {
      logCollectionFailure('grid_observation', error, {
        slot,
        targetObservedAt: gridObservationKoreanIso(clock),
      });
    }
  };
  await fetchGrid(pending, targetClock, 'LATEST');

  const previousClock = new Date(targetClock.getTime() - 10 * 60 * 1000);
  const previousObservedAt = gridObservationKoreanIso(previousClock);
  const previousPending = pending.filter(({ nx, ny }) => {
    const key = `${nx}:${ny}`;
    const record = cached.get(key);
    return !observations.has(key) &&
      (record?.status !== 'AVAILABLE' ||
        record.value.observedAt < previousObservedAt);
  });
  await fetchGrid(previousPending, previousClock, 'PREVIOUS');

  const missingGrid = pending.filter(
    (region) => !observations.has(`${region.nx}:${region.ny}`),
  );
  const fallbackTargets = (fastRetry ? [] : missingGrid).flatMap((region) => {
    const coordinates = region.latitude !== undefined &&
        region.longitude !== undefined
      ? { latitude: region.latitude, longitude: region.longitude }
      : kmaGridCoordinates(region.nx, region.ny);
    return coordinates ? [{ region, coordinates }] : [];
  });
  const awsReserved = fallbackTargets.length > 0 && await reserveApiHubBudget(
    env.DB,
    'AWS_CURRENT_FALLBACK',
    14,
    3_000_000,
    now,
  );
  if (fallbackTargets.length > 0 && !awsReserved) {
    console.warn(JSON.stringify({
      event: 'current_observation_budget_denied',
      source: 'AWS_FALLBACK',
    }));
  }
  if (awsReserved) {
    try {
      const fallback = await new KmaAwsMinuteObservationProvider({
        serviceKey: env.KMA_APIHUB_KEY,
        now: () => now,
      }).getCurrentByLocations(fallbackTargets.map(({ coordinates }) => coordinates));
      fallback.forEach((value, index) => {
        if (!value) return;
        awsCount += 1;
        const region = fallbackTargets[index].region;
        observations.set(`${region.nx}:${region.ny}`, value);
      });
    } catch (error) {
      logCollectionFailure('aws_current_fallback', error);
    }
  }

  await Promise.all(pending.flatMap((region) => {
    const key = `${region.nx}:${region.ny}`;
    const value = observations.get(key);
    if (!value || (cached.get(key)?.value.observedAt ?? '') >= value.observedAt) {
      return [];
    }
    stored += 1;
    return [saveCollectedCache(env.DB, {
      key: collectedCacheKey.ultraShortObservation(region.nx, region.ny),
      type: 'COLLECTED_ULTRA_SHORT',
      value,
      nx: region.nx,
      ny: region.ny,
      updatedAt: now,
    })];
  }));
  const missing = pending.filter(({ nx, ny }) =>
    !observations.has(`${nx}:${ny}`));
  const expiredActive = pending.filter(({ nx, ny }) => {
    const key = `${nx}:${ny}`;
    if (!activeKeys.has(key)) return false;
    const cachedAt = cached.get(key)?.value.observedAt;
    const fetchedAt = observations.get(key)?.observedAt;
    const newestAt = Math.max(
      cachedAt ? Date.parse(cachedAt) : -Infinity,
      fetchedAt ? Date.parse(fetchedAt) : -Infinity,
    );
    return !Number.isFinite(newestAt) ||
      now.getTime() - newestAt > 30 * 60 * 1000;
  });
  console.log(JSON.stringify({
    event: 'current_observation_collection_completed',
    targetObservedAt: expectedObservedAt,
    regions: regions.length,
    pending: pending.length,
    latestGridCount,
    awsCount,
    previousGridCount,
    stored,
    missing: missing.length,
    activeMissing: missing.filter(({ nx, ny }) =>
      activeKeys.has(`${nx}:${ny}`)).slice(0, 50)
      .map(({ nx, ny }) => `${nx}:${ny}`),
    missingSample: missing.slice(0, 10).map(({ nx, ny }) => `${nx}:${ny}`),
  }));
  if (expiredActive.length > 0) {
    console.error(JSON.stringify({
      event: 'current_observation_freshness_breached',
      targetObservedAt: expectedObservedAt,
      count: expiredActive.length,
      grids: expiredActive.slice(0, 50)
        .map(({ nx, ny }) => `${nx}:${ny}`),
    }));
  }
}

async function collectCurrentPrecipitation(
  env: ServerEnv,
  targets: CollectionTarget[],
  locations: Array<{ latitude: number; longitude: number }>,
  now: Date,
  forceSourceRefresh = false,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY) return;
  if (env.NATIONWIDE_PRECOLLECT_ENABLED === 'true' &&
      await collectNationwidePrecipitation(env, locations, now, forceSourceRefresh)) {
    return;
  }
  if (locations.length === 0) return;
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
    return reference ? [{ ...location,
      referenceRainDetected: reference.qualityFlags?.includes(
        'PRECIPITATION_TYPE_UNAVAILABLE',
      ) ? undefined : reference.rainDetected,
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

async function collectNationwidePrecipitation(
  env: ServerEnv,
  locations: Array<{ latitude: number; longitude: number }>,
  now: Date,
  forceSourceRefresh: boolean,
): Promise<boolean> {
  // Winter road-ice archives share the same daily APIHub byte allowance.
  if (!forceSourceRefresh && isRoadIceSeason(now) &&
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
  if (!await reserveApiHubBudget(
    env.DB,
    'NATIONWIDE_ANALYSIS_AND_RADAR',
    2,
    NATIONWIDE_ANALYSIS_BYTES + RADAR_BYTES,
    now,
  )) return false;
  try {
    const snapshot = await new KmaPrecipitationObservationProvider({
      serviceKey: env.KMA_APIHUB_KEY!,
      now: () => now,
      timeoutMs: 45_000,
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
  if (!await reserveApiHubBudget(
    env.DB,
    'ROAD_ICE',
    ROAD_ICE_ROAD_NUMBERS.length,
    ROAD_ICE_ROAD_NUMBERS.length * 2_100_000,
    now,
  )) return;
  try {
    const segments = await new KmaRoadIceProvider({
      serviceKey: env.KMA_APIHUB_KEY,
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
