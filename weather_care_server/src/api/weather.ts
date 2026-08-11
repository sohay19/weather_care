import { Hono } from 'hono';
import { ServerEnv, NotificationSettings, TodayWeatherResponse } from '../types';
import { DummyWeatherProvider } from '../providers/weather/dummyWeatherProvider';
import { DummyAirQualityProvider } from '../providers/air/dummyAirQualityProvider';
import { WeatherNormalizer } from '../normalization/weatherNormalizer';
import { runWeatherRuleEngine } from '../rules/weatherRuleEngine';
import { runLifestyleWeatherEngine } from '../lifestyle/lifestyleWeatherEngine';
import { runRecommendationEngine } from '../recommendations/recommendationEngine';
import { saveCurrentWeather } from '../database/weatherCacheRepository';
import { regionFromQuery } from '../utils';
import { runRecommendationNotificationJob } from '../notification/notificationScheduler';

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

  const response: TodayWeatherResponse = {
    region: { nx, ny, name: 'Suwon' },
    brief: '오늘은 덥다가 퇴근할 때 비가 와요.',
    current: snapshot,
    recommendations,
    lifestyleMessages: lifestyle.map((l) => ({
      type: l.type,
      title: l.type,
      description: `${l.type} (${l.score})`,
    })),
    timeline: [
      {
        timeLabel: '07',
        stateLabel: '출근할 때',
        detail: '선선해요. 특별히 챙길 건 없어요.',
        recommendations,
      },
      {
        timeLabel: '12',
        stateLabel: '점심 무렵',
        detail: '햇볕이 강해요.',
        recommendations,
      },
      {
        timeLabel: '18',
        stateLabel: '퇴근할 때',
        detail: '비 올 가능성이 높아요.',
        recommendations,
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
    days: [
      { date: '월', weatherLabel: '맑음', min: '24', max: '32', recommendations: [] },
      { date: '화', weatherLabel: '비', min: '23', max: '28', recommendations: [] },
      { date: '수', weatherLabel: '흐림', min: '22', max: '27', recommendations: [] },
    ],
  });
});

export default router;

