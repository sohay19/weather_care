import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { createComparisonRouter } from '../src/api/comparison';
import { currentFromUltraShortObservation } from '../src/api/weather';
import { getApiHubUsage } from '../src/database/apiUsageRepository';
import { saveGridObservationSnapshot } from '../src/database/gridObservationRepository';
import { asD1Database, runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { kmaGridCoordinates } from '../src/regions/kmaGridCoordinates';
import { collectAwsHourlyFallback, readCurrentWeatherObservation } from '../src/services/awsHourlyFallback';
import { observationSnapshot } from './gridObservationFixture';

const now = new Date('2026-11-10T09:14:00+09:00');
const todayAt = '2026-11-10T00:00:00.000Z';
const grid = kmaGridCoordinates(60, 127)!;
const request = '/yesterday?nx=60&ny=127';
const header = '# YYMMDDHHMI STN WD1 WS1 WDS WSS WD10 WS10 TA RE RN-15m RN-60m RN-12h RN-DAY HM PA PS TD';
let database: SqliteD1Database;

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(now);
  database = new SqliteD1Database(':memory:');
  runSqliteMigrations(database);
});

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
  database.close();
});

function mockProvider(yesterdayStation = '108') {
  return vi.spyOn(globalThis, 'fetch').mockImplementation(async (input) => {
    const url = new URL(String(input));
    if (url.pathname.endsWith('stn_inf.php')) {
      return new Response(`108 ${grid.longitude} ${grid.latitude}\n159 129.0756 35.1796`);
    }
    expect(url.pathname).toMatch(/nph-aws2_min$/);
    expect(url.searchParams.get('stn')).toBe('0');
    const slot = url.searchParams.get('tm2');
    const row = (at: string, station: string, temperature: number) =>
      `${at},${station},350.5,1.1,10.3,1.7,67.8,2.9,${temperature},-99.9,0.0,0.0,0.0,0.0,75.3,1018.4,1029.3,-2.0,=`;
    return new Response(`#START7777\n${header}\n${row('202611100859', '108', 20)}\n` +
      (slot === '202611100900' ? row(slot, '108', 2.6) : row('202611090900', yesterdayStation, 6.3)));
  });
}

it('전국 정각 두 회차를 공유 예산에 기록하고 현재·비교는 같은 관측소를 캐시에서 읽는다', async () => {
  const db = asD1Database(database);
  const fetcher = mockProvider();
  await Promise.all([collectAwsHourlyFallback(db, 'synthetic', now), collectAwsHourlyFallback(db, 'synthetic', now)]);
  await collectAwsHourlyFallback(db, 'synthetic', now);
  const current = await readCurrentWeatherObservation(db, 60, 127, now);
  expect(current?.value).toMatchObject({ observedAt: todayAt, temperature: 2.6, windSpeed: 2.9, sourceLocation: { stationId: '108' } });
  expect(currentFromUltraShortObservation({ observedAt: todayAt }, current, now)).toMatchObject({
    temperature: 2.6, apparentTemperature: expect.any(Number), dataRole: 'OBSERVATION',
  });
  const response = await createComparisonRouter({ now: () => now }).request(request, {}, { DB: db });
  const result = await response.json();
  expect(result).toMatchObject({
    comparisonAvailable: true, current: { temperature: 2.6, apparentTemperature: expect.any(Number) },
    comparison: { temperature: 6.3, apparentTemperature: expect.any(Number) },
    basis: { provider: 'KMA_AWS_OBSERVATION' },
  });
  expect(result.basis).not.toHaveProperty('currentObservedAt');
  expect(result.basis).not.toHaveProperty('comparisonObservedAt');
  expect(result.basis).not.toHaveProperty('stationId');
  expect(result.basis).not.toHaveProperty('distanceKm');
  expect(fetcher).toHaveBeenCalledTimes(3);
  expect(await getApiHubUsage(db, now)).toMatchObject({ requestCount: 3 });
});

it('어제 다른 관측소만 있으면 비교하지 않고 새 격자 실황을 항상 우선한다', async () => {
  const db = asD1Database(database);
  mockProvider('159');
  await collectAwsHourlyFallback(db, 'synthetic', now);
  const router = createComparisonRouter({ now: () => now });
  expect(await (await router.request(request, {}, { DB: db })).json()).toMatchObject({
    comparisonAvailable: false, reason: 'HISTORICAL_AWS_OBSERVATION_UNAVAILABLE',
  });
  expect(await readCurrentWeatherObservation(db, 60, 127, new Date('2026-11-10T10:06:00+09:00'))).toBeNull();
  expect(await readCurrentWeatherObservation(db, 98, 76, now)).toBeNull();
  await saveGridObservationSnapshot(db, observationSnapshot('2026-11-10T09:00:00+09:00', 4), now);
  expect((await readCurrentWeatherObservation(db, 60, 127, now))?.value).toMatchObject({
    temperature: 4, provider: 'KMA_APIHUB_GRID_OBSERVATION',
  });
});
