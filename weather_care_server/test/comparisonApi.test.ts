import { describe, expect, it } from 'vitest';
import router, { lastYearDate, yesterdayDate } from '../src/api/comparison';
import { env } from 'cloudflare:test';
import { seedCollectedComparison } from './collectedWeatherFixture';

describe('comparison dates', () => {
  it('uses the Korean calendar date across the UTC date boundary', () => {
    const koreanMidnight = new Date('2026-08-23T15:30:00Z');

    expect(yesterdayDate(koreanMidnight)).toBe('2026-08-23');
    expect(lastYearDate(koreanMidnight)).toBe('2025-08-24');
  });
});

describe('yesterday comparison API', () => {
  it('returns current and yesterday values from the same observation basis', async () => {
    await seedCollectedComparison(60, 121, {
      stationId: '108',
      distanceKm: 2.4,
      currentObservedAt: '2026-09-16T14:00:00+09:00',
      comparisonObservedAt: '2026-09-15T14:00:00+09:00',
      current: { temperature: 24, apparentTemperature: 25 },
      comparison: { temperature: 20, apparentTemperature: 21 },
    });
    const response = await router.request('/yesterday?nx=60&ny=121', {}, {
      DB: env.DB,
    });
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      comparisonAvailable: true,
      current: { temperature: 24 },
      comparison: { temperature: 20 },
      basis: {
        provider: 'KMA_ASOS',
        dataRole: 'OBSERVATION',
        stationId: '108',
      },
    });
  });
});
