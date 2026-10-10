import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createComparisonRouter, lastYearDate, yesterdayDate } from '../src/api/comparison';
import { env } from 'cloudflare:test';
import { seedCollectedUltraShortObservation } from './collectedWeatherFixture';
import { saveGridObservationSnapshot } from '../src/database/gridObservationRepository';
import { observationSnapshot } from '../test-node/gridObservationFixture';
import { ultraShortApparentTemperature } from '../src/providers/weather/kmaUltraShortObservationProvider';

const now = new Date('2026-10-04T11:54:00+09:00');
const observation = {
  observedAt: '2026-10-04T11:40:00+09:00', provider: 'KMA_APIHUB_GRID_OBSERVATION' as const,
  temperature: 23.8, humidity: 43.5, windSpeed: 2.6, rainDetected: false,
};

describe('comparison dates', () => {
  it('한국 날짜 경계를 사용한다', () => {
    const midnight = new Date('2026-08-23T15:30:00Z');
    expect(yesterdayDate(midnight)).toBe('2026-08-23');
    expect(lastYearDate(midnight)).toBe('2025-08-24');
  });
});

describe('어제 동시각 격자 실황 비교', () => {
  beforeEach(async () => {
    await seedCollectedUltraShortObservation(60, 121, observation, now);
    await env.DB.exec('DELETE FROM grid_observation_snapshots; DELETE FROM weather_cache;');
  });
  it('예보 없이 현재 실황과 정확히 24시간 전을 같은 산식으로 비교하고 표시용 시각을 생략한다', async () => {
    await seedCollectedUltraShortObservation(60, 121, observation, now);
    await saveGridObservationSnapshot(env.DB, observationSnapshot('2026-10-03T11:40:00+09:00', 20.6, 43.2, 3.4), now);
    const fetcher = vi.spyOn(globalThis, 'fetch');
    try {
      const response = await createComparisonRouter({ now: () => now }).request('/yesterday?nx=60&ny=121', {}, { DB: env.DB });
      expect(response.status).toBe(200);
      expect(await response.json()).toEqual({
        comparisonAvailable: true,
        current: { temperature: 23.8, apparentTemperature: ultraShortApparentTemperature(observation) },
        comparison: { temperature: 20.6, apparentTemperature: ultraShortApparentTemperature({ ...observation, observedAt: '2026-10-03T11:40:00+09:00', temperature: 20.6, humidity: 43.2, windSpeed: 3.4 }) },
        targetDate: '2026-10-03',
        basis: { provider: 'KMA_APIHUB_GRID_OBSERVATION', dataRole: 'OBSERVATION_VS_OBSERVATION', gridX: 60, gridY: 121 },
      });
      expect(fetcher).not.toHaveBeenCalled();
    } finally { fetcher.mockRestore(); }
  });

  it('분이 다른 어제 자료로 값을 채우지 않는다', async () => {
    await seedCollectedUltraShortObservation(60, 121, observation, now);
    await saveGridObservationSnapshot(env.DB, observationSnapshot('2026-10-03T11:50:00+09:00'), now);
    const response = await createComparisonRouter({ now: () => now }).request('/yesterday?nx=60&ny=121', {}, { DB: env.DB });
    expect(await response.json()).toMatchObject({ comparisonAvailable: false, reason: 'HISTORICAL_GRID_OBSERVATION_UNAVAILABLE' });
  });

  it('AWS 기존 캐시를 비교에 쓰지 않는다', async () => {
    await seedCollectedUltraShortObservation(60, 121, { ...observation, provider: 'KMA_AWS_OBSERVATION' }, now);
    const response = await createComparisonRouter({ now: () => now }).request('/yesterday?nx=60&ny=121', {}, { DB: env.DB });
    expect(await response.json()).toMatchObject({ comparisonAvailable: false, reason: 'CURRENT_GRID_OBSERVATION_UNAVAILABLE' });
  });

  it('자정 구간은 전날 23:50과 전전날 23:50을 비교한다', async () => {
    const midnight = new Date('2026-10-04T00:04:00+09:00');
    await seedCollectedUltraShortObservation(60, 121, { ...observation, observedAt: '2026-10-03T23:50:00+09:00' }, midnight);
    await saveGridObservationSnapshot(env.DB, observationSnapshot('2026-10-02T23:50:00+09:00'), midnight);
    const response = await createComparisonRouter({ now: () => midnight }).request('/yesterday?nx=60&ny=121', {}, { DB: env.DB });
    expect(await response.json()).toMatchObject({ comparisonAvailable: true, targetDate: '2026-10-02' });
  });
});
