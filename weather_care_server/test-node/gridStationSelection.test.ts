import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { selectGridCollectionStations } from '../src/collection/gridStationSelection';
import type { GridExtraConfig } from '../src/collection/gridExtraCollection';
import { GRID_HOURLY_CRON, runScheduledJobs } from '../src/cron/jobs';
import { asD1Database, SqliteD1Database } from '../src/node/sqliteD1';
import type { ServerEnv } from '../src/types';

let sqlite: SqliteD1Database;
const emptyConfig: GridExtraConfig = {
  tideStations: [], buoyStations: [], forecastStations: [],
  ripCurrentBeaches: [], romsAreas: [], riverStations: [], dams: [],
};

beforeEach(() => {
  sqlite = new SqliteD1Database(':memory:');
  sqlite.sqlite.exec(`CREATE TABLE installations (
    installation_id TEXT PRIMARY KEY, nx INTEGER NOT NULL, ny INTEGER NOT NULL,
    latitude REAL, longitude REAL);
    CREATE TABLE api_usage_daily (
      usage_date TEXT NOT NULL, provider TEXT NOT NULL,
      request_count INTEGER NOT NULL DEFAULT 0,
      response_bytes INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL,
      PRIMARY KEY(usage_date,provider));
    CREATE TABLE grid_extra_snapshots (
      source TEXT NOT NULL, target_id TEXT NOT NULL, slot TEXT NOT NULL,
      payload TEXT NOT NULL, collected_at TEXT NOT NULL,
      PRIMARY KEY(source,target_id,slot));`);
});
afterEach(() => { sqlite.close(); vi.unstubAllGlobals(); });

function addInstallation(id: string, nx: number, ny: number,
  latitude: number | null, longitude: number | null): void {
  sqlite.sqlite.prepare(`INSERT INTO installations
    (installation_id,nx,ny,latitude,longitude) VALUES (?,?,?,?,?)`)
    .run(id, nx, ny, latitude, longitude);
}

describe('사용자 위치별 해양 관측소 자동 선택', () => {
  it('같은 해안의 사용자는 지점별로 한 번만 수집하고 위치 변경을 반영한다', async () => {
    addInstallation('a', 98, 76, 35.10, 129.04);
    addInstallation('b', 98, 76, 35.11, 129.05);
    const db = asD1Database(sqlite);
    const busan = await selectGridCollectionStations(db, emptyConfig);
    expect(busan.tideStations).toEqual(['DT_0005']);
    expect(busan.forecastStations).toEqual(['DT_0005']);
    expect(busan.buoyStations).toHaveLength(1);

    sqlite.sqlite.prepare(`UPDATE installations SET nx=60, ny=127,
      latitude=37.45, longitude=126.70`).run();
    const incheon = await selectGridCollectionStations(db, emptyConfig);
    expect(incheon.tideStations).not.toContain('DT_0005');
    expect(incheon.tideStations).toHaveLength(1);
  });

  it('GPS가 없는 수동 지역은 격자 중심을 쓰고 먼 내륙에는 해양 지점을 붙이지 않는다', async () => {
    addInstallation('busan-grid', 98, 76, null, null);
    const db = asD1Database(sqlite);
    expect((await selectGridCollectionStations(db, emptyConfig)).tideStations.length)
      .toBeGreaterThan(0);

    sqlite.sqlite.prepare(`UPDATE installations SET nx=67, ny=100,
      latitude=36.35, longitude=127.38`).run();
    const inland = await selectGridCollectionStations(db, emptyConfig);
    expect(inland.tideStations).toEqual([]);
    expect(inland.buoyStations).toEqual([]);
    expect(inland.forecastStations).toEqual([]);
  });

  it('최신 부이 관측 API가 받는 TW 지점만 자동 선택한다', async () => {
    addInstallation('near-hb', 98, 76, 35.182444, 129.23525);
    const result = await selectGridCollectionStations(asD1Database(sqlite), emptyConfig);
    expect(result.buoyStations).toHaveLength(1);
    expect(result.buoyStations[0]).toMatch(/^TW_/);
  });

  it('기존 운영 지점은 자동 선택 지점과 중복 없이 합친다', async () => {
    addInstallation('a', 98, 76, 35.10, 129.04);
    const result = await selectGridCollectionStations(asD1Database(sqlite), {
      ...emptyConfig, tideStations: ['DT_0005', 'DT_0018'],
    });
    expect(result.tideStations).toEqual(['DT_0005', 'DT_0018']);
  });

  it('매시 작업이 선택된 지점만 API에 요청한다', async () => {
    addInstallation('coast', 98, 76, 35.10, 129.04);
    addInstallation('inland', 67, 100, 36.35, 127.38);
    const fetcher = vi.fn(async () => new Response(JSON.stringify({ response: {
      header: { resultCode: '00' }, body: { totalCount: 1,
        items: { item: [{ obsrvnDt: '2026-10-14 10:00', lat: 35.1, lot: 129.04 }] } },
    } }), { status: 200 }));
    vi.stubGlobal('fetch', fetcher);
    await runScheduledJobs({ DB: asD1Database(sqlite),
      KHOA_SERVICE_KEY: 'test-key', KMA_SERVICE_KEY: '',
    } as ServerEnv, GRID_HOURLY_CRON, Date.parse('2026-10-14T01:06:00Z'));
    expect(fetcher).toHaveBeenCalledTimes(4);
    expect(fetcher.mock.calls.map(([url]) => url.searchParams.get('obsCode')))
      .toEqual(['DT_0005', expect.any(String), 'DT_0005', 'DT_0005']);
    expect(sqlite.sqlite.prepare(`SELECT COUNT(*) AS count FROM grid_extra_snapshots`)
      .get()).toEqual({ count: 4 });
  });
});
