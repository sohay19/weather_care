import * as nationalForecast from '../src/services/nationwideForecastCache';
import { KmaGridObservationProvider, gridObservationKoreanIso } from '../src/providers/weather/kmaGridObservationProvider';
import { observationSnapshot } from './gridObservationFixture';
import { KmaUvProvider } from '../src/providers/uv/kmaUvProvider';
import { KmaWarningProvider } from '../src/providers/warnings/kmaWarningProvider';
import { AirKoreaAirQualityProvider, AIRKOREA_PROVINCES } from '../src/providers/air/airKoreaAirQualityProvider';
import { AirKoreaForecastProvider, AIRKOREA_FORECAST_AREAS } from '../src/providers/air/airKoreaForecastProvider';
import { saveCollectedSourceVersion } from '../src/database/collectedWeatherRepository';
import { latestMidTermIssueTimes } from '../src/providers/weather/kmaMidTermProvider';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { runWeatherCollectionJob } from '../src/collection/weatherCollectionJob';
import { SqliteD1Database, runSqliteMigrations } from '../src/node/sqliteD1';
import { nodeServerEnv } from '../src/node/runtime';
import { KmaDailyObservationProvider } from '../src/providers/weather/kmaDailyObservationProvider';
import { KmaHourlyObservationProvider } from '../src/providers/weather/kmaHourlyObservationProvider';
import { NATIONAL_DAILY_KEY, NATIONAL_VISIBILITY_KEY, readNationwideVisibility } from '../src/services/nationwideWeatherCache';
import { saveCollectedCache, getCollectedCache } from '../src/database/collectedWeatherRepository';
import { inspectOperationalPrewarm } from '../src/node/prewarmNationwide';

let database: SqliteD1Database;
const now = new Date('2026-10-04T09:30:00+09:00');
beforeEach(() => {
  database = new SqliteD1Database(':memory:'); runSqliteMigrations(database);
  vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('TEST_EXTERNAL_NETWORK_FORBIDDEN'));
  vi.spyOn(console, 'log').mockImplementation(() => {});
});
afterEach(() => { vi.restoreAllMocks(); database.close(); });

describe('대표 격자와 무관한 전국 원본 수집', () => {
  it('설치가 0개여도 전국 시정 원본을 저장하고 같은 격자의 실제 GPS에서 관측소를 직접 고른다', async () => {
    const source = vi.spyOn(KmaHourlyObservationProvider.prototype, 'getObservationsAt').mockResolvedValue({
      observedAt: '2026-10-04T08:00:00+09:00', stations: [
        { observedAt: '202610040800', stationId: 'A', latitude: 37.25, longitude: 127, temperature: 20, visibilityMeters: 1000 },
        { observedAt: '202610040800', stationId: 'B', latitude: 37.29, longitude: 127, temperature: 20, visibilityMeters: 20_000 },
      ],
    });
    const env = nodeServerEnv(database, { KMA_APIHUB_KEY: 'synthetic' });
    await runWeatherCollectionJob(env, { now: new Date('2026-10-04T09:00:00+09:00'), collectCore: false, collectHourlyObservations: true });
    await runWeatherCollectionJob(env, { now: new Date('2026-10-04T09:59:59+09:00'), collectCore: false, collectHourlyObservations: true });
    expect(source).toHaveBeenCalledOnce();
    expect(source).toHaveBeenCalledWith(new Date('2026-10-04T08:00:00Z'), { includeVisibility: true });
    expect((await readNationwideVisibility(env.DB, { nx: 60, ny: 121, coordinates: { latitude: 37.25, longitude: 127 } }, now))?.stationId).toBe('A');
    expect((await readNationwideVisibility(env.DB, { nx: 60, ny: 121, coordinates: { latitude: 37.29, longitude: 127 } }, now))?.stationId).toBe('B');
    expect(database.sqlite.prepare("SELECT COUNT(*) AS n FROM weather_cache WHERE cache_type='COLLECTED_VISIBILITY'").get()).toEqual({ n: 0 });
    expect(globalThis.fetch).not.toHaveBeenCalled();
  });

  it('이번 정시 캐시는 제외하고 유효한 이전 시정만 보존하며 3시간 초과 시 제공하지 않는다', async () => {
    const env = nodeServerEnv(database, {});
    await saveCollectedCache(env.DB, { key: NATIONAL_VISIBILITY_KEY, type: 'COLLECTED_NATIONWIDE_VISIBILITY',
      value: { observedAt: '2026-10-04T09:00:00+09:00', stations: [
        { observedAt: '202610040900', stationId: 'A', latitude: 37.25, longitude: 127, visibilityMeters: 500 },
      ] }, updatedAt: now });
    const location = { nx: 60, ny: 121, coordinates: { latitude: 37.25, longitude: 127 } };
    expect(await readNationwideVisibility(env.DB, location, now)).toBeUndefined();
    await saveCollectedCache(env.DB, { key: 'COLLECTED_VISIBILITY_60_121', type: 'COLLECTED_VISIBILITY',
      value: { observedAt: '2026-10-04T08:00:00+09:00', stationId: 'B', distanceKm: 2,
        visibilityMeters: 1000, provider: 'KMA_ASOS' }, updatedAt: now });
    expect((await readNationwideVisibility(env.DB, location, now))?.stationId).toBe('B');
    expect(await readNationwideVisibility(env.DB, location, new Date('2026-10-04T12:00:01+09:00'))).toBeUndefined();
  });

  it('과거 일 관측은 전국 관측소 원본을 저장하고 같은 완료 날짜를 중복 수집하지 않는다', async () => {
    const source = vi.spyOn(KmaDailyObservationProvider.prototype, 'getNationwide').mockResolvedValue({
      stations: [{ date: '2026-10-03', stationId: 'A', latitude: 37.25, longitude: 127, minTemperature: 15, maxTemperature: 25, precipitationAmount: 0, snowfallAmount: 0 }], snowfallMetricAvailable: true, completedDates: Array.from({ length: 7 }, (_, i) => new Date(Date.UTC(2026, 8, 27 + i)).toISOString().slice(0, 10)),
    });
    const env = nodeServerEnv(database, { KMA_APIHUB_KEY: 'synthetic' });
    await runWeatherCollectionJob(env, { now, collectCore: false, dailyObservationLookbackDays: 7 });
    await runWeatherCollectionJob(env, { now, collectCore: false, dailyObservationLookbackDays: 7 });
    expect(source).toHaveBeenCalledOnce();
    expect(source).toHaveBeenCalledWith('2026-09-27', '2026-10-03');
    expect((await getCollectedCache<{ stations: unknown[] }>(env.DB, NATIONAL_DAILY_KEY))?.value.stations).toHaveLength(1);
  });

  it('시작 검사는 37,697격자의 원본을 검사하며 대표 격자 캐시를 필수로 요구하지 않는다', () => {
    const result = inspectOperationalPrewarm({ database, env: nodeServerEnv(database, {}), close: () => {} }, now);
    expect(result.totalGrids).toBe(37_697);
    expect(result.missingSample.some((key) => /^COLLECTED_(REGION|VISIBILITY|WEEKLY)_\d/.test(key))).toBe(false);
    expect(result.missingSample).toContain('NATIONAL_FORECAST_SOURCE');
  });
});


it('일 관측의 일부 지표가 실패하면 완료로 표시하지 않고 재수집해 기존 값을 보존한다', async () => {
  const dates = Array.from({ length: 7 }, (_, i) => new Date(Date.UTC(2026, 8, 27 + i)).toISOString().slice(0, 10));
  const source = vi.spyOn(KmaDailyObservationProvider.prototype, 'getNationwide')
    .mockResolvedValueOnce({ stations: [{ date: '2026-10-03', stationId: 'A', latitude: 37, longitude: 127, minTemperature: 15 }],
      snowfallMetricAvailable: false, completedDates: [] })
    .mockResolvedValueOnce({ stations: [{ date: '2026-10-03', stationId: 'A', latitude: 37, longitude: 127, maxTemperature: 25, snowfallAmount: 0 }],
      snowfallMetricAvailable: true, completedDates: dates });
  const env = nodeServerEnv(database, { KMA_APIHUB_KEY: 'synthetic' });
  await runWeatherCollectionJob(env, { now, collectCore: false, dailyObservationLookbackDays: 7 });
  await runWeatherCollectionJob(env, { now, collectCore: false, dailyObservationLookbackDays: 7 });
  await runWeatherCollectionJob(env, { now, collectCore: false, dailyObservationLookbackDays: 7 });
  expect(source).toHaveBeenCalledTimes(2);
  const cached = await getCollectedCache<{ stations: unknown[] }>(env.DB, NATIONAL_DAILY_KEY);
  expect(cached?.value.stations).toEqual([expect.objectContaining({ minTemperature: 15, maxTemperature: 25, snowfallAmount: 0 })]);
});


it('전국 일 관측의 ISO 날짜를 시작 검사에서도 같은 완료 날짜로 인정한다', async () => {
  const dates = Array.from({ length: 7 }, (_, i) => new Date(Date.UTC(2026, 8, 27 + i)).toISOString().slice(0, 10));
  const env = nodeServerEnv(database, {});
  await saveCollectedCache(env.DB, { key: NATIONAL_DAILY_KEY, type: 'COLLECTED_NATIONWIDE_DAILY', updatedAt: now,
    value: { completedDates: dates, snowfallMetricAvailable: true,
      stations: dates.map(date => ({ date, stationId: '108', latitude: 37.57, longitude: 126.96, minTemperature: 15, maxTemperature: 25 })) } });
  const result = inspectOperationalPrewarm({ database, env, close: () => {} }, now);
  expect(result.missingSample).not.toContain(NATIONAL_DAILY_KEY);
});


it('설치 없는 전체 수집에서도 전국 항목을 갱신하고 대기질 관측소 목록은 하루 동안 공유한다', async () => {
  const env = nodeServerEnv(database, { KMA_APIHUB_KEY: 'synthetic', KMA_SERVICE_KEY: 'synthetic' });
  await saveCollectedSourceVersion(env.DB, 'KMA_MID_TERM_SUPPORTED_REGIONS', `DATA_GO_KR:${latestMidTermIssueTimes(now, 1)[0]}`, now);
  vi.spyOn(KmaGridObservationProvider.prototype, 'getSnapshot').mockImplementation(async clock => observationSnapshot(gridObservationKoreanIso(clock)));
  const forecast = vi.spyOn(nationalForecast, 'collectNationwideForecast').mockResolvedValue();
  const uv = vi.spyOn(KmaUvProvider.prototype, 'getNationwide').mockResolvedValue({ '4139054000': {
    areaNo: '4139054000', issuedAt: '2026-10-04T09:00:00+09:00', provider: 'KMA_LIVING_INDEX_V5', points: [{ forecastAt: now.toISOString(), uvIndex: 4 }],
  } });
  vi.spyOn(KmaWarningProvider.prototype, 'getRegionStations').mockResolvedValue([{ stationId: '108', stationName: '서울', regionId: 'L1100400', regionName: '서울서북권', latitude: 37.57, longitude: 126.96 }]);
  vi.spyOn(KmaWarningProvider.prototype, 'getActiveForRegions').mockResolvedValue([]);
  const catalog = vi.spyOn(AirKoreaAirQualityProvider.prototype, 'getStationCatalog').mockResolvedValue({ fetchedAt: now.toISOString(),
    stations: AIRKOREA_PROVINCES.map(stationName => ({ stationName, latitude: 37.57, longitude: 126.96 })) });
  const air = vi.spyOn(AirKoreaAirQualityProvider.prototype, 'getProvinceMeasurements').mockImplementation(async stationName => [{ stationName, observedAt: now.toISOString(), pm10: 20, pm25: 10, ozone: 0.02 }]);
  vi.spyOn(AirKoreaForecastProvider.prototype, 'getForecastsByAreas').mockResolvedValue(Object.fromEntries(AIRKOREA_FORECAST_AREAS.map(area => [area, [{ date: '20261004', pm10Grade: '좋음', pm25Grade: '좋음' }]])));
  vi.spyOn(KmaHourlyObservationProvider.prototype, 'getObservationsAt').mockImplementation(async clock => ({ observedAt: gridObservationKoreanIso(clock),
    stations: [{ observedAt: gridObservationKoreanIso(clock), stationId: '108', latitude: 37.57, longitude: 126.96, temperature: 20, visibilityMeters: 10000 }] }));
  const dates = Array.from({ length: 7 }, (_, i) => new Date(Date.UTC(2026, 8, 27 + i)).toISOString().slice(0, 10));
  vi.spyOn(KmaDailyObservationProvider.prototype, 'getNationwide').mockResolvedValue({ snowfallMetricAvailable: true, completedDates: dates,
    stations: dates.map(date => ({ date, stationId: '108', latitude: 37.57, longitude: 126.96, minTemperature: 15, maxTemperature: 25, snowfallAmount: 0 })) });
  await runWeatherCollectionJob(env, { now });
  await runWeatherCollectionJob(env, { now: new Date(now.getTime() + 4200000) });
  expect(forecast).toHaveBeenCalledTimes(2);
  expect(uv).toHaveBeenCalledOnce();
  expect(catalog).toHaveBeenCalledOnce();
  expect(air).toHaveBeenCalledTimes(AIRKOREA_PROVINCES.length * 2);
  expect(globalThis.fetch).not.toHaveBeenCalled();
  expect(database.sqlite.prepare("SELECT COUNT(*) AS n FROM weather_cache WHERE cache_type IN ('COLLECTED_REGION','COLLECTED_WEEKLY','COLLECTED_ENVIRONMENTAL','COLLECTED_VISIBILITY')").get()).toEqual({ n: 0 });
});
