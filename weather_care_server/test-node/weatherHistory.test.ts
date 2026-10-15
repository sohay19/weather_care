import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { SqliteD1Database, runSqliteMigrations, asD1Database } from '../src/node/sqliteD1';
import { saveAirQualityHistory, readDailyAirQualityObservation } from '../src/services/airQualityHistory';
import { readObservedDailyHumidity, archiveActiveDailyHumidity } from '../src/services/dailyHumidityHistory';
import { collectedCacheKey, saveCollectedCache } from '../src/database/collectedWeatherRepository';
import weatherRouter from '../src/api/weather';

let database: SqliteD1Database;
beforeEach(() => { database = new SqliteD1Database(':memory:'); runSqliteMigrations(database); });
afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals(); database.close(); });

describe('지난 날짜 관측 기록', () => {
  it('이미 수집한 대기질을 시간·측정소별로 보관하고 같은 시각 갱신은 중복하지 않는다', async () => {
    const db = asD1Database(database);
    const now = new Date('2026-10-15T12:00:00+09:00');
    const first = { stationName: '구로', observedAt: '2026-10-14T23:00:00+09:00',
      pm25: 12, pm10: 25, provider: 'AIRKOREA' as const };
    await saveAirQualityHistory(db, '서울', [first], now);
    await saveAirQualityHistory(db, '서울', [{ ...first, pm25: 14 },
      { ...first, observedAt: '2026-10-14T22:00:00+09:00', pm25: 10 }], now);
    const catalog = { fetchedAt: now.toISOString(), stations: [
      { stationName: '구로', latitude: 37.5, longitude: 126.9 },
    ] };
    expect(await readDailyAirQualityObservation(db, '2026-10-14', catalog,
      { latitude: 37.5, longitude: 126.9 })).toMatchObject({
      stationName: '구로', observedHours: 2, pm25: 12, pm10: 25,
    });
    const row = database.sqlite.prepare("SELECT COUNT(*) AS n FROM weather_cache WHERE cache_type='AIR_HISTORY'").get();
    expect(row).toEqual({ n: 1 });
  });

  it('24시간 모두 보관된 격자 습도만 일평균으로 저장한다', async () => {
    const db = asD1Database(database);
    const now = new Date('2026-10-15T12:00:00+09:00');
    const insert = database.sqlite.prepare(`INSERT INTO grid_observation_snapshots
      (observed_at,payload,updated_at) VALUES (?,?,?)`);
    const start = Date.parse('2026-10-14T00:00:00+09:00');
    for (let hour = 0; hour < 24; hour++) {
      const at = new Date(start + hour * 3_600_000).toISOString();
      insert.run(at, JSON.stringify({ fields: { REH: { values: [hour < 12 ? 40 : 60] } } }), now.toISOString());
    }
    expect(await readObservedDailyHumidity(db, '2026-10-14', 1, 1, now)).toBe(50);
    database.sqlite.prepare("DELETE FROM weather_cache WHERE cache_type='OBSERVED_DAILY_HUMIDITY'").run();
    await archiveActiveDailyHumidity(db, now, [{ nx: 1, ny: 1 }]);
    database.sqlite.prepare('DELETE FROM grid_observation_snapshots').run();
    expect(await readObservedDailyHumidity(db, '2026-10-14', 1, 1, now)).toBe(50);
    expect(await readObservedDailyHumidity(db, '2026-10-13', 1, 1, now)).toBeUndefined();
  });

  it('한 시간이라도 빠진 습도를 24시간 평균으로 오인하지 않는다', async () => {
    const db = asD1Database(database);
    const now = new Date('2026-10-15T12:00:00+09:00');
    const start = Date.parse('2026-10-14T00:00:00+09:00');
    const insert = database.sqlite.prepare(`INSERT INTO grid_observation_snapshots
      (observed_at,payload,updated_at) VALUES (?,?,?)`);
    for (let hour = 0; hour < 23; hour++) {
      insert.run(new Date(start + hour * 3_600_000).toISOString(),
        JSON.stringify({ fields: { REH: { values: [50] } } }), now.toISOString());
    }
    expect(await readObservedDailyHumidity(db, '2026-10-14', 1, 1, now)).toBeUndefined();
  });

  it('Week의 지난 날짜 응답에는 저장된 대기질·습도와 일 최대풍속을 관측값으로 연결한다', async () => {
    const now = new Date('2026-10-15T12:00:00+09:00');
    vi.useFakeTimers();
    vi.setSystemTime(now);
    const db = asD1Database(database);
    const catalog = { fetchedAt: now.toISOString(), stations: [
      { stationName: '구로', latitude: 37.5, longitude: 126.9 },
    ] };
    await saveCollectedCache(db, { key: collectedCacheKey.nationwideAir,
      type: 'COLLECTED_NATIONWIDE_AIR', value: { catalog, observations: [], collectedAt: now.toISOString() }, updatedAt: now });
    await saveAirQualityHistory(db, '서울', [{ stationName: '구로',
      observedAt: '2026-10-14T10:00:00+09:00', pm25: 14, provider: 'AIRKOREA' }], now);
    await saveCollectedCache(db, { key: 'OBSERVED_DAILY_HUMIDITY_2026-10-14_58_125',
      type: 'OBSERVED_DAILY_HUMIDITY', value: 54, updatedAt: now });
    await saveCollectedCache(db, { key: collectedCacheKey.weekly(58, 125),
      type: 'COLLECTED_WEEKLY', value: {
        forecast: { current: { observedAt: now.toISOString() }, hourly: [], daily: [],
          baseDate: '20261015', baseTime: '1200', dataSource: '기상청 단기예보' },
        midTermDays: [], airQuality: [],
        observedDays: [{ date: '20261014', forecastSource: 'KMA_OBSERVATION',
          minTemperature: 15, maxTemperature: 23, maximumWindSpeed: 5.4,
          skyCondition: '비·눈 기록 없음', precipitationProbability: 0,
          precipitationAmount: 0, snowProbability: 0, snowfallAmount: 0 }],
      }, updatedAt: now });
    const response = await weatherRouter.request(
      '/weekly?nx=58&ny=125&latitude=37.5&longitude=126.9', {}, { DB: db });
    expect(response.status).toBe(200);
    const body = await response.json() as { days: { forecastDate: string; averageHumidity?: number;
      maximumWindSpeed?: number; airQualityObservation?: { stationName: string; pm25?: number } }[] };
    expect(body.days.find(day => day.forecastDate === '2026-10-14')).toMatchObject({
      averageHumidity: 54, maximumWindSpeed: 5.4,
      airQualityObservation: { stationName: '구로', pm25: 14 },
    });
  });
});
