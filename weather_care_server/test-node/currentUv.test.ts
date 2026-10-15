import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { SqliteD1Database, runSqliteMigrations, asD1Database } from '../src/node/sqliteD1';
import { KmaUvObservationProvider, parseUvObservationStations, parseUvObservations, uvObservationRequestTime } from '../src/providers/uv/kmaUvObservationProvider';
import { collectCurrentUv, currentUvFields, UV_STATIONS_KEY, UV_OBSERVATIONS_KEY } from '../src/services/currentUvCache';
import { saveCollectedCache } from '../src/database/collectedWeatherRepository';

const now = new Date('2026-10-15T05:10:30Z');
const wrapped = (rows: string[]) => '#START7777\n' + rows.join('\n') + '\n#7777END';
const stations = wrapped([
  '13 126.16000000 33.30000000 71.00 0 고산센터 ----',
  '108 126.96500000 37.57100000 85.50 108 서울 Seoul 11B10101',
  '132 126.33000000 36.54000000 47.00 132 안면도(감) ----',
]);
const observation = (id: number, index: number, time = '202610151410') =>
  `${time} ${id} 0.148 1.295 -999.0 ${index} 0.3 23.6 23.6`;

describe('Today 자외선 관측', () => {
  let directory: string, database: SqliteD1Database, db: D1Database;
  beforeEach(() => {
    vi.useFakeTimers(); vi.setSystemTime(now);
    directory = mkdtempSync(join(tmpdir(), 'weather-care-uv-'));
    database = new SqliteD1Database(join(directory, 'weather.sqlite'));
    runSqliteMigrations(database); db = asD1Database(database);
    vi.spyOn(console, 'log').mockImplementation(() => {});
    vi.spyOn(console, 'error').mockImplementation(() => {});
  });
  afterEach(() => {
    database.close(); rmSync(directory, { recursive: true, force: true });
    vi.restoreAllMocks(); vi.useRealTimers();
  });

  it('UV 지점별 이름·좌표를 보존하고 복사량이나 결측 EUV를 지수로 쓰지 않는다', () => {
    expect(uvObservationRequestTime(now)).toBe('202610151400');
    expect(uvObservationRequestTime(new Date('2026-10-15T00:00:30+09:00'))).toBe('202610142350');
    expect(parseUvObservationStations(stations).map(s => s.stationName)).toEqual(['고산센터', '서울', '안면도(감)']);
    expect(parseUvObservations(wrapped([observation(13, 2.1), observation(108, 0), observation(132, -999)]), now)
      .map(s => s.uvIndex)).toEqual([2.1, 0, undefined]);
  });

  it('불완전·중복·미래 자료를 관측으로 저장하지 않는다', () => {
    for (const text of ['<html>error</html>', wrapped([observation(108, 1), observation(108, 2)]),
      wrapped([observation(108, 1, '202610151420')]), wrapped([observation(108, 1, '202602301400')])]) {
      expect(() => parseUvObservations(text, now)).toThrow();
    }
    expect(() => parseUvObservationStations(stations.replace('126.96500000', '26.96500000'))).toThrow();
  });

  it('전국 1회씩 수집하고 중복 실행·재시작에도 관측은 10분, 지점정보는 한국 날짜마다 1회만 요청한다', async () => {
    const fetcher = vi.spyOn(globalThis, 'fetch').mockImplementation(async input => {
      const url = new URL(String(input));
      expect(url.searchParams.get('stn')).toBe('0');
      expect(url.searchParams.get('help')).toBe('0');
      if (url.pathname.endsWith('kma_sfctm_uv.php')) expect(url.searchParams.get('tm')).toMatch(/^\d{12}$/);
      return new Response(url.pathname.endsWith('stn_inf.php') ? stations : wrapped([observation(108, 0.4)]));
    });
    await Promise.all([collectCurrentUv(db, 'key', now), collectCurrentUv(db, 'key', now)]);
    expect(fetcher).toHaveBeenCalledTimes(2);
    await collectCurrentUv(db, 'key', new Date(now.getTime() + 60_000));
    expect(fetcher).toHaveBeenCalledTimes(2);
    await collectCurrentUv(db, 'key', new Date(now.getTime() + 600_000));
    expect(fetcher).toHaveBeenCalledTimes(3);
    const nextDay = new Date(now.getTime() + 86_400_000);
    vi.setSystemTime(nextDay);
    await collectCurrentUv(db, 'key', nextDay);
    expect(fetcher).toHaveBeenCalledTimes(5);
    expect(database.sqlite.prepare("SELECT request_count FROM api_usage_daily WHERE provider='UV_STATIONS' AND usage_date='2026-10-15'").get())
      .toMatchObject({ request_count: 1 });
  });

  it('가장 가까운 유효 관측소를 실제 GPS로 선택하고 0·거리·시각을 전달한다', async () => {
    await saveCollectedCache(db, { key: UV_STATIONS_KEY, type: UV_STATIONS_KEY,
      value: parseUvObservationStations(stations), updatedAt: now });
    await saveCollectedCache(db, { key: UV_OBSERVATIONS_KEY, type: UV_OBSERVATIONS_KEY,
      value: parseUvObservations(wrapped([observation(13, 0), observation(108, 0.4), observation(132, -999)]), now), updatedAt: now });
    const fields = await currentUvFields(db, { nx: 58, ny: 125, coordinates: { latitude: 33.3, longitude: 126.16 } }, now);
    expect(fields).toMatchObject({ uvStatus: 'AVAILABLE', uvIndex: 0, uvStationId: '13',
      uvStationName: '고산센터', uvStationDistanceKm: 0, uvObservedAt: '2026-10-15T14:10:00+09:00' });
    expect((await currentUvFields(db, { nx: 58, ny: 125 }, now)).uvStationId).toBe('108');
    expect(await currentUvFields(db, { nx: 58, ny: 125 }, new Date(now.getTime() + 31 * 60_000)))
      .toEqual({ uvStatus: 'UNAVAILABLE', uvProvider: 'KMA_APIHUB_UV', uvIndex: undefined });
  });

  it('실제 EUC-KR 이름을 읽으며 권한 오류는 반복 호출하지 않는다', async () => {
    const body = new Uint8Array([...new TextEncoder().encode('#START7777\n108 127 37 85 0 '), 0xb0, 0xa1,
      ...new TextEncoder().encode(' ----\n#7777END')]);
    expect((await new KmaUvObservationProvider('key', async () => new Response(body)).getStations())[0].stationName).toBe('가');
    const fetcher = vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response('', { status: 403 }));
    await collectCurrentUv(db, 'key', now);
    await collectCurrentUv(db, 'key', new Date(now.getTime() + 600_000));
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it('새 회차에 아직 게시되지 않은 지점의 직전 유효 관측을 30분까지만 보존한다', async () => {
    vi.spyOn(globalThis, 'fetch').mockImplementation(async input =>
      new Response(String(input).includes('stn_inf.php') ? stations : wrapped([observation(13, 2)])));
    await saveCollectedCache(db, { key: UV_OBSERVATIONS_KEY, type: UV_OBSERVATIONS_KEY,
      value: [{ stationId: '108', observedAt: '2026-10-15T14:00:00+09:00', uvIndex: 0.4 }], updatedAt: now });
    await collectCurrentUv(db, 'key', now);
    expect((await currentUvFields(db, { nx: 58, ny: 125 }, now)).uvStationId).toBe('108');
    expect((await currentUvFields(db, { nx: 58, ny: 125 }, new Date('2026-10-15T14:31:00+09:00'))).uvStationId).toBe('13');
  });
});
