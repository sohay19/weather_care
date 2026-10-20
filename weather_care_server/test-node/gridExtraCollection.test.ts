import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { collectGridHourly, collectGridLightning, collectGridRiverFlow, parseLightningText,
  type GridExtraConfig } from '../src/collection/gridExtraCollection';
import { getApiHubUsage } from '../src/database/apiUsageRepository';
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
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ links: [], content: [
      { wlobscd: '1001602', ymdhm: '202610141250', wl: '1.39', fw: '  ' },
      { wlobscd: '1001603', ymdhm: '202610141250', wl: '0.19', fw: '0.12' },
    ] }), { status: 200 }));
    const now = new Date('2026-10-14T04:19:00Z');
    const db = asD1Database(sqlite);
    await collectGridRiverFlow({ db, key: 'test-key', now, fetcher: fetcher as typeof fetch });
    await collectGridRiverFlow({ db, key: 'test-key', now, fetcher: fetcher as typeof fetch });

    expect(fetcher).toHaveBeenCalledTimes(1);
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
