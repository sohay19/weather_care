import { createExecutionContext, waitOnExecutionContext } from 'cloudflare:test';
import { afterEach, describe, expect, it, vi } from 'vitest';
import router, { briefingLocationKey } from '../src/api/weather';
import { KmaWeatherProvider } from '../src/providers/weather/kmaWeatherProvider';
import * as environmental from '../src/providers/environmental/environmentalDataService';
import {
  LifestyleInsightType,
  WeatherRuleFactType,
  type BriefingTimelineEntry,
  type CanonicalBriefingIntent,
  type WeatherSnapshot,
} from '../src/types';
import { buildLifestyleMessages } from '../src/presentation/lifestyleMessages';
import { env } from 'cloudflare:test';
import { seedCollectedRegion } from './collectedWeatherFixture';

afterEach(() => { vi.restoreAllMocks(); vi.useRealTimers(); });

describe('Today brief display deadline', () => {
  it('같은 57/125에서도 항동 행정구역 context를 briefingId에 반영한다', () => {
    expect(briefingLocationKey(
      57,
      125,
      '1153080000',
      '서울특별시 구로구 항동',
    )).toBe('57:125:admin:1153080000');
    expect(briefingLocationKey(
      57,
      125,
      undefined,
      '경기도 부천시 범박동',
    )).not.toBe('57:125:admin:1153080000');
  });

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
    ['14:10:00', 14, 'UV'],
    ['14:10:00', 15, 'UV'],
    ['16:00:00', 14, 'DEFAULT'],
  ])('serializes canonical briefing at %s for hour %s without shifting official time', async (clock, hour, sceneId) => {
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
    const response = await router.request(
      '/today?nx=60&ny=121&regionCode=1153080000&regionName='
        + encodeURIComponent('서울특별시 구로구 항동'),
      {},
      { DB: env.DB },
      ctx,
    );
    expect(response.status).toBe(200);
    const data = await response.json<{
      brief: string;
      briefExpiresAt?: string;
      briefing: CanonicalBriefingIntent;
      briefingTimeline: BriefingTimelineEntry[];
      current: WeatherSnapshot;
      generatedAt: string;
    }>();
    expect(data.briefing.sceneId).toBe(sceneId);
    expect(data.briefing.locationKey).toBe('60:121:admin:1153080000');
    expect(data.brief).toBe(data.briefing.copy.medium);
    expect(data.briefExpiresAt).toBe(data.briefing.nextBriefingBoundary);
    expect(data.briefingTimeline[0]).toMatchObject({
      briefingId: data.briefing.briefingId,
      sceneId,
      validFrom: data.briefing.validFrom,
      validUntil: data.briefing.validUntil,
    });
    expect(data.current.forecastAt).toBe(time);
    expect(data.generatedAt).toBe(new Date().toISOString());
    if (sceneId === 'UV') expect(data.brief).toContain('자외선');
    else expect(data.brief).not.toContain('자외선');
    await waitOnExecutionContext(ctx);
  });
});
