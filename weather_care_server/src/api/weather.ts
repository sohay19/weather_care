import { Hono } from 'hono';
import { installationOwnerHash } from '../security/installationAccess';
import {
  NotificationSettings,
  CurrentPrecipitationObservation,
  OfficialRoadControl,
  RoadIceRisk,
  Recommendation,
  ServerEnv,
  TodayWeatherResponse,
  WeatherMessagePart,
  WeatherSnapshot,
} from '../types';
import { KmaWeatherProvider } from '../providers/weather/kmaWeatherProvider';
import {
  DailyWeatherForecast,
  WeatherForecast,
} from '../providers/weather/weatherProvider';
import {
  DECISION_VERSION,
  runWeatherRuleEngine,
  runWeatherRuleEngineForHourly,
} from '../rules/weatherRuleEngine';
import { runLifestyleWeatherEngine } from '../lifestyle/lifestyleWeatherEngine';
import { runRecommendationEngine } from '../recommendations/recommendationEngine';
import {
  getCurrentWeather,
  saveCurrentWeather,
} from '../database/weatherCacheRepository';
import { coordinatesFromQuery, regionFromQuery } from '../utils';
import { CATALOG_VERSION } from '../recommendations/recommendationTemplates';
import { buildWeatherBriefResult } from '../presentation/weatherBrief';
import {
  buildEnvironmentalDataStatusMessages,
  buildLifestyleMessages,
} from '../presentation/lifestyleMessages';
import {
  enrichForecastWithEnvironmentalData,
  EnvironmentalDataBundle,
  loadEnvironmentalData,
} from '../providers/environmental/environmentalDataService';
import {
  regionMetadataForGrid,
  regionName,
} from '../regions/regionCatalog';
import {
  defaultNotificationSettings,
  getNotificationSettings,
} from '../database/notificationSettingsRepository';
import { KmaPrecipitationObservationProvider } from '../providers/precipitation/precipitationObservationProvider';
import { buildCurrentPrecipitationMessage } from '../presentation/currentPrecipitationMessage';
import {
  KmaWarningProvider,
  OfficialWeatherWarning,
} from '../providers/warnings/kmaWarningProvider';
import { buildActiveWarningMessages } from '../presentation/officialWarningMessages';
import { RegionMetadata } from '../regions/regionCatalog';
import { KmaRoadIceProvider } from '../providers/road/kmaRoadIceProvider';
import { buildRoadIceMessage } from '../presentation/roadIceMessage';
import { itsRoadControlProviderFromEnvironment } from '../providers/traffic/itsRoadControlProvider';
import { buildRoadControlMessage } from '../presentation/roadControlMessage';
import { providerErrorDiagnostic, safeErrorName } from '../observability/providerErrorDiagnostics';
import { defaultRuleConfig } from '../config/ruleConfig';
import { precipitationPeriod, precipitationLabel, koreaDate, precipitationOnlySnapshot,
  withoutPrecipitation } from '../rules/precipitationWindows';
import { KmaMidTermProvider } from '../providers/weather/kmaMidTermProvider';
import { resolveKmaMidTermRegionIds } from '../regions/kmaMidTermRegionCatalog';
import { KmaDailyObservationProvider } from '../providers/weather/kmaDailyObservationProvider';
import { kmaGridCoordinates } from '../regions/kmaGridCoordinates';
import { KmaUvProvider } from '../providers/uv/kmaUvProvider';
import type { UvForecast } from '../providers/uv/uvProvider';
import { uvAreaNoForGrid } from '../regions/kmaUvAreaGridCatalog';
import {
  AirKoreaForecastProvider,
  type DailyAirQualityForecastAtDate,
} from '../providers/air/airKoreaForecastProvider';
import {
  currentKoreanCalendarWeek,
  getWeeklyForecastRecords,
  koreanCalendarDate,
  saveWeeklyForecastRecords,
} from '../database/weeklyForecastRepository';

const router = new Hono<{ Bindings: ServerEnv }>();
router.use('*', async (c, next) => {
  if (c.req.header('Authorization')) c.header('Cache-Control', 'private, no-store');
  await next();
});
const TODAY_OPTIONAL_PROVIDER_BUDGET_MS = 3_500;
// A cold 13 MB radar composite regularly needs more than the shared 3.5 s
// optional-source deadline. Keep it within the app's 20 s API timeout.
const CURRENT_PRECIPITATION_PROVIDER_BUDGET_MS = 8_000;

interface TimedResult<T> {
  value: T;
  timedOut: boolean;
}

interface OptionalProviderTimeouts {
  precipitation: boolean;
  warning: boolean;
  roadIce: boolean;
  roadControl: boolean;
}

router.get('/main', async (c) => {
  const { nx, ny } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
  if (!c.env.KMA_SERVICE_KEY) {
    return c.json({ error: 'KMA_SERVICE_KEY_NOT_CONFIGURED' }, 503);
  }

  try {
    const generatedAt = new Date();
    let cached: WeatherSnapshot | null = null;
    if (c.env.DB) {
      try {
        cached = await getCurrentWeather(c.env.DB, nx, ny);
      } catch (error) {
        console.error(JSON.stringify({
          event: 'main_weather_cache_load_failed',
          error: safeErrorName(error),
        }));
      }
    }

    const cachedIsFresh = cached !== null &&
      isFreshMainSnapshot(cached, generatedAt);
    const forecast = cachedIsFresh
      ? forecastFromCachedSnapshot(cached)
      : await new KmaWeatherProvider({
          serviceKey: c.env.KMA_SERVICE_KEY,
        }).getLatestForecastByRegion(nx, ny);
    const brief = buildWeatherBriefResult(forecast, {
      regionKey: `${nx}:${ny}`,
      now: generatedAt,
    });
    const environmental = unavailableEnvironmentalData();
    const response: TodayWeatherResponse = {
      dataSource: cachedIsFresh ? '기상청 빠른 캐시' : forecast.dataSource,
      region: { nx, ny, name: regionName(nx, ny, '선택 지역') },
      brief: brief.text,
      briefExpiresAt: brief.expiresAt,
      current: forecast.current,
      hourly: [],
      recommendations: [],
      lifestyleMessages: [],
      dataStatusMessages: [],
      timeline: [],
      environmentalSources: environmental.sources,
      decisionVersion: DECISION_VERSION,
      catalogVersion: CATALOG_VERSION,
      generatedAt: generatedAt.toISOString(),
    };

    if (!cachedIsFresh && c.env.DB) {
      c.executionCtx.waitUntil(
        saveCurrentWeather(c.env.DB, nx, ny, forecast.current).catch(
          (error: unknown) => {
            console.error(JSON.stringify({
              event: 'main_weather_cache_persistence_failed',
              error: safeErrorName(error),
            }));
          },
        ),
      );
    }
    return c.json(response);
  } catch (error) {
    logProviderError('main', error);
    return c.json({ error: 'WEATHER_PROVIDER_UNAVAILABLE' }, 502);
  }
});

router.get('/today', async (c) => {
  const { nx, ny } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
  const coordinates = coordinatesFromQuery(
    c.req.query('latitude'),
    c.req.query('longitude'),
  );
  if (!c.env.KMA_SERVICE_KEY) {
    return c.json({ error: 'KMA_SERVICE_KEY_NOT_CONFIGURED' }, 503);
  }

  try {
    const region = regionMetadataForGrid(nx, ny);
    const weatherForecastPromise = new KmaWeatherProvider({
      serviceKey: c.env.KMA_SERVICE_KEY,
    }).getForecastByRegion(nx, ny);
    const environmentalDataPromise = loadEnvironmentalData(
      c.env,
      region,
      { nx, ny, coordinates },
    );
    const settingsPromise = settingsForRequest(
      c.env.DB,
      c.req.query('installationId'),
      c.req.header('Authorization'),
    );
    const precipitationPromise = loadCurrentPrecipitation(c.env, coordinates);
    const warningPromise = loadActiveWarnings(c.env, region, coordinates);
    const roadIcePromise = loadRoadIce(c.env, coordinates);
    const roadControlPromise = loadRoadControl(c.env, coordinates);
    const optionalPromises = [
      environmentalDataPromise,
      precipitationPromise,
      warningPromise,
      roadIcePromise,
      roadControlPromise,
    ] as const;

    c.executionCtx.waitUntil(
      Promise.allSettled(optionalPromises).then(() => undefined),
    );

    const [
      weatherForecast,
      settings,
      environmentalResult,
      precipitationResult,
      warningResult,
      roadIceResult,
      roadControlResult,
    ] = await Promise.all([
      weatherForecastPromise,
      settingsPromise,
      settleWithin(
        environmentalDataPromise,
        unavailableEnvironmentalData(),
        TODAY_OPTIONAL_PROVIDER_BUDGET_MS,
      ),
      settleWithin(
        precipitationPromise,
        undefined,
        CURRENT_PRECIPITATION_PROVIDER_BUDGET_MS,
      ),
      settleWithin(
        warningPromise,
        { warnings: [], regionName: region?.name },
        TODAY_OPTIONAL_PROVIDER_BUDGET_MS,
      ),
      settleWithin(
        roadIcePromise,
        undefined,
        TODAY_OPTIONAL_PROVIDER_BUDGET_MS,
      ),
      settleWithin(
        roadControlPromise,
        undefined,
        TODAY_OPTIONAL_PROVIDER_BUDGET_MS,
      ),
    ]);
    const environmentalData = environmentalResult.value;
    const precipitation = precipitationResult.value;
    const warningsResultValue = warningResult.value;
    const roadIce = roadIceResult.value;
    const roadControl = roadControlResult.value;
    const optionalTimeouts: OptionalProviderTimeouts = {
      precipitation: precipitationResult.timedOut,
      warning: warningResult.timedOut,
      roadIce: roadIceResult.timedOut,
      roadControl: roadControlResult.timedOut,
    };
    logOptionalProviderTimeouts({
      environmental: environmentalResult.timedOut,
      ...optionalTimeouts,
    });
    const forecast = enrichForecastWithEnvironmentalData(
      weatherForecast,
      environmentalData,
    );
    const decisionHourly = forecast.hourly.slice(0, 24);
    const rules = runWeatherRuleEngineForHourly(decisionHourly);
    const lifestyle = runLifestyleWeatherEngine(rules, decisionHourly);
    const recommendations = runRecommendationEngine(lifestyle, settings);
    const regionLabel = regionName(
      nx,
      ny,
      coordinates ? '현재 위치' : '선택 지역',
    );

    const forecastLifestyleMessages = buildLifestyleMessages(
      lifestyle,
      rules,
      decisionHourly,
      regionLabel,
    );
    const currentPrecipitationMessage = buildCurrentPrecipitationMessage(
      precipitation,
      settings.umbrellaEnabled,
    );
    const warnings = warningsResultValue.warnings;
    const warningMessages = buildActiveWarningMessages(
      warnings,
      warningsResultValue.regionName ?? regionLabel,
    );
    const roadIceMessage = buildRoadIceMessage(roadIce, regionLabel);
    const roadControlMessage = buildRoadControlMessage(roadControl);
    const generatedAt = new Date();
    const brief = buildWeatherBriefResult(forecast, { regionKey: `${nx}:${ny}`, now: generatedAt });
    const response: TodayWeatherResponse = {
      dataSource: forecast.dataSource,
      region: { nx, ny, name: regionLabel },
      brief: brief.text,
      briefExpiresAt: brief.expiresAt,
      current: {
        ...forecast.current,
        activeWarnings: warnings,
      },
      currentPrecipitation: precipitation,
      currentRoadIce: roadIce,
      currentRoadControl: roadControl,
      hourly: forecast.hourly,
      recommendations,
      lifestyleMessages: [
        ...warningMessages,
        ...(roadControlMessage ? [roadControlMessage] : []),
        ...(roadIceMessage ? [roadIceMessage] : []),
        ...(currentPrecipitationMessage ? [currentPrecipitationMessage] : []),
        ...forecastLifestyleMessages,
      ],
      dataStatusMessages: [
        ...buildEnvironmentalDataStatusMessages(environmentalData.sources),
        ...buildOptionalProviderTimeoutStatusMessages(optionalTimeouts),
      ],
      timeline: buildTimeline(
        forecast.timelineHourly ?? forecast.hourly,
        settings,
        generatedAt.toISOString(),
      ),
      environmentalSources: environmentalData.sources,
      decisionVersion: DECISION_VERSION,
      catalogVersion: CATALOG_VERSION,
      generatedAt: generatedAt.toISOString(),
    };

    if (c.env.DB) {
      c.executionCtx.waitUntil(
        saveCurrentWeather(c.env.DB, nx, ny, forecast.current)
          .catch((error: unknown) => {
            console.error(
              JSON.stringify({
                event: 'weather_snapshot_persistence_failed',
                error: safeErrorName(error),
              }),
            );
          }),
      );
    }
    return c.json(response);
  } catch (error) {
    logProviderError('today', error);
    return c.json({ error: 'WEATHER_PROVIDER_UNAVAILABLE' }, 502);
  }
});

async function loadCurrentPrecipitation(
  env: ServerEnv,
  coordinates: { latitude: number; longitude: number } | undefined,
): Promise<CurrentPrecipitationObservation | undefined> {
  if (!coordinates || !env.KMA_APIHUB_KEY) return undefined;
  try {
    return await new KmaPrecipitationObservationProvider({
      serviceKey: env.KMA_APIHUB_KEY,
    }).getCurrentByLocation(coordinates.latitude, coordinates.longitude);
  } catch (error) {
    console.error(
      JSON.stringify({
        event: 'current_precipitation_provider_failed',
        provider: 'KMA_ANALYSIS_RADAR',
        ...providerErrorDiagnostic(error),
      }),
    );
    return undefined;
  }
}

async function loadRoadControl(
  env: ServerEnv,
  coordinates: { latitude: number; longitude: number } | undefined,
): Promise<OfficialRoadControl | undefined> {
  if (!coordinates) return undefined;
  try {
    const provider = itsRoadControlProviderFromEnvironment(env);
    if (!provider) return undefined;
    return await provider.getNearestActiveControl(
      coordinates.latitude,
      coordinates.longitude,
    );
  } catch (error) {
    console.error(
      JSON.stringify({
        event: 'road_control_provider_failed',
        provider: 'ITS_EVENT_INFO',
        ...providerErrorDiagnostic(error),
      }),
    );
    return undefined;
  }
}

async function loadRoadIce(
  env: ServerEnv,
  coordinates: { latitude: number; longitude: number } | undefined,
): Promise<RoadIceRisk | undefined> {
  if (!env.KMA_APIHUB_KEY || !coordinates) return undefined;
  try {
    return await new KmaRoadIceProvider({
      serviceKey: env.KMA_APIHUB_KEY,
    }).getNearestRiskByLocation(
      coordinates.latitude,
      coordinates.longitude,
    );
  } catch (error) {
    console.error(
      JSON.stringify({
        event: 'road_ice_provider_failed',
        provider: 'KMA_ROAD_RISK',
        ...providerErrorDiagnostic(error),
      }),
    );
    return undefined;
  }
}

async function loadActiveWarnings(
  env: ServerEnv,
  region: RegionMetadata | undefined,
  coordinates: { latitude: number; longitude: number } | undefined,
): Promise<{
  warnings: OfficialWeatherWarning[];
  regionName?: string;
}> {
  if (!env.KMA_APIHUB_KEY) return { warnings: [] };
  try {
    const provider = new KmaWarningProvider({
      serviceKey: env.KMA_APIHUB_KEY,
    });
    if (region) {
      return {
        warnings: await provider.getActiveForRegions(region.warningRegionIds),
        regionName: region.name,
      };
    }
    if (!coordinates) return { warnings: [] };
    const matchedRegion = await provider.resolveRegionByLocation(
      coordinates.latitude,
      coordinates.longitude,
    );
    return {
      warnings: await provider.getActiveForRegions([matchedRegion.regionId]),
      regionName: matchedRegion.regionName,
    };
  } catch (error) {
    console.error(
      JSON.stringify({
        event: 'official_warning_provider_failed',
        provider: 'KMA_WARNING_STATUS',
        ...providerErrorDiagnostic(error),
      }),
    );
    return { warnings: [], regionName: region?.name };
  }
}

router.get('/weekly', async (c) => {
  const { nx, ny } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
  if (!c.env.KMA_SERVICE_KEY && !c.env.KMA_APIHUB_KEY) {
    return c.json({ error: 'KMA_SERVICE_KEY_NOT_CONFIGURED' }, 503);
  }

  try {
    const now = new Date();
    const regionId = `${nx}_${ny}`;
    const calendarWeek = currentKoreanCalendarWeek(now);
    const today = koreanCalendarDate(now);
    const includeExtras = c.req.query('includeExtras') === 'true';
    const requestedRegionName = c.req.query('regionName');
    const midTermRegion = resolveKmaMidTermRegionIds(
      c.req.query('regionName'),
      c.req.query('regionCode'),
      nx,
      ny,
    );
    const shortTermPromise = c.env.KMA_SERVICE_KEY
      ? new KmaWeatherProvider({
          serviceKey: c.env.KMA_SERVICE_KEY,
        }).getForecastByRegion(nx, ny).catch((error: unknown) => {
          logProviderError('weekly', error);
          return undefined;
        })
      : Promise.resolve(undefined);
    const midTermPromise = midTermRegion &&
      (c.env.KMA_APIHUB_KEY || c.env.KMA_SERVICE_KEY)
      ? new KmaMidTermProvider({
          apiHubKey: c.env.KMA_APIHUB_KEY,
          serviceKey: c.env.KMA_SERVICE_KEY,
        })
          .getForecast(midTermRegion)
          .catch((error: unknown) => {
            console.error(JSON.stringify({
              event: 'mid_term_weather_provider_failed',
              provider: 'KMA_MID_TERM',
              ...providerErrorDiagnostic(error),
            }));
            return [];
          })
      : Promise.resolve([] as DailyWeatherForecast[]);
    const observationCoordinates = kmaGridCoordinates(nx, ny);
    const observationEnd = calendarWeek.dates
      .filter((date) => date < today)
      .at(-1);
    const observationPromise = c.env.KMA_APIHUB_KEY &&
      observationCoordinates &&
      observationEnd
      ? new KmaDailyObservationProvider({
          serviceKey: c.env.KMA_APIHUB_KEY,
          timeoutMs: 7_500,
        }).getDailyByLocation(
          observationCoordinates.latitude,
          observationCoordinates.longitude,
          calendarWeek.startDate,
          observationEnd,
        ).catch((error: unknown) => {
          console.error(JSON.stringify({
            event: 'daily_weather_observation_provider_failed',
            provider: 'KMA_DAILY_OBSERVATION',
            ...providerErrorDiagnostic(error),
          }));
          return [];
        })
      : Promise.resolve([] as DailyWeatherForecast[]);
    const savedPromise = c.env.DB
      ? getWeeklyForecastRecords(
          c.env.DB,
          regionId,
          calendarWeek.startDate,
          calendarWeek.endDate,
        ).catch((error: unknown) => {
          console.error(JSON.stringify({
            event: 'weekly_forecast_history_load_failed',
            error: safeErrorName(error),
          }));
          return [];
        })
      : Promise.resolve([] as DailyWeatherForecast[]);
    const uvAreaNo = includeExtras ? uvAreaNoForGrid(nx, ny) : undefined;
    const uvPromise = includeExtras && uvAreaNo && c.env.KMA_SERVICE_KEY
      ? new KmaUvProvider({ serviceKey: c.env.KMA_SERVICE_KEY })
          .getForecast(uvAreaNo)
          .catch((error: unknown) => {
            console.error(JSON.stringify({
              event: 'weekly_uv_provider_failed',
              provider: 'KMA_LIVING_INDEX_V5',
              ...providerErrorDiagnostic(error),
            }));
            return undefined;
          })
      : Promise.resolve(undefined);
    const airPromise = includeExtras && c.env.KMA_SERVICE_KEY
      ? new AirKoreaForecastProvider({ serviceKey: c.env.KMA_SERVICE_KEY })
          .getForecast(requestedRegionName, nx, ny)
          .catch((error: unknown) => {
            console.error(JSON.stringify({
              event: 'weekly_air_quality_provider_failed',
              provider: 'AIRKOREA_FORECAST',
              ...providerErrorDiagnostic(error),
            }));
            return [];
          })
      : Promise.resolve([] as DailyAirQualityForecastAtDate[]);
    const [forecast, settings, midTermDays, observedDays, savedDays, uv, airQuality] = await Promise.all([
      shortTermPromise,
      settingsForRequest(c.env.DB, c.req.query('installationId'), c.req.header('Authorization')),
      midTermPromise,
      observationPromise,
      savedPromise,
      uvPromise,
      airPromise,
    ]);
    const liveDays = enrichWeeklyForecastDays(
      mergeWeeklyForecastDays(forecast?.daily ?? [], midTermDays),
      uv,
      airQuality,
    );
    const displayedDays = weeklyCalendarDays(
      liveDays,
      observedDays,
      savedDays,
      calendarWeek.dates,
      today,
    );
    if (c.env.DB) {
      await saveWeeklyForecastRecords(c.env.DB, regionId, liveDays, now)
        .catch((error: unknown) => {
          console.error(JSON.stringify({
            event: 'weekly_forecast_history_save_failed',
            error: safeErrorName(error),
          }));
        });
    }
    return c.json({
      dataSource: weeklyDataSource(forecast, midTermDays, observedDays),
      regionId,
      days: displayedDays.map((day) => ({
        date: weekdayLabel(day.date),
        forecastDate: `${day.date.slice(0, 4)}-${day.date.slice(4, 6)}-${day.date.slice(6, 8)}`,
        weatherLabel: day.skyCondition,
        weatherDataComplete: day.weatherDataComplete,
        precipitationDetail: day.precipitationDetail,
        min: formatTemperature(day.minTemperature),
        max: formatTemperature(day.maxTemperature),
        minTemperatureSource: day.minTemperatureSource,
        maxTemperatureSource: day.maxTemperatureSource,
        averageHumidity: roundOptional(day.averageHumidity),
        maximumWindSpeed: roundOptional(day.maximumWindSpeed, 1),
        maximumUvIndex: roundOptional(day.maximumUvIndex, 1),
        snowfallAmount: day.snowfallDataAvailable
          ? roundOptional(day.snowfallAmount, 1)
          : undefined,
        airQualityForecast: day.airQualityForecast,
        forecastSource: day.forecastSource,
        issuedAt: day.issuedAt,
        recordedAt: day.recordedAt,
        historical: day.historical === true,
        observationStationId: day.observationStationId,
        observationDistanceKm: day.observationDistanceKm,
        recommendations: day.forecastSource === 'KMA_OBSERVATION'
          ? []
          : recommendationsForDay(
              day,
              forecast?.hourly ?? [],
              settings,
            ).filter((item) => item.recommended).slice(0, 3),
      })),
    });
  } catch (error) {
    logProviderError('weekly', error);
    return c.json({ error: 'WEATHER_PROVIDER_UNAVAILABLE' }, 502);
  }
});

export function mergeWeeklyForecastDays(
  shortTerm: DailyWeatherForecast[],
  midTerm: DailyWeatherForecast[],
): DailyWeatherForecast[] {
  const byDate = new Map<string, DailyWeatherForecast>();
  for (const day of midTerm) byDate.set(day.date, day);
  for (const day of shortTerm) {
    const medium = byDate.get(day.date);
    const hasOfficialDailyTemperatures =
      day.minTemperatureSource === 'DAILY' &&
      day.maxTemperatureSource === 'DAILY';
    if (!medium || hasOfficialDailyTemperatures) byDate.set(day.date, day);
  }
  return [...byDate.values()].sort((left, right) => left.date.localeCompare(right.date));
}

export function enrichWeeklyForecastDays(
  days: DailyWeatherForecast[],
  uv: UvForecast | undefined,
  airQuality: DailyAirQualityForecastAtDate[],
): DailyWeatherForecast[] {
  const uvByDate = new Map<string, number>();
  for (const point of uv?.points ?? []) {
    const date = point.forecastAt.slice(0, 10).replaceAll('-', '');
    const current = uvByDate.get(date);
    if (current === undefined || point.uvIndex > current) {
      uvByDate.set(date, point.uvIndex);
    }
  }
  const airByDate = new Map(airQuality.map((day) => [day.date, day]));
  return days.map((day) => {
    const date = day.date.replaceAll('-', '');
    const air = airByDate.get(date);
    return {
      ...day,
      maximumUvIndex: uvByDate.get(date),
      airQualityForecast: air === undefined
        ? undefined
        : {
            pm10Grade: air.pm10Grade,
            pm25Grade: air.pm25Grade,
            ozoneGrade: air.ozoneGrade,
            yellowDustMentioned: air.yellowDustMentioned,
            confidence: air.confidence,
          },
    };
  });
}

export function weeklyCalendarDays(
  liveDays: DailyWeatherForecast[],
  observedDays: DailyWeatherForecast[],
  savedDays: DailyWeatherForecast[],
  calendarDates: string[],
  today: string,
): DailyWeatherForecast[] {
  const live = new Map(liveDays.map((day) => [compactCalendarDate(day.date), day]));
  const observed = new Map(
    observedDays.map((day) => [compactCalendarDate(day.date), day]),
  );
  const saved = new Map(savedDays.map((day) => [compactCalendarDate(day.date), day]));
  const result: DailyWeatherForecast[] = [];
  for (const date of calendarDates) {
    if (date < today) {
      const recorded = observed.get(date) ?? saved.get(date);
      if (recorded) result.push({ ...recorded, historical: true });
      continue;
    }
    const current = live.get(date);
    if (current) result.push({ ...current, historical: false });
  }
  return result;
}

function weeklyDataSource(
  shortTerm: WeatherForecast | undefined,
  midTermDays: DailyWeatherForecast[],
  observedDays: DailyWeatherForecast[],
): string {
  const sources = [
    shortTerm ? '기상청 단기예보' : undefined,
    midTermDays.length > 0 ? '기상청 중기예보' : undefined,
    observedDays.length > 0 ? '기상청 지상·AWS 실제 관측' : undefined,
  ].filter((value): value is string => value !== undefined);
  return sources.length === 0 ? '기상청 자료 없음' : sources.join(' · ');
}

function compactCalendarDate(value: string): string {
  return /^\d{8}$/.test(value)
    ? `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`
    : value;
}

export default router;

export function buildTimeline(
  hourly: WeatherSnapshot[],
  settings: Partial<NotificationSettings> =
    defaultNotificationSettings('anonymous'),
  referenceTime?: string,
) {
  const firstTime = hourly[0]?.forecastAt ?? hourly[0]?.observedAt;
  const targetDate = referenceTime
    ? koreaDate(referenceTime)
    : firstTime
      ? koreaDate(firstTime)
      : undefined;
  if (!targetDate) return [];

  const itemsByKoreaHour = new Map(
    hourly.map((item) => {
      const time = item.forecastAt ?? item.observedAt;
      return [koreaHourKey(time), item] as const;
    }),
  );
  const nextDate = shiftCalendarDate(targetDate, 1);
  const slots = [3, 6, 9, 12, 15, 18, 21, 24].map((displayHour) => {
    const dataDate = displayHour === 24 ? nextDate : targetDate;
    const dataHour = displayHour % 24;
    return {
      displayHour,
      item: itemsByKoreaHour.get(
        `${dataDate}T${String(dataHour).padStart(2, '0')}`,
      ),
    };
  });
  const temperatures = slots.flatMap(({ item }) =>
    item?.temperature === undefined ? [] : [item.temperature],
  );
  const minimumTemperature = temperatures.length > 0
    ? Math.min(...temperatures)
    : undefined;
  const maximumTemperature = temperatures.length > 0
    ? Math.max(...temperatures)
    : undefined;

  return slots.map(({ displayHour, item }, index) => {
    const timeLabel = String(displayHour).padStart(2, '0');
    if (!item) {
      return {
        timeLabel,
        stateLabel: '시간별 예보를 확인하세요',
        detail: '예상기온 자료 없음 / 날씨 자료 없음',
        recommendations: [],
      };
    }
    const recommendations = recommendationsForSnapshot(item, settings);
    const topRecommendation = recommendations[0]?.type;
    const previousTemperature = slots
      .slice(0, index)
      .reverse()
      .find(({ item: previous }) => previous?.temperature !== undefined)
      ?.item?.temperature;
    const stateLabel = timelineStateLabel(item, recommendations, {
      minimumTemperature,
      maximumTemperature,
      previousTemperature,
    });
    const precipitationRelated =
      ['UMBRELLA', 'HEAVY_SNOW_CAUTION'].includes(topRecommendation ?? '') ||
      (!topRecommendation && timelinePrecipitationStateLabel(item) !== undefined);
    return {
      timeLabel,
      stateLabel:
        (precipitationRelated && precipitationPeriod(item)
          ? `${precipitationLabel(item)} · `
          : '') + stateLabel,
      detail: timelineDetail(item),
      recommendations,
    };
  });
}

function koreaHourKey(iso: string): string {
  return new Date(Date.parse(iso) + 9 * 3_600_000)
    .toISOString()
    .slice(0, 13);
}

function shiftCalendarDate(date: string, days: number): string {
  const shifted = new Date(`${date}T00:00:00Z`);
  shifted.setUTCDate(shifted.getUTCDate() + days);
  return shifted.toISOString().slice(0, 10);
}

function timelineWeatherSummary(snapshot: WeatherSnapshot): string {
  const temperature = snapshot.temperature === undefined
    ? '예상기온 자료 없음'
    : `예상기온 ${snapshot.temperature.toFixed(1)}℃`;
  return `${temperature} / ${snapshot.skyCondition ?? '날씨 자료 없음'}`;
}

interface TimelineTemperatureContext {
  minimumTemperature?: number;
  maximumTemperature?: number;
  previousTemperature?: number;
}

const TIMELINE_TEMPERATURE_RANGE_THRESHOLD = 3;
const TIMELINE_TEMPERATURE_CHANGE_THRESHOLD = 3;

function timelineStateLabel(
  snapshot: WeatherSnapshot,
  recommendations: Recommendation[],
  temperatureContext: TimelineTemperatureContext,
): string {
  const recommendation = recommendations[0]?.type;
  const labels: Partial<Record<Recommendation['type'], string>> = {
    UMBRELLA: '비가 예보됐어요',
    PARASOL: '자외선지수가 높게 예보됐어요',
    HEAVY_SNOW_CAUTION: '많은 눈이 예보됐어요',
    OUTERWEAR: '기온이 낮게 예보됐어요',
    MASK: '대기질이 나쁨 단계예요',
    WATER: '예상 체감온도가 높게 계산됐어요',
    SUNSCREEN: '자외선지수가 높게 예보됐어요',
  };
  if (recommendation && labels[recommendation]) {
    return labels[recommendation];
  }

  const precipitation = timelinePrecipitationStateLabel(snapshot);
  if (precipitation) return precipitation;

  if ((snapshot.windSpeed ?? 0) >= defaultRuleConfig.wind.caution) {
    return '바람이 강하게 불어요';
  }

  const { minimumTemperature, maximumTemperature, previousTemperature } =
    temperatureContext;
  const temperature = snapshot.temperature;
  const temperatureRange =
    minimumTemperature !== undefined && maximumTemperature !== undefined
      ? maximumTemperature - minimumTemperature
      : 0;
  if (
    temperature !== undefined &&
    temperatureRange >= TIMELINE_TEMPERATURE_RANGE_THRESHOLD
  ) {
    if (temperature === maximumTemperature) {
      return '오늘 가장 따뜻한 시간이에요';
    }
    if (temperature === minimumTemperature) {
      return '오늘 가장 쌀쌀한 시간이에요';
    }
  }
  if (temperature !== undefined && previousTemperature !== undefined) {
    const change = temperature - previousTemperature;
    if (change >= TIMELINE_TEMPERATURE_CHANGE_THRESHOLD) {
      return '기온이 크게 오르는 시간이에요';
    }
    if (change <= -TIMELINE_TEMPERATURE_CHANGE_THRESHOLD) {
      return '기온이 크게 내려가는 시간이에요';
    }
  }

  if ((snapshot.humidity ?? 0) >= defaultRuleConfig.humidity.high) {
    return '습도가 높은 시간이에요';
  }

  const skyCondition = snapshot.skyCondition?.trim() ?? '';
  if (skyCondition.includes('맑')) return '맑은 하늘이 이어져요';
  if (skyCondition.includes('구름')) return '구름이 많은 날씨예요';
  if (skyCondition.includes('흐림') || skyCondition.includes('흐린')) {
    return '흐린 날씨가 이어져요';
  }
  return '시간별 예보를 확인하세요';
}

function timelinePrecipitationStateLabel(
  snapshot: WeatherSnapshot,
): string | undefined {
  if (snapshot.precipitationType === 'RAIN_SNOW') {
    return '비와 눈이 예보됐어요';
  }
  if (snapshot.precipitationType === 'SHOWER') {
    return '소나기가 예보됐어요';
  }
  if (
    snapshot.precipitationType === 'SNOW' ||
    snapshot.snowExpected === true ||
    (snapshot.snowProbability ?? 0) > 0 ||
    (snapshot.snowfallAmountRange?.max ??
      snapshot.snowfallAmountRange?.min ??
      snapshot.snowfallAmount ??
      0) > 0
  ) {
    return '눈이 예보됐어요';
  }
  if (snapshot.precipitationType === 'RAIN') return '비가 예보됐어요';
  if (
    (snapshot.precipitationProbability ?? 0) > 0 ||
    (snapshot.precipitationAmountRange?.max ??
      snapshot.precipitationAmountRange?.min ??
      snapshot.precipitationAmount ??
      0) > 0
  ) {
    return '강수 가능성이 있어요';
  }
  return undefined;
}

function timelineDetail(snapshot: WeatherSnapshot): string {
  const weather = timelineWeatherSummary(snapshot);
  const precipitation = timelinePrecipitationSummary(snapshot);
  return precipitation ? `${weather}\n${precipitation}` : weather;
}

function timelinePrecipitationSummary(
  snapshot: WeatherSnapshot,
): string | undefined {
  const hasPrecipitationForecast =
    (snapshot.precipitationType !== undefined &&
      snapshot.precipitationType !== 'NONE') ||
    (snapshot.precipitationProbability ?? 0) > 0 ||
    (snapshot.precipitationAmountRange?.max ??
      snapshot.precipitationAmountRange?.min ??
      snapshot.precipitationAmount ??
      0) > 0 ||
    (snapshot.snowProbability ?? 0) > 0 ||
    snapshot.snowExpected === true ||
    (snapshot.snowfallAmountRange?.max ??
      snapshot.snowfallAmountRange?.min ??
      snapshot.snowfallAmount ??
      0) > 0;
  if (!hasPrecipitationForecast) return undefined;

  const forecastLabel = precipitationForecastLabel(snapshot);
  const period = precipitationPeriod(snapshot);
  const timedLabel = period
    ? `${precipitationLabel(snapshot)} ${forecastLabel}`
    : forecastLabel;
  return snapshot.precipitationProbability === undefined
    ? timedLabel
    : `${timedLabel} · 강수확률 ${Math.round(snapshot.precipitationProbability)}%`;
}

function precipitationForecastLabel(snapshot: WeatherSnapshot): string {
  if (snapshot.precipitationType === 'RAIN_SNOW') return '비·눈 예보';
  if (snapshot.precipitationType === 'SHOWER') return '소나기 예보';
  if (
    snapshot.precipitationType === 'SNOW' ||
    snapshot.snowExpected === true ||
    (snapshot.snowProbability ?? 0) > 0 ||
    (snapshot.snowfallAmount ?? 0) > 0
  ) {
    return '강설 예보';
  }
  if (snapshot.precipitationType === 'RAIN') return '강수 예보';
  return '강수 가능성';
}

function recommendationsForSnapshot(
  snapshot: WeatherSnapshot,
  settings: Partial<NotificationSettings>,
): Recommendation[] {
  return runRecommendationEngine(
    runLifestyleWeatherEngine(runWeatherRuleEngine(snapshot)),
    settings,
  );
}

export function recommendationsForDay(
  day: DailyWeatherForecast,
  hourly: WeatherSnapshot[],
  settings: Partial<NotificationSettings> =
    defaultNotificationSettings('anonymous'),
): Recommendation[] {
  const dayHourly = hourly.flatMap((item) => {
    const pointDate = koreaDate(item.forecastAt ?? item.observedAt).replaceAll('-', '');
    const period = precipitationPeriod(item);
    if (!period) return pointDate === day.date ? [item] : [];
    const rainDate = koreaDate(period.start).replaceAll('-', '');
    if (pointDate === day.date) return [rainDate === day.date ? item : withoutPrecipitation(item)];
    return rainDate === day.date ? [precipitationOnlySnapshot(item)] : [];
  });
  if (dayHourly.length > 0) {
    const facts = runWeatherRuleEngineForHourly(dayHourly);
    return runRecommendationEngine(
      runLifestyleWeatherEngine(facts, dayHourly),
      settings,
    );
  }

  const snapshot: WeatherSnapshot = {
    observedAt: `${day.date.slice(0, 4)}-${day.date.slice(4, 6)}-${day.date.slice(6, 8)}T12:00:00+09:00`,
    temperature: day.maxTemperature,
    minTemperature: day.minTemperature,
    maxTemperature: day.maxTemperature,
    precipitationProbability: day.precipitationProbability,
    precipitationAmount: day.precipitationAmount,
    snowProbability: day.snowProbability,
    snowfallAmount: day.snowfallAmount,
    skyCondition: day.skyCondition,
  };
  return recommendationsForSnapshot(snapshot, settings);
}

async function settingsForRequest(
  db: D1Database,
  installationId: string | undefined,
  authorization?: string,
): Promise<NotificationSettings> {
  if (!installationId || !authorization || !await installationOwnerHash(db, installationId, authorization)) {
    return defaultNotificationSettings('anonymous');
  }
  return getNotificationSettings(db, installationId);
}

function weekdayLabel(kmaDate: string): string {
  const date = new Date(
    Date.UTC(
      Number(kmaDate.slice(0, 4)),
      Number(kmaDate.slice(4, 6)) - 1,
      Number(kmaDate.slice(6, 8)),
    ),
  );
  return ['일', '월', '화', '수', '목', '금', '토'][date.getUTCDay()];
}

function formatTemperature(value?: number): string {
  return value === undefined ? '--' : String(Math.round(value));
}

function roundOptional(value: number | undefined, fractionDigits = 0): number | undefined {
  if (value === undefined || !Number.isFinite(value)) return undefined;
  const factor = 10 ** fractionDigits;
  return Math.round(value * factor) / factor;
}

function maximum(values: number[]): number {
  return values.length === 0 ? 0 : Math.max(...values);
}

function logProviderError(
  route: 'main' | 'today' | 'weekly',
  error: unknown,
): void {
  console.error(
    JSON.stringify({
      event: 'weather_provider_failed',
      provider: 'KMA',
      route,
      ...providerErrorDiagnostic(error),
    }),
  );
}

export function isFreshMainSnapshot(
  snapshot: WeatherSnapshot,
  now = new Date(),
): boolean {
  const fetchedAt = Date.parse(snapshot.fetchedAt ?? '');
  const forecastAt = Date.parse(snapshot.forecastAt ?? snapshot.observedAt);
  const reference = now.getTime();
  return Number.isFinite(fetchedAt) &&
    Number.isFinite(forecastAt) &&
    fetchedAt >= reference - 90 * 60 * 1000 &&
    fetchedAt <= reference + 5 * 60 * 1000 &&
    forecastAt >= reference - 90 * 60 * 1000 &&
    forecastAt <= reference + 3 * 60 * 60 * 1000;
}

function forecastFromCachedSnapshot(
  current: WeatherSnapshot,
): WeatherForecast {
  return {
    current,
    hourly: [current],
    timelineHourly: [current],
    daily: [],
    baseDate: '',
    baseTime: '',
    dataSource: '기상청 빠른 캐시',
  };
}

export async function settleWithin<T>(
  promise: Promise<T>,
  fallback: T,
  timeoutMs: number,
): Promise<TimedResult<T>> {
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      promise.then((value) => ({ value, timedOut: false })),
      new Promise<TimedResult<T>>((resolve) => {
        timeoutId = setTimeout(
          () => resolve({ value: fallback, timedOut: true }),
          timeoutMs,
        );
      }),
    ]);
  } finally {
    if (timeoutId !== undefined) clearTimeout(timeoutId);
  }
}

export function buildOptionalProviderTimeoutStatusMessages(
  timeouts: OptionalProviderTimeouts,
): WeatherMessagePart[] {
  return [
    timeouts.precipitation
      ? dataStatusMessage(
          '자료를 받아오지 못해 현재 강수 상태를 확인하기 어려워요',
          '기상청 관측분석자료·기상청 레이더',
        )
      : undefined,
    timeouts.warning
      ? dataStatusMessage(
          '자료를 받아오지 못해 현재 기상특보 상태를 확인하기 어려워요',
          '기상청 특보정보',
        )
      : undefined,
    timeouts.roadIce
      ? dataStatusMessage(
          '자료를 받아오지 못해 블랙아이스(도로살얼음) 발생 가능 정보를 확인하기 어려워요',
          '기상청 도로살얼음 발생 가능 정보',
        )
      : undefined,
    timeouts.roadControl
      ? dataStatusMessage(
          '자료를 받아오지 못해 현재 도로 통제 상태를 확인하기 어려워요',
          '국가교통정보센터 돌발상황정보',
        )
      : undefined,
  ].filter((message): message is WeatherMessagePart => message !== undefined);
}

function unavailableEnvironmentalData(): EnvironmentalDataBundle {
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

function dataStatusMessage(text: string, source: string): WeatherMessagePart {
  return { role: 'DATA_STATUS', text, source };
}

function logOptionalProviderTimeouts(
  timeouts: OptionalProviderTimeouts & { environmental: boolean },
): void {
  for (const [provider, timedOut] of Object.entries(timeouts)) {
    if (!timedOut) continue;
    console.warn(
      JSON.stringify({
        event: 'today_optional_provider_timed_out',
        provider,
        budgetMs: provider === 'precipitation'
          ? CURRENT_PRECIPITATION_PROVIDER_BUDGET_MS
          : TODAY_OPTIONAL_PROVIDER_BUDGET_MS,
      }),
    );
  }
}
