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
import { saveDailyWeatherSnapshot } from '../database/comparisonRepository';
import { regionFromQuery } from '../utils';
import { runRecommendationNotificationJob } from '../notification/notificationScheduler';
import { CATALOG_VERSION } from '../recommendations/recommendationTemplates';
import { buildWeatherBrief } from '../presentation/weatherBrief';
import { buildLifestyleMessages } from '../presentation/lifestyleMessages';
import {
  enrichForecastWithEnvironmentalData,
  loadEnvironmentalData,
} from '../providers/environmental/environmentalDataService';
import {
  regionMetadataForGrid,
  regionName,
} from '../regions/regionCatalog';

const router = new Hono<{ Bindings: ServerEnv }>();

const defaultSettings: Partial<NotificationSettings> = {
  umbrellaEnabled: true,
  parasolEnabled: true,
  heavySnowEnabled: true,
  outerwearEnabled: true,
  maskEnabled: true,
  waterEnabled: true,
  sunscreenEnabled: true,
};

router.get('/today', async (c) => {
  const { nx, ny } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
  if (!c.env.KMA_SERVICE_KEY) {
    return c.json({ error: 'KMA_SERVICE_KEY_NOT_CONFIGURED' }, 503);
  }

  try {
    const region = regionMetadataForGrid(nx, ny);
    const [weatherForecast, environmentalData] = await Promise.all([
      new KmaWeatherProvider({
        serviceKey: c.env.KMA_SERVICE_KEY,
      }).getForecastByRegion(nx, ny),
      loadEnvironmentalData(c.env, region),
    ]);
    const forecast = enrichForecastWithEnvironmentalData(
      weatherForecast,
      environmentalData,
    );
    const decisionHourly = forecast.hourly.slice(0, 24);
    const rules = runWeatherRuleEngineForHourly(decisionHourly);
    const lifestyle = runLifestyleWeatherEngine(rules, decisionHourly);
    const recommendations = runRecommendationEngine(lifestyle, defaultSettings);

    const response: TodayWeatherResponse = {
      dataSource: forecast.dataSource,
      region: { nx, ny, name: regionName(nx, ny) },
      brief: buildWeatherBrief(forecast, { regionKey: `${nx}:${ny}` }),
      current: forecast.current,
      hourly: forecast.hourly,
      recommendations,
      lifestyleMessages: buildLifestyleMessages(lifestyle),
      timeline: buildTimeline(forecast.hourly),
      environmentalSources: environmentalData.sources,
      decisionVersion: DECISION_VERSION,
      catalogVersion: CATALOG_VERSION,
      generatedAt: new Date().toISOString(),
    };

    if (c.env.DB) {
      c.executionCtx.waitUntil(
        Promise.all([
          saveCurrentWeather(c.env.DB, nx, ny, forecast.current),
          saveDailyWeatherSnapshot(c.env.DB, nx, ny, forecast.current),
        ])
          .then(() => runRecommendationNotificationJob(c.env))
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
    const forecast = await new KmaWeatherProvider({
      serviceKey: c.env.KMA_SERVICE_KEY,
    }).getForecastByRegion(nx, ny);
    return c.json({
      dataSource: forecast.dataSource,
      regionId: `${nx}_${ny}`,
      days: forecast.daily.map((day) => ({
        date: weekdayLabel(day.date),
        weatherLabel: day.skyCondition,
        min: formatTemperature(day.minTemperature),
        max: formatTemperature(day.maxTemperature),
        recommendations: recommendationsForDay(day, forecast.hourly),
      })),
    });
  } catch (error) {
    logProviderError('weekly', nx, ny, error);
    return c.json({ error: 'WEATHER_PROVIDER_UNAVAILABLE' }, 502);
  }
});

export default router;

function aggregateDecisionSnapshot(forecast: WeatherForecast): WeatherSnapshot {
  const nextDay = forecast.hourly.slice(0, 24);
  const temperatures = nextDay
    .map((item) => item.temperature)
    .filter((value): value is number => value !== undefined);
  const apparentTemperatures = nextDay
    .map((item) => item.apparentTemperature)
    .filter((value): value is number => value !== undefined);

  return {
    ...forecast.current,
    minTemperature:
      temperatures.length === 0 ? undefined : Math.min(...temperatures),
    maxTemperature:
      temperatures.length === 0 ? undefined : Math.max(...temperatures),
    apparentTemperature:
      apparentTemperatures.length === 0
        ? forecast.current.apparentTemperature
        : Math.max(...apparentTemperatures),
    precipitationProbability: maximum(
      nextDay.map((item) => item.precipitationProbability ?? 0),
    ),
    precipitationAmount: nextDay.reduce(
      (sum, item) => sum + (item.precipitationAmount ?? 0),
      0,
    ),
    snowProbability: maximum(
      nextDay.map((item) => item.snowProbability ?? 0),
    ),
    snowfallAmount: nextDay.reduce(
      (sum, item) => sum + (item.snowfallAmount ?? 0),
      0,
    ),
  };
}

export function buildTimeline(hourly: WeatherSnapshot[]) {
  const offsets = [0, 3, 6, 9, 12];
  return offsets
    .map((offset) => hourly[offset])
    .filter((item): item is WeatherSnapshot => item !== undefined)
    .map((item) => {
      const recommendations = recommendationsForSnapshot(item);
      const hour = item.observedAt.slice(11, 13);
      return {
        timeLabel: hour,
        stateLabel: timelineStateLabel(recommendations, hour),
        detail: timelineDetail(item),
        recommendations,
      };
    });
}

function timelineStateLabel(
  recommendations: Recommendation[],
  hour: string,
): string {
  const recommendation = recommendations[0]?.type;
  const labels: Partial<Record<Recommendation['type'], string>> = {
    UMBRELLA: '우산 챙기기 좋은 때',
    PARASOL: '햇볕 대비하기 좋은 때',
    HEAVY_SNOW_CAUTION: '이동 준비를 살피기 좋은 때',
    OUTERWEAR: '겉옷 챙기기 좋은 때',
    MASK: '마스크 챙기기 좋은 때',
    WATER: '수분 챙기기 좋은 때',
    SUNSCREEN: '햇볕 대비하기 좋은 때',
  };
  if (recommendation && labels[recommendation]) {
    return labels[recommendation];
  }
  const hourNumber = Number(hour);
  return hourNumber >= 6 && hourNumber < 18
    ? '바깥 날씨 확인하기 좋은 때'
    : '귀가 날씨 확인하기 좋은 때';
}

function timelineDetail(snapshot: WeatherSnapshot): string {
  const pieces = [
    snapshot.skyCondition ?? '날씨 정보 확인 중',
    snapshot.temperature === undefined
      ? null
      : `${snapshot.temperature.toFixed(1)}°`,
    `강수확률 ${Math.round(snapshot.precipitationProbability ?? 0)}%`,
  ];
  return pieces.filter((piece): piece is string => piece !== null).join(' · ');
}

function recommendationsForSnapshot(snapshot: WeatherSnapshot): Recommendation[] {
  return runRecommendationEngine(
    runLifestyleWeatherEngine(runWeatherRuleEngine(snapshot)),
    defaultSettings,
  );
}

export function recommendationsForDay(
  day: DailyWeatherForecast,
  hourly: WeatherSnapshot[],
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
      defaultSettings,
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
  return recommendationsForSnapshot(snapshot).slice(0, 3);
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
