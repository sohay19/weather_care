import { describe, expect, it, vi } from 'vitest';
import { createComparisonRouter, lastYearDate, yesterdayDate } from '../src/api/comparison';
import { env } from 'cloudflare:test';
import { seedCollectedRegion } from './collectedWeatherFixture';

describe('comparison dates', () => {
  it('uses the Korean calendar date across the UTC date boundary', () => {
    const koreanMidnight = new Date('2026-08-23T15:30:00Z');

    expect(yesterdayDate(koreanMidnight)).toBe('2026-08-23');
    expect(lastYearDate(koreanMidnight)).toBe('2025-08-24');
  });
});

describe('yesterday comparison API', () => {
  it('compares the next-hour forecast with the previous-day observation', async () => {
    await seedCollectedRegion(60, 121, {
      current: {
        observedAt: '2026-09-21T13:00:00+09:00',
        forecastAt: '2026-09-21T13:00:00+09:00',
        temperature: 23,
      },
      hourly: [{
        observedAt: '2026-09-21T14:00:00+09:00',
        forecastAt: '2026-09-21T14:00:00+09:00',
        issuedAt: '2026-09-21T11:00:00+09:00',
        temperature: 24,
        apparentTemperature: 25,
      }],
      daily: [],
      baseDate: '20260921',
      baseTime: '1100',
      dataSource: 'KMA',
    });
    const requested = <URL>[];
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = new URL(input.toString());
      requested.push(url);
      return Response.json({
        response: {
          header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' },
          body: {
            items: {
              item: [
                { category: 'PTY', obsrValue: '0' },
                { category: 'T1H', obsrValue: '20' },
                { category: 'REH', obsrValue: '60' },
                { category: 'WSD', obsrValue: '2' },
              ],
            },
          },
        },
      });
    });
    const router = createComparisonRouter({
      fetcher,
      now: () => new Date('2026-09-21T04:10:00Z'),
    });
    const response = await router.request('/yesterday?nx=60&ny=121', {}, {
      DB: env.DB,
      KMA_SERVICE_KEY: 'service-key',
    });
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      comparisonAvailable: true,
      current: { temperature: 24, apparentTemperature: 25 },
      comparison: { temperature: 20 },
      targetDate: '2026-09-20',
      basis: {
        provider: 'KMA_FORECAST_VS_ULTRA_SHORT_OBSERVATION',
        dataRole: 'FORECAST_VS_OBSERVATION',
        gridX: 60,
        gridY: 121,
        currentForecastAt: '2026-09-21T14:00:00+09:00',
        comparisonObservedAt: '2026-09-20T14:00:00+09:00',
      },
    });
    expect(requested).toHaveLength(1);
    expect(requested.map((url) => ({
      date: url.searchParams.get('base_date'),
      time: url.searchParams.get('base_time'),
      nx: url.searchParams.get('nx'),
      ny: url.searchParams.get('ny'),
    }))).toEqual([
      { date: '20260920', time: '1400', nx: '60', ny: '121' },
    ]);
  });
});
