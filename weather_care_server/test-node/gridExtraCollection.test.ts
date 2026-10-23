import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { collectGridHourly, collectGridLightning, collectGridRiverFlow, collectGridRiverHistory, parseLightningText,
  type GridExtraConfig } from '../src/collection/gridExtraCollection';
import { getApiHubUsage } from '../src/database/apiUsageRepository';
import { collectDailyRiverHistory } from '../src/collection/riverHistoryCollection';
import { asD1Database, SqliteD1Database } from '../src/node/sqliteD1';

let sqlite: SqliteD1Database;
const emptyConfig: GridExtraConfig = { tideStations: [], buoyStations: [],
  forecastStations: [], ripCurrentBeaches: [], romsAreas: [],
  riverStations: [], dams: [] };

beforeEach(() => {
  sqlite = new SqliteD1Database(':memory:');
  sqlite.sqlite.exec(`CREATE TABLE api_usage_daily (
    usage_date TEXT NOT NULL, provider TEXT NOT NULL, request_count INTEGER NOT NULL DEFAULT 0,
    response_bytes INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL,
    PRIMARY KEY(usage_date, provider));
    CREATE TABLE grid_extra_snapshots (
    source TEXT NOT NULL, target_id TEXT NOT NULL, slot TEXT NOT NULL,
    payload TEXT NOT NULL, collected_at TEXT NOT NULL,
    PRIMARY KEY(source,target_id,slot));
    CREATE TABLE lightning_collection_state (
      id INTEGER PRIMARY KEY,attempted_at TEXT NOT NULL,window_end TEXT NOT NULL,status TEXT NOT NULL);
    CREATE TABLE weather_cache (
    cache_key TEXT PRIMARY KEY, region_id TEXT NOT NULL, nx INTEGER NOT NULL,
    ny INTEGER NOT NULL, cache_type TEXT NOT NULL, payload TEXT NOT NULL,
    status TEXT NOT NULL, updated_at TEXT NOT NULL);`);
});
afterEach(() => sqlite.close());

describe('격자 부가자료 수집', () => {
  it('정기 하천 수집은 당일 이력을 재사용하고 한국 날짜가 바뀌면 새 자료를 받는다', async () => {
    const fetcher = vi.fn(async (url: URL) => {
      const history = url.pathname.includes('/1H/');
      const day = history ? url.pathname.split('/').at(-2)!.slice(0, 8) : '202610232310';
      return Response.json({ content: [{ wlobscd: '1001603',
        ymdhm: history ? `${day}01` : day, wl: '1', fw: '2' }] });
    });
    const input = { db: asD1Database(sqlite), key: 'test-key',
      now: new Date('2026-10-23T14:29:00Z'), fetcher: fetcher as typeof fetch };
    expect(await collectDailyRiverHistory(input)).toEqual({ targets: 1, succeeded: 1, failed: 0, budgetExhausted: false });
    await collectDailyRiverHistory({ ...input, now: new Date('2026-10-23T14:39:00Z') });
    expect(fetcher).toHaveBeenCalledTimes(3); // 제원·전국 최신·지점 이력, 재실행은 모두 재사용.
    await collectDailyRiverHistory({ ...input, now: new Date('2026-10-24T14:29:00Z') });
    expect(fetcher).toHaveBeenCalledTimes(6);
    const historyUrls = fetcher.mock.calls.map(([url]) => String(url)).filter(url => url.includes('/1H/'));
    expect(historyUrls[1]).toContain('/2026102400/2026102423.json');
  });

  it('정기 하천 이력 수집이 일일 요청 한도를 소진하면 추가 호출을 중지한다', async () => {
    sqlite.sqlite.prepare(`INSERT INTO api_usage_daily VALUES(?, 'HRFCO_RIVER_HISTORY', 1200, 0, ?)`)
      .run('2026-10-23', '2026-10-23T14:29:00Z');
    const fetcher = vi.fn(async () => Response.json({ content: [{ wlobscd: '1001603',
      obsnm: '관측소', ymdhm: '202610232310', wl: '1', fw: '2' }] }));
    const result = await collectDailyRiverHistory({ db: asD1Database(sqlite), key: 'test-key',
      now: new Date('2026-10-23T14:29:00Z'), fetcher: fetcher as typeof fetch });
    expect(result).toEqual({ targets: 1, succeeded: 0, failed: 0, budgetExhausted: true });
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it('K-water 이름 목록은 하루에 한 번 받고 댐의 축약 시각은 요청 날짜로 정규화한다', async () => {
    const fetcher = vi.fn(async (url: URL) => {
      const rows = url.pathname.endsWith('/wal/wallist')
        ? [{ walobsrvtcode: '9000266', obsrvtNm: '삼척시(갈밭교)' }]
        : url.pathname.endsWith('/damCodelist') ? [{ damcode: '1001210', damnm: '광동댐' }]
        : url.pathname.endsWith('/hourlist') ? [
            { obsrdt: '10-21 01시 ', lowlevel: 35.94 },
            { obsrdt: '10-20 23시 ', lowlevel: 99 },
            { obsrdt: '잘못된 시각', lowlevel: 100 },
          ] : [{ obsrdthour: '2026-10-21 01:00', flux: 1, hourwal: 0 }];
      return new Response(JSON.stringify({ response: { header: { resultCode: '00' },
        body: { totalCount: rows.length, items: { item: rows } } } }));
    });
    const input = { db: asD1Database(sqlite), config: { ...emptyConfig,
      riverStations: [{ damCode: '1001210', stationCode: '9000266' }] },
      now: new Date('2026-10-21T02:00:00Z'), kwaterKey: 'test-key', fetcher: fetcher as typeof fetch };
    await collectGridHourly(input);
    await collectGridHourly({ ...input, now: new Date('2026-10-21T03:00:00Z') });
    expect(fetcher.mock.calls.filter(([url]) => url.pathname.endsWith('/wal/wallist'))).toHaveLength(1);
    const read = (source: string) => JSON.parse((sqlite.sqlite.prepare(
      'SELECT payload FROM grid_extra_snapshots WHERE source=? ORDER BY slot DESC LIMIT 1')
      .get(source) as { payload: string }).payload);
    expect(read('KWATER_RIVER_STATIONS')).toEqual([{ stationCode: '9000266', name: '삼척시(갈밭교)' }]);
    expect(read('KWATER_DAM')).toEqual([{ observedAt: '2026-10-21T01:00:00+09:00',
      levelM: 35.94, inflowM3PerSec: null, dischargeM3PerSec: null }]);
    expect(read('KWATER_RIVER_LEVEL')[0].observedAt).toBe('2026-10-21 01:00');
    expect(read('KWATER_RIVER_LEVEL')[0]).toMatchObject({ levelM: 0, flowM3PerSec: 1, fieldMappingVersion: 2 });
    expect(read('KWATER_RIVER_LEVEL')[0]).not.toHaveProperty('rainfallMm');
  });
  it('하천 기간 자료는 오늘 0시부터 완료된 정각까지만 관측소별로 저장한다', async () => {
    const fetcher = vi.fn(async () => Response.json({ content: [
      { wlobscd: '1001603', ymdhm: '2026102100', wl: '0.93', fw: '7.21' },
      { wlobscd: '1001603', ymdhm: '202610210100', wl: '0.91', fw: '' },
      { wlobscd: '1001603', ymdhm: '2026102112', wl: '0.85', fw: '4.89' },
      { wlobscd: '1001603', ymdhm: '2026102112', wl: '999', fw: '999' },
      { wlobscd: '1001603', ymdhm: '2026102012', wl: '999', fw: '999' },
      { wlobscd: '1001603', ymdhm: '2026102113', wl: '999', fw: '999' },
      { wlobscd: '1001603', ymdhm: '202610210199', wl: '999', fw: '999' },
      { wlobscd: '1001604', ymdhm: '2026102102', wl: '999', fw: '999' },
    ] }));
    const input = { db: asD1Database(sqlite), key: 'test-key', stationCode: '1001603',
      now: new Date('2026-10-21T03:29:00Z'), fetcher: fetcher as typeof fetch };
    expect(await collectGridRiverHistory(input)).toBe(true);
    expect(await collectGridRiverHistory(input)).toBe(true);
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(String(fetcher.mock.calls[0][0])).toContain('/1H/1001603/2026102100/2026102112.json');
    const payload = JSON.parse((sqlite.sqlite.prepare("SELECT payload FROM grid_extra_snapshots WHERE target_id='1001603'")
      .get() as { payload: string }).payload);
    expect(payload.stations).toEqual([
      { stationCode: '1001603', observedAt: '202610210000', levelM: 0.93, flowM3PerSec: 7.21 },
      { stationCode: '1001603', observedAt: '202610210100', levelM: 0.91, flowM3PerSec: null },
      { stationCode: '1001603', observedAt: '202610211200', levelM: 0.85, flowM3PerSec: 4.89 },
    ]);
  });
  it('조위 관측의 모든 페이지를 저장하고 같은 시간의 재호출을 피한다', async () => {
    const fetcher = vi.fn(async (url: URL) => {
      const page = Number(url.searchParams.get('pageNo'));
      const rows = page === 1 ? [{ obsrvnDt: '2026-10-14 09:00', lot: 129.16,
        lat: 35.16, bscTdlvHgt: 78, wtem: 21.5, crsp: 0.4 },
      { obsrvnDt: '2026-10-14 10:00', lot: 129.16, lat: 35.16,
        bscTdlvHgt: 80 }] : [{ obsrvnDt: '2026-10-14 11:00',
        lot: 129.16, lat: 35.16, bscTdlvHgt: 81 }];
      return new Response(JSON.stringify({ response: { header: { resultCode: '00' },
        body: { totalCount: 3, items: { item: rows } } } }), { status: 200 });
    });
    const input = { db: asD1Database(sqlite), config: { ...emptyConfig,
      tideStations: ['DT_0018'] }, now: new Date('2026-10-14T02:06:00Z'),
    khoaKey: 'test-key', fetcher: fetcher as typeof fetch };
    await collectGridHourly(input);
    await collectGridHourly(input);
    expect(fetcher).toHaveBeenCalledTimes(2);
    const row = sqlite.sqlite.prepare(`SELECT payload FROM grid_extra_snapshots
      WHERE source='KHOA_TIDE_OBS'`).get() as { payload: string };
    const data = JSON.parse(row.payload) as Array<Record<string, unknown>>;
    expect(data).toHaveLength(3);
    expect(data[0]).toMatchObject({ tideCm: 78, waterTempC: 21.5,
      currentSpeedMs: 0.4, latitude: 35.16 });
    expect(sqlite.sqlite.prepare(`SELECT request_count AS count FROM api_usage_daily
      WHERE provider='DATA_GO_KHOA_TIDE_OBS'`).get()).toEqual({ count: 2 });
  });

  it('공공데이터포털의 일시적인 04 오류는 한 번 재시도한다', async () => {
    const fetcher = vi.fn(async () => new Response(fetcher.mock.calls.length === 1
      ? JSON.stringify({ OpenAPI_ServiceResponse: { cmmMsgHeader: {
        returnReasonCode: '04', errMsg: 'HTTP_ERROR',
      } } })
      : JSON.stringify({ response: { header: { resultCode: '00' },
        body: { totalCount: 1, items: { item: { obsrvnDt: '2026-10-14 10:00' } } },
      } }), { status: 200 }));
    await collectGridHourly({ db: asD1Database(sqlite),
      config: { ...emptyConfig, tideStations: ['DT_0018'] },
      now: new Date('2026-10-14T01:06:00Z'), khoaKey: 'test-key',
      fetcher: fetcher as typeof fetch });
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(sqlite.sqlite.prepare(`SELECT COUNT(*) AS count FROM grid_extra_snapshots
      WHERE source='KHOA_TIDE_OBS'`).get()).toEqual({ count: 1 });
  });

  it('K-water 댐 코드를 조회해 전국 댐 자료를 중복 없이 수집한다', async () => {
    const fetcher = vi.fn(async (url: URL) => {
      const codes = url.pathname.endsWith('/damCodelist');
      const rows = codes ? [{ damcode: '2022510', damnm: '예시댐' },
        { damcode: '2022511', damnm: '예시보' }] :
        [{ obsrdt: '2026-10-14 10:00', lowlevel: '20.5', inflowqy: '4.2' }];
      return new Response(JSON.stringify({ response: { header: { resultCode: '00' },
        body: { totalCount: rows.length, items: { item: rows } } } }), { status: 200 });
    });
    const input = { db: asD1Database(sqlite), config: emptyConfig,
      now: new Date('2026-10-14T01:06:00Z'), kwaterKey: 'test-key',
      fetcher: fetcher as typeof fetch };
    await collectGridHourly(input);
    await collectGridHourly(input);
    expect(fetcher.mock.calls.filter(([url]) => url.pathname.endsWith('/damCodelist')))
      .toHaveLength(1);
    expect(fetcher.mock.calls.filter(([url]) => url.pathname.endsWith('/hourlist')))
      .toHaveLength(2);
    expect(sqlite.sqlite.prepare(`SELECT COUNT(*) AS count FROM grid_extra_snapshots
      WHERE source='KWATER_DAM'`).get()).toEqual({ count: 2 });
  });

  it('낙뢰 자료는 좌표를 확인하고 지난 두 회차까지 중복 없이 보충한다', async () => {
    expect(parseLightningText('# header\n202610141000 127.1 37.1 -4 G 0\n'))
      .toMatchObject([{ longitude: 127.1, latitude: 37.1, type: 'G' }]);
    expect(parseLightningText('202610141000 127.1 37.1 -4\n'))
      .toMatchObject([{ longitude: 127.1, latitude: 37.1, intensity: -4,
        type: null, altitudeKm: null }]);
    expect(parseLightningText('202610141000 0 0 1 G 0')).toEqual([]);
    const fetcher = vi.fn(async () => new Response('202610141000 127.1 37.1 -4 G 0\n',
      { status: 200 }));
    const input = { db: asD1Database(sqlite), key: 'test-key',
      now: new Date('2026-10-14T01:05:00Z'), fetcher: fetcher as typeof fetch };
    await collectGridLightning(input);
    await collectGridLightning(input);
    expect(fetcher).toHaveBeenCalledTimes(3);
    expect(sqlite.sqlite.prepare(`SELECT COUNT(*) AS count FROM grid_extra_snapshots
      WHERE source='KMA_LIGHTNING'`).get()).toEqual({ count: 3 });
  });

  it('한강홍수통제소의 실제 응답 형식에서 유량이 있는 지점만 저장한다', async () => {
    const fetcher = vi.fn(async (url: URL) => new Response(JSON.stringify({ links: [], content: url.pathname.endsWith('info.json') ? [
      { wlobscd: '1001603', obsnm: '예시교 관측소' },
    ] : [
      { wlobscd: '1001602', ymdhm: '202610141250', wl: '1.39', fw: '  ' },
      { wlobscd: '1001603', ymdhm: '202610141250', wl: '0.19', fw: '0.12' },
    ] }), { status: 200 }));
    const now = new Date('2026-10-14T04:19:00Z');
    const db = asD1Database(sqlite);
    await collectGridRiverFlow({ db, key: 'test-key', now, fetcher: fetcher as typeof fetch });
    await collectGridRiverFlow({ db, key: 'test-key', now, fetcher: fetcher as typeof fetch });

    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(JSON.parse((sqlite.sqlite.prepare(`SELECT payload FROM grid_extra_snapshots
      WHERE source='HRFCO_STATIONS'`).get() as { payload: string }).payload))
      .toEqual([{ stationCode: '1001603', name: '예시교 관측소' }]);
    const row = sqlite.sqlite.prepare(`SELECT payload FROM grid_extra_snapshots
      WHERE source='HRFCO_RIVER_FLOW'`).get() as { payload: string };
    expect(JSON.parse(row.payload)).toEqual({ stations: [{
      stationCode: '1001603', observedAt: '202610141250', levelM: 0.19,
      flowM3PerSec: 0.12,
    }] });
    expect(await getApiHubUsage(db, now)).toEqual({ requestCount: 0, responseBytes: 0 });
  });

  it('수산과학원 목록의 body.item에서 새 상세 자료를 조회한다', async () => {
    const fetcher = vi.fn(async (url: URL) => {
      const id = url.searchParams.get('id');
      const body = id === 'jellyList' ? { item: [
        { board_idx: '123', gbn: '1', inpt_date: '2026-10-14' },
        { board_idx: '124', gbn: '0', inpt_date: '2026-10-14' },
      ] } : { item: [{ srcode: url.searchParams.get('srcode') }] };
      return new Response(JSON.stringify({ header: { resultCode: '00' }, body }),
        { status: 200 });
    });
    const db = asD1Database(sqlite);
    const input = { db, config: emptyConfig, now: new Date('2026-10-14T03:06:00Z'),
      nifsKey: 'test-key', fetcher: fetcher as typeof fetch };

    await collectGridHourly(input);
    await collectGridHourly(input);

    expect(fetcher).toHaveBeenCalledTimes(3);
    expect(fetcher.mock.calls.map(([url]) => url.searchParams.get('id')))
      .toEqual(['jellyList', 'jellyDetail', 'jellyDetail2']);
    expect(sqlite.sqlite.prepare(`SELECT COUNT(*) AS count FROM grid_extra_snapshots
      WHERE source='NIFS_JELLYFISH_DETAIL'`).get()).toEqual({ count: 2 });
  });
});
