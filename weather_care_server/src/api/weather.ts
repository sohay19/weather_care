import { Hono } from 'hono';
import {
  NotificationSettings,
  Recommendation,
  ServerEnv,
  TodayWeatherResponse,
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
import { regionFromQuery } from '../utils';
import { CATALOG_VERSION } from '../recommendations/recommendationTemplates';
import { buildWeatherBrief } from '../presentation/weatherBrief';
import {
  buildEnvironmentalDataStatusMessages,
  buildLifestyleMessages,
} from '../presentation/lifestyleMessages';
import {
  enrichForecastWithEnvironmentalData,
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

const router = new Hono<{ Bindings: ServerEnv }>();

router.get('/today', async (c) => {
  const { nx, ny } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
  if (!c.env.KMA_SERVICE_KEY) {
    return c.json({ error: 'KMA_SERVICE_KEY_NOT_CONFIGURED' }, 503);
  }

  try {
    const region = regionMetadataForGrid(nx, ny);
    const [weatherForecast, environmentalData, settings] = await Promise.all([
      new KmaWeatherProvider({
        serviceKey: c.env.KMA_SERVICE_KEY,
      }).getForecastByRegion(nx, ny),
      loadEnvironmentalData(c.env, region),
      settingsForRequest(c.env.DB, c.req.query('installationId')),
    ]);
    const forecast = enrichForecastWithEnvironmentalData(
      weatherForecast,
      environmentalData,
    );
    const decisionHourly = forecast.hourly.slice(0, 24);
    const rules = runWeatherRuleEngineForHourly(decisionHourly);
    const lifestyle = runLifestyleWeatherEngine(rules, decisionHourly);
    const recommendations = runRecommendationEngine(lifestyle, settings);
    const regionLabel = regionName(nx, ny);

    const response: TodayWeatherResponse = {
      dataSource: forecast.dataSource,
      region: { nx, ny, name: regionLabel },
      brief: buildWeatherBrief(forecast, { regionKey: `${nx}:${ny}` }),
      current: forecast.current,
      hourly: forecast.hourly,
      recommendations,
      lifestyleMessages: buildLifestyleMessages(
        lifestyle,
        rules,
        decisionHourly,
        regionLabel,
      ),
      dataStatusMessages: buildEnvironmentalDataStatusMessages(
        environmentalData.sources,
      ),
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
        weatherLabel: day.skyCondition,
        min: formatTemperature(day.minTemperature),
        max: formatTemperature(day.maxTemperature),
        recommendations: recommendationsForDay(
          day,
          forecast.hourly,
          settings,
        ),
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
    ).slice(0, 3);
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
  return recommendationsForSnapshot(snapshot, settings).slice(0, 3);
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
      error: error instanceof Error ? error.name : 'UnknownError',
    }),
  );
}
