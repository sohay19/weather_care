import { afterEach, beforeEach, expect, it } from 'vitest';
import gridExtraRoutes from '../src/api/gridExtra';
import { kmaGridFromCoordinates } from '../src/regions/kmaGridFromCoordinates';
import { asD1Database, SqliteD1Database } from '../src/node/sqliteD1';
import type { ServerEnv } from '../src/types';

let sqlite: SqliteD1Database;
let env: ServerEnv;

beforeEach(() => {
  sqlite = new SqliteD1Database(':memory:');
  sqlite.sqlite.exec(`CREATE TABLE grid_extra_snapshots (
    source TEXT NOT NULL,target_id TEXT NOT NULL,slot TEXT NOT NULL,
    payload TEXT NOT NULL,collected_at TEXT NOT NULL,
    PRIMARY KEY(source,target_id,slot));`);
  env = { DB: asD1Database(sqlite) } as ServerEnv;
});
afterEach(() => sqlite.close());

function save(source: string, target: string, slot: string, payload: unknown) {
  sqlite.sqlite.prepare(`INSERT INTO grid_extra_snapshots VALUES (?,?,?,?,?)`)
    .run(source, target, slot, JSON.stringify(payload), slot);
}

it('댐 이름으로 선택하고 선택한 댐의 시간별 값만 반환한다', async () => {
  save('KWATER_DAM_CODES', 'ALL', '2026-10-14', [
    { damcode: '2022510', damnm: '첫째댐' },
    { damcode: '2022511', damnm: '둘째댐' },
  ]);
  save('KWATER_DAM', '2022510', '2026-10-14T01:00:00Z', [
    { observedAt: '2026-10-14 10:00', levelM: 20.5, inflowM3PerSec: 4.2 },
  ]);
  save('KWATER_DAM', '2022511', '2026-10-14T01:00:00Z', [
    { observedAt: '2026-10-14 10:00', levelM: 9 },
  ]);
  const catalog = await gridExtraRoutes.request('/catalog?nx=60&ny=121', {}, env);
  const groups = (await catalog.json() as { groups: Array<{ source: string;
    targets: Array<{ id: string; name: string }> }> }).groups;
  expect(groups.find((group) => group.source === 'KWATER_DAM')?.targets)
    .toEqual(expect.arrayContaining([
      { id: '2022510', name: '첫째댐' }, { id: '2022511', name: '둘째댐' },
    ]));
  const response = await gridExtraRoutes.request(
    '/records?source=KWATER_DAM&targetId=2022510&nx=60&ny=121', {}, env);
  const data = await response.json() as { records: Array<{ values: Record<string, number> }> };
  expect(data.records).toHaveLength(1);
  expect(data.records[0].values).toEqual({ levelM: 20.5, inflowM3PerSec: 4.2 });
});

it('전국 하천 스냅샷은 고른 관측소만 보여준다', async () => {
  save('HRFCO_RIVER_FLOW', 'ALL', '2026-10-14T01:00:00Z', { stations: [
    { stationCode: '1001603', observedAt: '202610141000', levelM: 0.19,
      flowM3PerSec: 0.12 },
    { stationCode: '1001604', observedAt: '202610141000', levelM: 1,
      flowM3PerSec: 3 },
  ] });
  const response = await gridExtraRoutes.request(
    '/records?source=HRFCO_RIVER_FLOW&targetId=1001603&nx=60&ny=121', {}, env);
  const data = await response.json() as { records: Array<{ values: Record<string, number> }> };
  expect(data.records.map((record) => record.values.flowM3PerSec)).toEqual([0.12]);
});

it('낙뢰는 이벤트 좌표가 선택 격자에 속할 때만 시간별로 집계한다', async () => {
  const grid = kmaGridFromCoordinates(37.5, 127);
  save('KMA_LIGHTNING', 'ALL', '2026-10-14T01:00:00Z', { events: [
    { observedAt: '202610141000', latitude: 37.5, longitude: 127 },
    { observedAt: '202610141030', latitude: 37.5, longitude: 127 },
    { observedAt: '202610141000', latitude: 35, longitude: 129 },
  ] });
  const response = await gridExtraRoutes.request(
    `/records?source=KMA_LIGHTNING&targetId=${grid.nx}_${grid.ny}&nx=${grid.nx}&ny=${grid.ny}`,
    {}, env);
  const data = await response.json() as { records: Array<{ values: { count: number } }> };
  expect(data.records.map((record) => record.values.count)).toEqual([2]);
});

it('해양 모델값은 같은 5km 격자 안의 지점만 대표값으로 고른다', async () => {
  const grid = kmaGridFromCoordinates(37.5, 127);
  save('KHOA_ROMS', '서해', '2026-10-14', [
    { forecastAt: '2026-10-14 10:00', latitude: 37.5, longitude: 127,
      waterTempC: 20 },
    { forecastAt: '2026-10-14 10:00', latitude: 35, longitude: 129,
      waterTempC: 30 },
  ]);
  const response = await gridExtraRoutes.request(
    `/records?source=KHOA_ROMS&targetId=GRID&nx=${grid.nx}&ny=${grid.ny}`,
    {}, env);
  const data = await response.json() as { records: Array<{ values: { waterTempC: number } }> };
  expect(data.records.map((record) => record.values.waterTempC)).toEqual([20]);
});

it('부이·예측 해역 목록은 좌표와 거리 및 인근 관측소 이름을 제공한다', async () => {
  const grid = kmaGridFromCoordinates(35.05, 129);
  save('KHOA_BUOY_OBS', 'TW_0088', '2026-10-20', [
    { name: '감천항', latitude: 35.052805, longitude: 129.003083 },
  ]);
  save('KHOA_ROMS', 'BUOY_TW_0088', '20261020', [
    { latitude: 35.05, longitude: 129, waterTempC: 20 },
  ]);
  save('KHOA_BUOY_OBS', 'TW_0077', '2026-10-20', []);
  const response = await gridExtraRoutes.request(
    `/catalog?nx=${grid.nx}&ny=${grid.ny}&latitude=35.05&longitude=129`, {}, env);
  const data = await response.json() as any;
  const forecast = data.groups.find((g: any) => g.source === 'KHOA_ROMS').targets;
  expect(forecast.find((t: any) => t.id === 'BUOY_TW_0088')).toMatchObject({
    name: '감천항 인근 해역', latitude: 35.05, longitude: 129, distanceKm: 0, hasData: true,
  });
  const buoys = data.groups.find((g: any) => g.source === 'KHOA_BUOY_OBS').targets;
  expect(buoys.find((t: any) => t.id === 'TW_0088').distanceKm).toBeLessThan(1);
  expect(buoys.find((t: any) => t.id === 'TW_0077')).toMatchObject({ hasData: false,
    latitude: 37.523388, longitude: 126.592083 });
});

it('이름을 붙일 관측소가 먼 모델 지점은 관측소 이름 대신 좌표로 표시한다', async () => {
  save('KHOA_BUOY_OBS', 'TW_0088', '2026-10-20', [
    { name: '감천항', latitude: 35.05, longitude: 129 },
  ]);
  save('KHOA_ROMS', 'MODEL_1', '20261020', [{ latitude: 33, longitude: 124 }]);
  const response = await gridExtraRoutes.request('/catalog?nx=58&ny=125', {}, env);
  const data = await response.json() as any;
  const target = data.groups.find((g: any) => g.source === 'KHOA_ROMS').targets[1];
  expect(target.name).toBe('해양 예측 지점 (북위 33.00°, 동경 124.00°)');
  expect(Number.isFinite(target.distanceKm)).toBe(true);
});

it('현재 격자 밖 GPS나 잘못된 좌표는 격자 중심으로 거리를 계산한다', async () => {
  save('KHOA_BUOY_OBS', 'TW_0088', '2026-10-20', [
    { name: '감천항', latitude: 35.05, longitude: 129 },
  ]);
  const catalog = async (query: string) => {
    const response = await gridExtraRoutes.request(`/catalog?nx=58&ny=125${query}`, {}, env);
    return (await response.json() as any).groups.find((g: any) => g.source === 'KHOA_BUOY_OBS').targets[0];
  };
  expect(await catalog('&latitude=35.05&longitude=129')).toEqual(await catalog(''));
  expect(await catalog('&latitude=NaN&longitude=999')).toEqual(await catalog(''));
});

it('조위 통합 선택을 위해 관측·예측 양쪽에 거리와 자료 유무를 제공한다', async () => {
  save('KHOA_TIDE_OBS', 'DT_0001', '2026-10-20', []);
  save('KHOA_TIDE_HOURLY', 'DT_0001', '20261020', [
    { name: '인천', forecastAt: '2026-10-20 14:00', tideCm: 500 },
  ]);
  const response = await gridExtraRoutes.request('/catalog?nx=58&ny=125', {}, env);
  const data = await response.json() as any;
  const obs = data.groups.find((g: any) => g.source === 'KHOA_TIDE_OBS').targets[0];
  const forecast = data.groups.find((g: any) => g.source === 'KHOA_TIDE_HOURLY').targets[0];
  expect(obs.hasData).toBe(false);
  expect(forecast.hasData).toBe(true);
  expect(obs.distanceKm).toBeGreaterThan(0);
  expect(forecast.distanceKm).toBe(obs.distanceKm);
  expect(forecast.name).toBe('인천');
});
