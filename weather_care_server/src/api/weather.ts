import { Hono } from 'hono';
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
import { saveCurrentWeather } from '../database/weatherCacheRepository';
import { coordinatesFromQuery, regionFromQuery } from '../utils';
import { CATALOG_VERSION } from '../recommendations/recommendationTemplates';
import { buildWeatherBrief } from '../presentation/weatherBrief';
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
import { providerErrorDiagnostic } from '../observability/providerErrorDiagnostics';

const router = new Hono<{ Bindings: ServerEnv }>();
const TODAY_OPTIONAL_PROVIDER_BUDGET_MS = 3_500;

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
        TODAY_OPTIONAL_PROVIDER_BUDGET_MS,
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
    const response: TodayWeatherResponse = {
      dataSource: forecast.dataSource,
      region: { nx, ny, name: regionLabel },
      brief: buildWeatherBrief(forecast, { regionKey: `${nx}:${ny}` }),
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
      timeline: buildTimeline(forecast.hourly, settings),
      environmentalSources: environmentalData.sources,
      decisionVersion: DECISION_VERSION,
      catalogVersion: CATALOG_VERSION,
      generatedAt: new Date().toISOString(),
    };

    if (c.env.DB) {
      c.executionCtx.waitUntil(
        saveCurrentWeather(c.env.DB, nx, ny, forecast.current)
          .catch((error: unknown) => {
            console.error(
              JSON.stringify({
                event: 'weather_snapshot_persistence_failed',
                nx,
                ny,
                error: error instanceof Error ? error.name : 'UnknownError',
              }),
            );
          }),
      );
    }
    return c.json(response);
  } catch (error) {
    logProviderError('today', nx, ny, error);
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
  if (!c.env.KMA_SERVICE_KEY) {
    return c.json({ error: 'KMA_SERVICE_KEY_NOT_CONFIGURED' }, 503);
  }

  try {
    const [forecast, settings] = await Promise.all([
      new KmaWeatherProvider({
        serviceKey: c.env.KMA_SERVICE_KEY,
      }).getForecastByRegion(nx, ny),
      settingsForRequest(c.env.DB, c.req.query('installationId')),
    ]);
    return c.json({
      dataSource: forecast.dataSource,
      regionId: `${nx}_${ny}`,
      days: forecast.daily.map((day) => ({
        date: weekdayLabel(day.date),
        forecastDate: `${day.date.slice(0, 4)}-${day.date.slice(4, 6)}-${day.date.slice(6, 8)}`,
        weatherLabel: day.skyCondition,
        weatherDataComplete: day.weatherDataComplete,
        precipitationDetail: day.precipitationDetail,
        min: formatTemperature(day.minTemperature),
        max: formatTemperature(day.maxTemperature),
        minTemperatureSource: day.minTemperatureSource,
        maxTemperatureSource: day.maxTemperatureSource,
        recommendations: recommendationsForDay(
          day,
          forecast.hourly,
          settings,
        ).filter((item) => item.recommended).slice(0, 3),
      })),
    });
  } catch (error) {
    logProviderError('weekly', nx, ny, error);
    return c.json({ error: 'WEATHER_PROVIDER_UNAVAILABLE' }, 502);
  }
});

export default router;

export function buildTimeline(
  hourly: WeatherSnapshot[],
  settings: Partial<NotificationSettings> =
    defaultNotificationSettings('anonymous'),
) {
  const offsets = [0, 3, 6, 9, 12];
  return offsets
    .map((offset) => hourly[offset])
    .filter((item): item is WeatherSnapshot => item !== undefined)
    .map((item) => {
      const recommendations = recommendationsForSnapshot(item, settings);
      const hour = (item.forecastAt ?? item.observedAt).slice(11, 13);
      return {
        timeLabel: hour,
        stateLabel: timelineStateLabel(recommendations),
        detail: timelineDetail(item),
        recommendations,
      };
    });
}

function timelineStateLabel(
  recommendations: Recommendation[],
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
  return '시간별 예보를 확인하세요';
}

function timelineDetail(snapshot: WeatherSnapshot): string {
  const pieces = [
    snapshot.skyCondition ?? '날씨 정보 확인 중',
    snapshot.temperature === undefined
      ? null
      : `예상기온 ${snapshot.temperature.toFixed(1)}℃`,
    `강수확률 ${Math.round(snapshot.precipitationProbability ?? 0)}%`,
  ];
  return pieces.filter((piece): piece is string => piece !== null).join(' · ');
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
  const dayHourly = hourly.filter((item) => {
    const date = (item.forecastAt ?? item.observedAt)
      .slice(0, 10)
      .replaceAll('-', '');
    return date === day.date;
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
): Promise<NotificationSettings> {
  if (!installationId) return defaultNotificationSettings('anonymous');
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

function maximum(values: number[]): number {
  return values.length === 0 ? 0 : Math.max(...values);
}

function logProviderError(
  route: 'today' | 'weekly',
  nx: number,
  ny: number,
  error: unknown,
): void {
  console.error(
    JSON.stringify({
      event: 'weather_provider_failed',
      provider: 'KMA',
      route,
      nx,
      ny,
      ...providerErrorDiagnostic(error),
    }),
  );
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
        budgetMs: TODAY_OPTIONAL_PROVIDER_BUDGET_MS,
      }),
    );
  }
}
