import { beforeEach, describe, expect, it } from 'vitest';
import { env } from 'cloudflare:test';
import { archiveSnowDepth, readSnowDepthHistory, selectSnowDepthHistory } from '../src/services/snowDepthHistory';
import { saveCollectedCache } from '../src/database/collectedWeatherRepository';
import type { SnowStation } from '../src/providers/weather/kmaSnowObservationProvider';

const location = { nx: 60, ny: 127, coordinates: { latitude: 37.5, longitude: 127 } };
const station = (time: string, depthCm: number, overrides: Partial<SnowStation> = {}): SnowStation => ({
  observedAt: `2026-10-26T${time}:00+09:00`, stationId: '108', stationName: '관측소',
  stationKind: '000', latitude: 37.5, longitude: 127, depthCm, ...overrides,
});
const now = new Date('2026-10-26T12:10:00+09:00');

describe('현재 적설 시간별 관측 이력', () => {
  beforeEach(async () => {
    await env.DB.prepare(`CREATE TABLE IF NOT EXISTS weather_cache (cache_key TEXT PRIMARY KEY,
      region_id TEXT, nx INTEGER, ny INTEGER, cache_type TEXT NOT NULL, payload TEXT NOT NULL,
      status TEXT NOT NULL, updated_at TEXT NOT NULL)`).run();
  });

  it('같은 시각 재수집과 시간 내 갱신을 중복시키지 않고 0cm도 보관한다', async () => {
    for (const row of [station('10:00', 1), station('10:20', 2), station('11:00', 0)]) {
      await archiveSnowDepth(env.DB, { requestedAt: '', stations: [row] }, new Date(row.observedAt));
    }
    await archiveSnowDepth(env.DB, { requestedAt: '', stations: [station('10:00', 99)] }, now);
    await saveCollectedCache(env.DB, { key: 'COLLECTED_NATIONWIDE_SNOW_TOTAL', type: 'SNOW',
      value: { stations: [station('11:00', 0)] }, updatedAt: now });
    const result = await readSnowDepthHistory(env.DB, location, now);
    expect(result.map((row) => row.depthCm)).toEqual([2, 0]);
    expect(result[0].observedAt).toContain('10:20');
    expect(result.every((row) => row.stationId === '108' && row.distanceKm === 0)).toBe(true);
  });

  it('관측소를 섞지 않고 이전 날짜·미래·음수·결측을 현재 이력으로 채우지 않는다', () => {
    const result = selectSnowDepthHistory([
      station('10:00', 2), station('12:00', 3), station('13:00', 50), station('11:00', -1),
      station('09:00', 20, { stationId: '200', latitude: 38 }),
      station('01:00', 10, { observedAt: '2026-10-25T23:00:00+09:00' }),
    ], location, now);
    expect(result.map((row) => row.depthCm)).toEqual([2, 3]);
    expect(selectSnowDepthHistory([], location, now)).toEqual([]);
  });

  it('48시간이 지난 적설 이력만 정리하고 다른 날씨 캐시는 유지한다', async () => {
    await archiveSnowDepth(env.DB, { requestedAt: '', stations: [station('10:00', 2,
      { observedAt: '2026-10-23T10:00:00+09:00' })] }, new Date('2026-10-23T10:10:00+09:00'));
    await saveCollectedCache(env.DB, { key: 'OTHER_WEATHER', type: 'OTHER', value: { keep: true } });
    await archiveSnowDepth(env.DB, { requestedAt: '', stations: [station('12:00', 3)] }, now);
    expect(await env.DB.prepare("SELECT cache_key FROM weather_cache WHERE cache_key='COLLECTED_SNOW_HISTORY_2026102310'").first()).toBeNull();
    expect(await env.DB.prepare("SELECT cache_key FROM weather_cache WHERE cache_key='OTHER_WEATHER'").first()).not.toBeNull();
  });
});
