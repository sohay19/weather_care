import { Hono } from 'hono';
import { Recommendation, ServerEnv, NotificationSettings, TodayWeatherResponse } from '../types';
import { DummyWeatherProvider } from '../providers/weather/dummyWeatherProvider';
import { DummyAirQualityProvider } from '../providers/air/dummyAirQualityProvider';
import { WeatherNormalizer } from '../normalization/weatherNormalizer';
import { runWeatherRuleEngine } from '../rules/weatherRuleEngine';
import { runLifestyleWeatherEngine } from '../lifestyle/lifestyleWeatherEngine';
import { runRecommendationEngine } from '../recommendations/recommendationEngine';
import { saveCurrentWeather } from '../database/weatherCacheRepository';
import { regionFromQuery } from '../utils';
import { runRecommendationNotificationJob } from '../notification/notificationScheduler';
import { lifestyleMessageFor } from '../lifestyle/lifestyleTemplates';

const router = new Hono<{ Bindings: ServerEnv }>();
const weatherProvider = new DummyWeatherProvider();
const airQualityProvider = new DummyAirQualityProvider();

const sampleSettings: Partial<NotificationSettings> = {
  umbrellaEnabled: true,
  parasolEnabled: true,
  heavySnowEnabled: true,
  outerwearEnabled: true,
  maskEnabled: true,
  waterEnabled: true,
  sunscreenEnabled: true,
};

router.get('/today', async (c) => {
  const { nx, ny, topic } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
  const raw = await weatherProvider.getByRegion(nx, ny);
  const air = await airQualityProvider.getByRegion(nx, ny);
  const snapshot = WeatherNormalizer.normalize({
    ...raw,
    pm10: air.pm10,
    pm25: air.pm25,
    airQualityGrade: air.airQualityGrade,
  });
  const rules = runWeatherRuleEngine(snapshot);
  const lifestyle = runLifestyleWeatherEngine(rules);
  const recommendations = runRecommendationEngine(lifestyle, sampleSettings);
  const recommendationOf = (type: Recommendation['type']) =>
    recommendations.filter((item) => item.type === type);

  const response: TodayWeatherResponse = {
    region: { nx, ny, name: '수원' },
    brief: '오늘은 덥다가 퇴근할 때 비가 와요.',
    current: snapshot,
    hourly: buildHourlyForecast(snapshot),
    recommendations,
    lifestyleMessages: lifestyle.map((item) => ({
      type: item.type,
      ...lifestyleMessageFor(item.type, item.score),
    })),
    timeline: [
      {
        timeLabel: '07',
        stateLabel: '출근할 때',
        detail: '선선해요. 특별히 챙길 건 없어요.',
        recommendations: [],
      },
      {
        timeLabel: '12',
        stateLabel: '점심 무렵',
        detail: '햇볕이 강해요.',
        recommendations: recommendationOf('SUNSCREEN'),
      },
      {
        timeLabel: '18',
        stateLabel: '퇴근할 때',
        detail: '비 올 가능성이 높아요.',
        recommendations: recommendationOf('UMBRELLA'),
      },
    ],
  };

  if (c.env.DB) {
    await saveCurrentWeather(c.env.DB, nx, ny, snapshot);
    // Topic subscription corrective logic could be added here
    void runRecommendationNotificationJob(c.env);
  }
  return c.json(response);
});

router.get('/weekly', async (c) => {
  const { nx, ny } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
  return c.json({
    regionId: `${nx}_${ny}`,
    days: buildWeeklyForecast(),
  });
});

export default router;

function buildHourlyForecast(current: TodayWeatherResponse['current']) {
  const baseTemperature = current.temperature ?? 27;
  const baseDate = current.observedAt.slice(0, 10);
  const rows = [
    { time: '06', delta: -6, apparentDelta: -5.5, rain: 10, amount: 0, wind: 1.4, sky: '맑음' },
    { time: '09', delta: -3, apparentDelta: -2, rain: 10, amount: 0, wind: 1.8, sky: '구름 조금' },
    { time: '12', delta: 0, apparentDelta: 2.5, rain: 20, amount: 0, wind: 2.4, sky: '부분 흐림' },
    { time: '15', delta: 1.5, apparentDelta: 4, rain: 35, amount: 0, wind: 3.1, sky: '흐림' },
    { time: '18', delta: -2.5, apparentDelta: -0.5, rain: 75, amount: 3.2, wind: 5.8, sky: '비' },
    { time: '21', delta: -5, apparentDelta: -4, rain: 60, amount: 1.1, wind: 4.3, sky: '비' },
  ];
  return rows.map((row) => ({
    observedAt: `${baseDate}T${row.time}:00:00+09:00`,
    temperature: baseTemperature + row.delta,
    apparentTemperature: baseTemperature + row.apparentDelta,
    precipitationProbability: row.rain,
    precipitationAmount: row.amount,
    snowProbability: 0,
    snowfallAmount: 0,
    windSpeed: row.wind,
    skyCondition: row.sky,
  }));
}

function buildWeeklyForecast() {
  const weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];
  const koreaNow = new Date(Date.now() + 9 * 60 * 60 * 1000);
  const firstWeekday = koreaNow.getUTCDay();
  const umbrella = weeklyRecommendation(
    'UMBRELLA',
    90,
    '우산 챙겨요',
    '비 예보가 있어 외출 전에 우산을 준비해요.',
    'RAIN_LIKELY',
  );
  const sunscreen = weeklyRecommendation(
    'SUNSCREEN',
    70,
    '선크림 챙겨요',
    '자외선이 강한 시간대 전에 선크림을 발라요.',
    'UV_HIGH',
  );
  const water = weeklyRecommendation(
    'WATER',
    65,
    '물 챙겨요',
    '체감온도가 높아 작은 물병을 준비하면 좋아요.',
    'APPARENT_TEMPERATURE_HIGH',
  );
  const rows = [
    { weatherLabel: '구름 후 비', min: '24', max: '32', recommendations: [umbrella, sunscreen] },
    { weatherLabel: '비', min: '23', max: '28', recommendations: [umbrella] },
    { weatherLabel: '흐림', min: '22', max: '27', recommendations: [] },
    { weatherLabel: '맑음', min: '23', max: '30', recommendations: [sunscreen] },
    { weatherLabel: '소나기', min: '24', max: '29', recommendations: [umbrella] },
    { weatherLabel: '맑음', min: '24', max: '31', recommendations: [sunscreen] },
    { weatherLabel: '구름 조금', min: '25', max: '32', recommendations: [water] },
  ];

  return rows.map((row, index) => ({
    date: weekdayLabels[(firstWeekday + index) % weekdayLabels.length],
    ...row,
  }));
}

function weeklyRecommendation(
  type: Recommendation['type'],
  priority: number,
  title: string,
  description: string,
  reasonCode: string,
): Recommendation {
  return {
    type,
    recommended: true,
    priority,
    title,
    description,
    reasonCodes: [reasonCode],
    notificationEligible: true,
  };
}
