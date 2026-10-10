import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { gunzipSync } from 'fflate';
import { SqliteD1Database, runSqliteMigrations, asD1Database } from '../src/node/sqliteD1';
import { readNationwideForecast, saveNationwideForecastField } from '../src/database/nationwideForecastRepository';
import { NATIONAL_FORECAST_VARIABLES, KmaNationwideForecastProvider, nationwideForecastPlan } from '../src/providers/weather/kmaNationwideForecastProvider';
import { providerErrorDiagnostic } from '../src/observability/providerErrorDiagnostics';
import { saveCollectedCache } from '../src/database/collectedWeatherRepository';
import { NATIONAL_UV_KEY, readNationwideRegion } from '../src/services/nationwideWeatherCache';
import { administrativeAreaForLocation } from '../src/regions/nationwideLocation';
import { KMA_ADMINISTRATIVE_AREAS } from '../src/regions/kmaAdministrativeAreas';
import weatherRouter from '../src/api/weather';
import { saveGridObservationSnapshot } from '../src/database/gridObservationRepository';
import { observationSnapshot } from './gridObservationFixture';
import { collectNationwideForecast } from '../src/services/nationwideForecastCache';
import { apiHubBudgetedFetch } from '../src/services/apiHubFetch';
import { getApiHubUsage, reserveApiHubBudget } from '../src/database/apiUsageRepository';
import { KmaGridObservationProvider } from '../src/providers/weather/kmaGridObservationProvider';

let database: SqliteD1Database;
const now = new Date('2026-10-04T09:15:00+09:00');
beforeEach(() => { database = new SqliteD1Database(':memory:'); runSqliteMigrations(database); vi.spyOn(console, 'log').mockImplementation(() => {}); });
afterEach(() => { vi.useRealTimers(); vi.restoreAllMocks(); database.close(); });

async function seedHour(valid = '2026100409', issue = '2026100408') {
  const db = asD1Database(database);
  for (const variable of NATIONAL_FORECAST_VARIABLES) {
    const values = Array.from({ length: 37_697 }, (_, i) => variable === 'TMP' ? (i % 700) / 10 - 20 :
      variable === 'REH' ? 60 : variable === 'WSD' ? 2 : variable === 'SKY' ? 1 : variable === 'VEC' ? 180 : 0);
    await saveNationwideForecastField(db, { issue, valid, variable }, { width: 149, height: 253, values }, now);
  }
}
describe('전국 GPS 데이터 계약', () => {
  it('전체 37,697개 셀을 무손실 저장하고 첫·끝·대표 목록 밖 격자에서 정확한 값을 읽는다', async () => {
    await seedHour();
    const row = database.sqlite.prepare("SELECT payload FROM nationwide_forecast_fields WHERE variable='TMP'").get() as { payload: string };
    const raw = JSON.parse(row.payload);
    const values = raw.blocks.flatMap((block: string) => {
      const bytes = gunzipSync(Uint8Array.from(atob(block), (s) => s.charCodeAt(0)));
      const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.length);
      return Array.from({ length: bytes.length / 8 }, (_, i) => view.getFloat64(i * 8, true));
    });
    expect(values).toEqual(Array.from({ length: 37_697 }, (_, i) => (i % 700) / 10 - 20));
    for (const [nx, ny] of [[1, 1], [149, 253], [140, 180], [63, 124]]) {
      const forecast = await readNationwideForecast(asD1Database(database), nx, ny, now);
      expect(forecast?.current.temperature).toBe(values[(ny - 1) * 149 + nx - 1]);
      expect(forecast?.current.fetchedAt).toBe(now.toISOString());
    }
  });

  it('지역 캐시가 없어도 메인 API가 전국 실황을 반환한다', async () => {
    vi.useFakeTimers(); vi.setSystemTime(now);
    const snapshot = observationSnapshot('2026-10-04T09:00:00+09:00', 23.8);
    await saveGridObservationSnapshot(asD1Database(database), snapshot, now);
    const fetcher = vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('NO_EXTERNAL_REQUEST'));
    const response = await weatherRouter.request('/main?nx=149&ny=253', {}, { DB: asD1Database(database) });
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ current: { temperature: 23.8 } });
    expect(fetcher).not.toHaveBeenCalled();
    expect(database.sqlite.prepare("SELECT COUNT(*) AS n FROM weather_cache WHERE cache_type='COLLECTED_REGION'").get()).toEqual({ n: 0 });
  });

  it('여행지 71/130 격자는 대표 캐시 없이 메인·오늘·주간 응답을 제공한다', async () => {
    vi.useFakeTimers(); vi.setSystemTime(now);
    await seedHour();
    await saveGridObservationSnapshot(asD1Database(database), observationSnapshot('2026-10-04T09:00:00+09:00', 23.8), now);
    const fetcher = vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('NO_EXTERNAL_REQUEST'));
    for (const route of ['main', 'today', 'weekly']) {
      const response = await weatherRouter.request(`/${route}?nx=71&ny=130&latitude=37.697249&longitude=127.660949`, {}, { DB: asD1Database(database) });
      expect(response.status).toBe(200);
      const data = await response.json() as Record<string, unknown>;
      expect(data.error).toBeUndefined();
      if (route !== 'weekly') expect(data.current).toMatchObject({ temperature: 23.8 });
    }
    expect(fetcher).not.toHaveBeenCalled();
    expect(database.sqlite.prepare("SELECT COUNT(*) AS n FROM weather_cache WHERE cache_type='COLLECTED_REGION'").get()).toEqual({ n: 0 });
  });

  it('GPS 지역명으로 자외선을 연결하며 알림도 같은 좌표의 확인된 지역명을 재사용한다', async () => {
    await seedHour();
    const db = asD1Database(database);
    const location = { nx: 57, ny: 124, regionName: '시흥시 은행동', coordinates: { latitude: 37.434, longitude: 126.803 } };
    const area = administrativeAreaForLocation(location)!;
    expect(area[1]).toContain('시흥시 은행동');
    expect(administrativeAreaForLocation({ nx: 60, ny: 121, regionName: '경기도 수원시' })?.[0]).toBe('4111000000');
    expect(administrativeAreaForLocation({ nx: 52, ny: 125, regionName: '인천광역시 영종구 운서2동' })?.[0]).toBe('2815500000');
    await saveCollectedCache(db, { key: NATIONAL_UV_KEY, type: 'COLLECTED_NATIONWIDE_UV', value: { forecasts: {
      [area[0]]: { areaNo: area[0], issuedAt: '2026-10-04T09:00:00+09:00', points: [{ forecastAt: now.toISOString(), uvIndex: 4 }], provider: 'KMA_LIVING_INDEX_V5' },
    } }, updatedAt: now });
    const first = await readNationwideRegion(db, location, now);
    const again = await readNationwideRegion(db, { nx: 57, ny: 124, coordinates: location.coordinates }, now);
    expect(first?.value.environmental.uv?.areaNo).toBe(area[0]);
    expect(again?.value.environmental.uv?.areaNo).toBe(area[0]);
    expect(administrativeAreaForLocation({ ...location, regionName: '시흥시 목록에없는동' })?.[1]).toBe('경기도 시흥시');
    expect(administrativeAreaForLocation({ nx: 57, ny: 124, regionName: '서울 구로구 항동' })?.[0]).toBe('1153080000');
  });

  it('부분 발표의 변수를 다른 발표와 섞지 않고 이전 완성 묶음을 유지한다', async () => {
    await seedHour('2026100412', '2026100408');
    await saveNationwideForecastField(asD1Database(database), { issue: '2026100411', valid: '2026100412', variable: 'TMP' },
      { width: 149, height: 253, values: Array(37_697).fill(50) }, now);
    const result = await readNationwideForecast(asD1Database(database), 1, 1, new Date('2026-10-04T12:15:00+09:00'));
    expect(result?.current.temperature).toBe(-20);
    expect(result?.current.issuedAt).toBe('2026-10-04T08:00:00+09:00');
  });

  it('풍향 파일이 없으면 같은 발표의 다른 예보를 유지하며 이전 발표 풍향을 섞지 않는다', async () => {
    await seedHour('2026100412', '2026100408');
    await seedHour('2026100412', '2026100411');
    database.sqlite.prepare("DELETE FROM nationwide_forecast_fields WHERE issue_time='2026100411' AND variable='VEC'").run();
    const result = await readNationwideForecast(asD1Database(database), 1, 1, new Date('2026-10-04T12:15:00+09:00'));
    expect(result?.current.temperature).toBe(-20);
    expect(result?.current.humidity).toBe(60);
    expect(result?.current.windSpeed).toBe(2);
    expect(result?.current.windDirection).toBeUndefined();
    expect(result?.current.issuedAt).toBe('2026-10-04T11:00:00+09:00');
    expect(result?.current.qualityFlags).toContain('WIND_DIRECTION_UNAVAILABLE');
  });

  it('풍향이 아니라 필수 풍속 파일이 없으면 이전 발표의 묶음을 유지한다', async () => {
    await seedHour('2026100412', '2026100408');
    await seedHour('2026100412', '2026100411');
    database.sqlite.prepare("DELETE FROM nationwide_forecast_fields WHERE issue_time='2026100411' AND variable='WSD'").run();
    const result = await readNationwideForecast(asD1Database(database), 1, 1, new Date('2026-10-04T12:15:00+09:00'));
    expect(result?.current.issuedAt).toBe('2026-10-04T08:00:00+09:00');
    expect(result?.current.windDirection).toBe(180);
  });

  it('HTTP200 빈 예보 응답은 사용 가능한 자료 없음으로 분류한다', async () => {
    const provider = new KmaNationwideForecastProvider('synthetic', async () => new Response(null));
    try {
      await provider.getField({ issue: '2026100408', valid: '2026100412', variable: 'VEC' });
      throw new Error('EXPECTED_PROVIDER_FAILURE');
    } catch (error) {
      expect(providerErrorDiagnostic(error).failureReason).toBe('NO_USABLE_DATA');
    }
  });

  it('겨울 먼 예보는 하루 한 번, 가까운 24시간은 최신 발표를 쓰고 연장일 비발표 시각을 요청하지 않는다', () => {
    const a = nationwideForecastPlan(new Date('2026-12-04T08:30:00+09:00'));
    const b = nationwideForecastPlan(new Date('2026-12-04T11:30:00+09:00'));
    expect(new Set(a.filter((r) => r.variable === 'TMP').map((r) => r.issue))).toEqual(new Set(['2026120408', '2026120317']));
    expect(new Set(b.filter((r) => r.variable === 'TMP').map((r) => r.issue))).toEqual(new Set(['2026120411', '2026120317']));
    expect(a.some((r) => r.issue === '2026120317' && r.valid === '2026120701')).toBe(false);
    expect(a.some((r) => r.issue === '2026120317' && r.valid === '2026120703')).toBe(true);
  });

  it.each([
    ['2026-10-09T05:30:00+09:00', '2026100905', '2026101200', '2026101203', '2026101300'],
    ['2026-10-09T17:30:00+09:00', '2026100917', '2026101300', '2026101303', '2026101400'],
    ['2026-12-04T08:30:00+09:00', '2026120317', '2026120700', '2026120703', '2026120800'],
  ])('05·17시 연장 풍향만 제외하고 정상 풍향과 연장 필수8항목을 보존한다: %s', (at, issue, boundary, first, last) => {
    const plan = nationwideForecastPlan(new Date(at)).filter((r) => r.issue === issue);
    expect(plan.some((r) => r.variable === 'VEC' && r.valid === boundary)).toBe(true);
    expect(plan.some((r) => r.variable === 'VEC' && r.valid >= first)).toBe(false);
    const slots = [...new Set(plan.filter((r) => r.variable === 'TMP' && r.valid >= first).map((r) => r.valid))];
    expect(slots).toHaveLength(8);
    expect(slots[0]).toBe(first);
    expect(slots[7]).toBe(last);
    for (const valid of slots) {
      expect(new Set(plan.filter((r) => r.valid === valid && NATIONAL_FORECAST_VARIABLES.includes(r.variable as typeof NATIONAL_FORECAST_VARIABLES[number])).map((r) => r.variable)))
        .toEqual(new Set(['TMP', 'REH', 'WSD', 'SKY', 'PTY', 'POP', 'PCP', 'SNO']));
    }
  });

  it('연장일의 풍속·강수·적설 코드를 수치로 계산하지 않는다', async () => {
    await seedHour('2026100803', '2026100417');
    const result = await readNationwideForecast(asD1Database(database), 1, 1, new Date('2026-10-04T18:30:00+09:00'));
    expect(result?.current.windSpeed).toBeUndefined();
    expect(result?.current.precipitationAmountRange).toBeUndefined();
    expect(result?.current.rawValue).toMatchObject({ windQualitative: '2', precipitationQualitative: '0' });
  });
});

describe('APIHub 실제 응답량 정산과 한도', () => {
  it('응답 바이트만 정산하고 같은 회차의 추가 호출은 공통 재시도 예산으로 기록한다', async () => {
    const db = asD1Database(database);
    const fetcher = vi.fn<typeof fetch>(async () => new Response('weather'));
    const wrapped = apiHubBudgetedFetch({ db, provider: 'FIXTURE', now, maxBytes: 1_000_000, fetcher });
    await wrapped('https://apihub.kma.go.kr/fixture?authKey=synthetic');
    await wrapped('https://apihub.kma.go.kr/fixture?authKey=synthetic');
    expect(await getApiHubUsage(db, now)).toEqual({ requestCount: 2, responseBytes: 14 });
    expect(database.sqlite.prepare("SELECT SUM(response_bytes) AS bytes FROM api_usage_daily WHERE provider GLOB 'APIHUB_RETRY*'").get()).toEqual({ bytes: 7 });
  });

  it('한도가 소진되면 실제 HTTP 요청을 보내지 않는다', async () => {
    const db = asD1Database(database);
    await reserveApiHubBudget(db, 'ESSENTIAL', 1, 4_500_000_000, now);
    const fetcher = vi.fn<typeof fetch>();
    await expect(apiHubBudgetedFetch({ db, provider: 'FIXTURE', now, maxBytes: 1000, fetcher })('https://apihub.kma.go.kr/fixture')).rejects.toThrow('BUDGET_EXHAUSTED');
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('초기 재시도는 100MB, 정상 운영 재시도는 400MB 상한을 적용한다', async () => {
    const db = asD1Database(database);
    await reserveApiHubBudget(db, 'APIHUB_RETRY', 1, 100_000_000, now);
    const fetcher = vi.fn<typeof fetch>(async () => new Response('ok'));
    const wrapped = apiHubBudgetedFetch({ db, provider: 'FIXTURE', now, maxBytes: 1000, retry: true, fetcher });
    await expect(wrapped('https://apihub.kma.go.kr/fixture')).rejects.toThrow('BUDGET_EXHAUSTED');
    await saveCollectedCache(db, { key: 'NATIONAL_BOOTSTRAP', type: 'NATIONAL_BOOTSTRAP', value: {}, updatedAt: new Date(now.getTime() - 25 * 3_600_000) });
    await wrapped('https://apihub.kma.go.kr/fixture');
    expect(fetcher).toHaveBeenCalledOnce();
  });

  it('기온 첫 파일이 504이면 나머지 5개 실황 요청과 예약은 발생하지 않는다', async () => {
    const db = asD1Database(database);
    const fetcher = vi.fn<typeof fetch>(async () => new Response('Gateway timeout', { status: 504 }));
    const provider = new KmaGridObservationProvider({ serviceKey: 'synthetic', fetcher: apiHubBudgetedFetch({ db, provider: 'GRID', now, maxBytes: 1_000_000, fetcher }) });
    await expect(provider.getSnapshot(new Date('2026-10-04T09:00:00Z'))).rejects.toThrow('504');
    expect(fetcher).toHaveBeenCalledOnce();
    expect(await getApiHubUsage(db, now)).toEqual({ requestCount: 1, responseBytes: 15 });
  });
});


it('응답 상한을 초과한 경우 이미 수신한 바이트까지 기록하고 게시하지 않는다', async () => {
  const db = asD1Database(database);
  const fetcher = vi.fn<typeof fetch>().mockResolvedValue(new Response('1234567890123'));
  await expect(apiHubBudgetedFetch({ db, provider: 'NATIONAL_TEST', now, maxBytes: 10, fetcher })
    ('https://apihub.kma.go.kr/example?authKey=synthetic')).rejects.toThrow('APIHUB_RESPONSE_EXCEEDS_RESERVED_BYTES');
  expect(await getApiHubUsage(db, now)).toEqual({ requestCount: 1, responseBytes: 13 });
});

it('같은 원본은 수집 작업명이 달라도 두 번째 실제 호출부터 공통 재시도로 집계한다', async () => {
  const db = asD1Database(database);
  const fetcher = vi.fn<typeof fetch>().mockImplementation(async () => new Response('123'));
  const url = 'https://apihub.kma.go.kr/example?authKey=synthetic';
  await apiHubBudgetedFetch({ db, provider: 'GRID_OBSERVATION_FAST_RETRY', now, maxBytes: 100, fetcher, sourceVersion: 'same' })(url);
  await apiHubBudgetedFetch({ db, provider: 'GRID_OBSERVATION_10_MINUTES', now, maxBytes: 100, fetcher, sourceVersion: 'same' })(url);
  expect(database.sqlite.prepare("SELECT SUM(request_count) AS n,SUM(response_bytes) AS bytes FROM api_usage_daily WHERE provider GLOB 'APIHUB_RETRY*'").get())
    .toEqual({ n: 1, bytes: 3 });
  expect(database.sqlite.prepare("SELECT request_count AS n FROM api_usage_daily WHERE provider='GRID_OBSERVATION_FAST_RETRY'").get()).toEqual({ n: 1 });
});


it.each([403, 429])('전국 예보 인증·호출 제한 %s는 동시 요청 4개 이후 배치를 중단한다', async status => {
  const fetcher = vi.spyOn(globalThis, 'fetch').mockImplementation(async () => new Response('denied', { status }));
  vi.spyOn(console, 'error').mockImplementation(() => {});
  await collectNationwideForecast(asD1Database(database), 'synthetic', now);
  expect(fetcher.mock.calls.length).toBeGreaterThan(0);
  expect(fetcher.mock.calls.length).toBeLessThanOrEqual(4);
  expect(database.sqlite.prepare('SELECT COUNT(*) AS n FROM nationwide_forecast_fields').get()).toEqual({ n: 0 });
});

it('손상된 최신 예보 블록은 이전의 완성된 원본으로 복구해 읽는다', async () => {
  vi.spyOn(console, 'error').mockImplementation(() => {});
  await seedHour('2026100412', '2026100408');
  await seedHour('2026100412', '2026100411');
  database.sqlite.prepare("UPDATE nationwide_forecast_fields SET payload='broken-json' WHERE issue_time='2026100411' AND variable='TMP'").run();
  const result = await readNationwideForecast(asD1Database(database), 1, 1, new Date('2026-10-04T12:15:00+09:00'));
  expect(result?.current.temperature).toBe(-20);
  expect(result?.baseTime).toBe('0800');
});

it('발표 시각을 고정해도 실제 호출 날짜가 바뀌면 새 KST 날짜의 사용량을 기록한다', async () => {
  const db = asD1Database(database);
  const next = new Date('2026-10-05T00:01:00+09:00');
  await apiHubBudgetedFetch({ db, provider: 'NATIONAL_TEST', now, maxBytes: 100, clock: () => next,
    fetcher: async () => new Response('123') })('https://apihub.kma.go.kr/example');
  expect(await getApiHubUsage(db, now)).toEqual({ requestCount: 0, responseBytes: 0 });
  expect(await getApiHubUsage(db, next)).toEqual({ requestCount: 1, responseBytes: 3 });
});

it('공식 지역명 전부와 세종·구 지역명·법정동 입력을 확인된 공식 구역으로 연결한다', () => {
  for (const [code, regionName, nx, ny] of KMA_ADMINISTRATIVE_AREAS) {
    expect(administrativeAreaForLocation({ nx, ny, regionName })?.[0], regionName).toBe(code);
  }
  expect(administrativeAreaForLocation({ nx: 65, ny: 103, regionName: '세종시 금남면' })?.[0]).toBe('3611034000');
  expect(administrativeAreaForLocation({ nx: 66, ny: 103, regionName: '세종시' })?.[0]).toBe('3600000000');
  expect(administrativeAreaForLocation({ nx: 59, ny: 75, regionName: '광주 북구' })?.[0]).toBe('1230000000');
  expect(administrativeAreaForLocation({ nx: 73, ny: 66, regionName: '전라남도 여수시' })?.[0]).toBe('1213000000');
  expect(administrativeAreaForLocation({ nx: 51, ny: 125, regionName: '인천 중구 운서동' })?.[0]).toBe('2815500000');
  expect(administrativeAreaForLocation({ nx: 61, ny: 126, regionName: '서울 강남구 역삼동' })?.[0]).toBe('1168000000');
  expect(administrativeAreaForLocation({ nx: 57, ny: 124 })).toBeUndefined();
});

it('최초 지역명 미확인은 제공처 지역 누락과 구분하고 이후 정상 이름을 같은 GPS에서 재사용한다', async () => {
  vi.spyOn(console, 'warn').mockImplementation(() => {});
  await seedHour();
  const db = asD1Database(database);
  const coordinates = { latitude: 37.434, longitude: 126.803 };
  await saveCollectedCache(db, { key: NATIONAL_UV_KEY, type: 'COLLECTED_NATIONWIDE_UV',
    value: { forecasts: {} }, updatedAt: now });
  const missing = await readNationwideRegion(db, { nx: 57, ny: 124, coordinates }, now);
  expect(missing?.value.environmental.sources.uv.reason).toBe('LOCATION_UNRESOLVED');
  const named = await readNationwideRegion(db, { nx: 57, ny: 124, coordinates, regionName: '시흥시 은행동' }, now);
  expect(named?.value.environmental.sources.uv.reason).toBe('UPSTREAM_AREA_MISSING');
  await saveCollectedCache(db, { key: NATIONAL_UV_KEY, type: 'COLLECTED_NATIONWIDE_UV', value: { forecasts: {
    '4139054000': { areaNo: '4139054000', issuedAt: now.toISOString(), points: [{ forecastAt: now.toISOString(), uvIndex: 4 }] },
  } }, updatedAt: now });
  const recovered = await readNationwideRegion(db, { nx: 57, ny: 124, coordinates, regionName: '확인안되는지역' }, now);
  expect(recovered?.value.environmental.uv?.areaNo).toBe('4139054000');
});

it('APIHub 연결 실패 로그는 단계·회차·허용 오류코드만 기록하고 키·URL·원문을 제외한다', async () => {
  const log = vi.spyOn(console, 'error').mockImplementation(() => {});
  const db = asD1Database(database);
  const error = new TypeError('DO_NOT_LOG_RAW_URL_OR_KEY', { cause: { code: 'UND_ERR_CONNECT_TIMEOUT' } });
  const wrapped = apiHubBudgetedFetch({ db, provider: 'ASOS_VISIBILITY', now, maxBytes: 512000,
    sourceVersion: '2026-10-04T08:00:00+09:00', fetcher: async () => { throw error; } });
  await expect(wrapped('https://apihub.kma.go.kr/example?obs=VS&authKey=DO_NOT_LOG_KEY')).rejects.toBe(error);
  expect(JSON.parse(String(log.mock.calls[0][0]))).toMatchObject({ event: 'apihub_request_failed',
    metric: 'VS', phase: 'RESPONSE_HEADERS', receivedBytes: 0, reservedBytes: 512000,
    failureReason: 'TIMEOUT', networkCode: 'UND_ERR_CONNECT_TIMEOUT' });
  expect(JSON.stringify(log.mock.calls)).not.toContain('DO_NOT_LOG');
  expect(JSON.stringify(log.mock.calls)).not.toContain('https://');
  expect(await getApiHubUsage(db, now)).toEqual({ requestCount: 1, responseBytes: 512000 });
});
