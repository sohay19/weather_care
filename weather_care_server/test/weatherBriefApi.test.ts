import { createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import { afterEach, describe, expect, it, vi } from 'vitest';
import router from '../src/api/weather';
import { KmaWeatherProvider } from '../src/providers/weather/kmaWeatherProvider';
import * as environmental from '../src/providers/environmental/environmentalDataService';
import { LifestyleInsightType, WeatherRuleFactType, type WeatherSnapshot } from '../src/types';
import { buildLifestyleMessages } from '../src/presentation/lifestyleMessages';
import { env } from 'cloudflare:test';
import { seedCollectedRegion } from './collectedWeatherFixture';

afterEach(() => { vi.restoreAllMocks(); vi.useRealTimers(); });

describe('Today brief display deadline', () => {
  it.each([
    ['2026-09-10T05:00:00Z', '2026-09-10T04:00:00Z', '오후 2시'],
    ['2026-09-11T05:00:00Z', '2026-09-10T04:00:00Z', '내일 오후 2시'],
    ['2027-01-01T05:00:00Z', '2026-12-31T14:00:00Z', '내일 오후 2시'],
  ])('retains the date and original validity of UV grounding: %s', (forecastAt, fetchedAt, label) => {
    const sample: WeatherSnapshot = { observedAt: forecastAt, forecastAt, fetchedAt, uvIndex: 7 };
    const insights = [LifestyleInsightType.STRONG_SUN_EXPOSURE, LifestyleInsightType.SUNSCREEN_USEFUL]
      .map((type) => ({ type, score: 70, sourceFacts: [WeatherRuleFactType.UV_HIGH] }));
    for (const message of buildLifestyleMessages(insights, [], [sample], '수원')) {
      expect(message.parts.find((part) => part.role === 'OFFICIAL_FACT')).toMatchObject({
        text: `기상청은 ${label} 수원의 자외선지수를 7, 높음 단계로 예보했어요`,
        validFrom: forecastAt,
      });
    }
    expect(sample.forecastAt).toBe(forecastAt);
  });

  it.each([
    ['14:10:00', 14, '지금', '2026-09-10T05:59:59.000Z'],
    ['14:10:00', 15, '오후 3시', '2026-09-10T06:00:00.000Z'],
    ['16:00:00', 14, undefined, undefined],
  ])('serializes the deadline at %s for hour %s without shifting official time', async (clock, hour, label, expiry) => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(`2026-09-10T${clock}+09:00`));
    const time = `2026-09-10T${hour}:00:00+09:00`;
    const sample: WeatherSnapshot = {
      observedAt: time, forecastAt: time, validTo: `2026-09-10T${hour}:59:59+09:00`,
      uvIndex: 7, temperature: 25, apparentTemperature: 25,
    };
    const forecast = {
      current: sample, hourly: [sample], daily: [], baseDate: '20260910',
      baseTime: '1100', dataSource: '기상청',
    };
    await seedCollectedRegion(60, 121, forecast);
    vi.spyOn(environmental, 'loadEnvironmentalData').mockResolvedValue({ sources: {
      uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNAVAILABLE' },
      airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' },
    } });
    vi.spyOn(environmental, 'enrichForecastWithEnvironmentalData').mockImplementation((input) => input);
    const ctx = createExecutionContext();
    const response = await router.request('/today?nx=60&ny=121', {}, { DB: env.DB }, ctx);
    expect(response.status).toBe(200);
    const data = await response.json<{ brief: string; briefExpiresAt?: string; current: WeatherSnapshot; generatedAt: string }>();
    expect(data.briefExpiresAt).toBe(expiry);
    expect(data.current.forecastAt).toBe(time);
    expect(data.generatedAt).toBe(new Date().toISOString());
    if (label) expect(data.brief).toContain(`${label} 외출한다면`);
    else expect(data.brief).toBe('오늘은 외출 전에 시간별 예보를 확인하세요');
    await waitOnExecutionContext(ctx);
  });
});
