import { afterEach, beforeEach, expect, it, vi } from 'vitest';
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
afterEach(() => { sqlite.close(); vi.restoreAllMocks(); });

function save(source: string, target: string, slot: string, payload: unknown) {
  sqlite.sqlite.prepare(`INSERT INTO grid_extra_snapshots VALUES (?,?,?,?,?)`)
    .run(source, target, slot, JSON.stringify(payload), slot);
}

it('하천 최신 관측과 지점별 오늘 이력을 합치고 지점·시각 중복을 제거한다', async () => {
  save('HRFCO_RIVER_FLOW', 'ALL', '2026-10-21T03:00:00Z', { stations: [
    { stationCode: '1001603', observedAt: '202610211220', levelM: 0.85, flowM3PerSec: 4.89 },
    { stationCode: '1001604', observedAt: '202610211220', levelM: 100 },
  ] });
  save('HRFCO_RIVER_FLOW', '1001603', '2026-10-21T03:00:00Z', { stations: [
    { stationCode: '1001603', observedAt: '202610210000', levelM: 0.93, flowM3PerSec: 7.21 },
    { stationCode: '1001603', observedAt: '202610211200', levelM: 0.85, flowM3PerSec: 4.89 },
    { stationCode: '1001603', observedAt: '202610211200', levelM: 999 },
  ] });
  const response = await gridExtraRoutes.request('/records?source=HRFCO_RIVER_FLOW&targetId=1001603&nx=58&ny=125', {}, env);
  const data = await response.json() as any;
  expect(data.records.map((r: any) => r.time)).toEqual([
    '2026-10-21T12:20:00+09:00', '2026-10-21T12:00:00+09:00', '2026-10-21T00:00:00+09:00',
  ]);
  expect(data.records.every((r: any) => r.values.levelM < 2)).toBe(true);
  const catalog = await gridExtraRoutes.request('/catalog?nx=58&ny=125', {}, env);
  const groups = (await catalog.json() as any).groups;
  expect(groups.find((g: any) => g.source === 'HRFCO_RIVER_FLOW').targets).toHaveLength(2);
});

it('선택한 구역 기준으로 하천·댐·조석 기준 관측소 거리를 제공한다', async () => {
  const grid = kmaGridFromCoordinates(37.5, 127);
  save('HRFCO_STATIONS', 'ALL', '2026-10-21', [
    { stationCode: '1001603', name: '기준 관측소', latitude: 37.5, longitude: 127 },
    { stationCode: '1001604', name: '위치 없는 관측소' },
  ]);
  save('KWATER_DAM_CODES', 'ALL', '2026-10-21', [{ damcode: '1003110', damnm: '충주' }]);
  save('KWATER_DAM', '1003110', '2026-10-21', []);
  save('KHOA_TIDE_EXTREME', 'DT_0001', '2026-10-21', []);
  const response = await gridExtraRoutes.request(`/catalog?nx=${grid.nx}&ny=${grid.ny}&latitude=37.5&longitude=127`, {}, env);
  const groups = (await response.json() as any).groups;
  const river = groups.find((g: any) => g.source === 'HRFCO_RIVER_FLOW').targets;
  expect(river.find((t: any) => t.id === '1001603').distanceKm).toBe(0);
  expect(river.find((t: any) => t.id === '1001604').distanceKm).toBeUndefined();
  expect(groups.find((g: any) => g.source === 'KWATER_DAM').targets[0].distanceKm).toBeGreaterThan(0);
  expect(groups.find((g: any) => g.source === 'KHOA_TIDE_EXTREME').targets[0].distanceKm).toBeGreaterThan(0);
});

it('좌표가 없는 하천은 코드와 이름이 확인된 공식 제원으로 보완하되 원래 좌표를 우선한다', async () => {
  save('HRFCO_STATIONS', 'ALL', '2026-10-21', [
    { stationCode: '1001613', name: '삼척시(광동교)' },
    { stationCode: '1007642', name: '다른 지점으로 바뀐 이름' },
    { stationCode: '5002630', name: '장성군(개천교)', latitude: 37.5, longitude: 127 },
    { stationCode: '8000001', name: '대아저수지' },
  ]);
  const grid = kmaGridFromCoordinates(37.5, 127);
  const response = await gridExtraRoutes.request(
    `/catalog?nx=${grid.nx}&ny=${grid.ny}&latitude=37.5&longitude=127`, {}, env);
  const river = (await response.json() as any).groups
    .find((g: any) => g.source === 'HRFCO_RIVER_FLOW').targets;
  expect(river.find((t: any) => t.id === '1001613')).toMatchObject({
    latitude: 37.35861111111111, longitude: 128.9488888888889, hasData: false,
  });
  expect(river.find((t: any) => t.id === '1001613').distanceKm).toBeGreaterThan(0);
  expect(river.find((t: any) => t.id === '1007642').distanceKm).toBeUndefined();
  expect(river.find((t: any) => t.id === '5002630').distanceKm).toBe(0);
  // 다른 지점에도 반복된 잘못된 제주 좌표는 사용하지 않는다.
  expect(river.find((t: any) => t.id === '8000001').distanceKm).toBeUndefined();
});

it('K-water 보완 위치를 하천 통합·기존 목록과 댐 자동선택 거리에 함께 제공한다', async () => {
  save('KWATER_RIVER_STATIONS', '1003110', '2026-10-21', [
    { stationCode: '9000181', name: '충주시(명서교)' },
  ]);
  save('KWATER_RIVER_LEVEL', '1003110:9000181', '2026-10-21', []);
  save('KWATER_DAM_CODES', 'ALL', '2026-10-21', [{ damcode: '2022510', damnm: '낙동강하굿둑' }]);
  save('KWATER_DAM', '2022510', '2026-10-21', []);
  const response = await gridExtraRoutes.request('/catalog?nx=98&ny=76', {}, env);
  const groups = (await response.json() as any).groups;
  const merged = groups.find((g: any) => g.source === 'HRFCO_RIVER_FLOW').targets[0];
  const legacy = groups.find((g: any) => g.source === 'KWATER_RIVER_LEVEL').targets[0];
  expect(merged).toMatchObject({ id: '9000181', latitude: 37.067378864, longitude: 128.032505104 });
  expect(legacy.distanceKm).toBe(merged.distanceKm);
  expect(Number.isFinite(legacy.distanceKm)).toBe(true);
  expect(groups.find((g: any) => g.source === 'KWATER_DAM').targets[0]).toMatchObject({
    id: '2022510', latitude: 35.10777777777778, longitude: 128.95055555555555,
  });
});

it('관측값이 비어 있는 BUOY 예측 대상도 연결된 부이 위치로 거리를 계산한다', async () => {
  for (const code of ['TW_0084', 'TW_0088', 'TW_0092']) {
    save('KHOA_ROMS', `BUOY_${code}`, '2026-10-21', []);
  }
  const response = await gridExtraRoutes.request('/catalog?nx=98&ny=76', {}, env);
  const targets = (await response.json() as any).groups
    .find((g: any) => g.source === 'KHOA_ROMS').targets.filter((t: any) => t.id !== 'GRID');
  expect(targets).toHaveLength(3);
  expect(targets.every((t: any) => Number.isFinite(t.distanceKm) && t.hasData === false)).toBe(true);
  expect(targets.find((t: any) => t.id === 'BUOY_TW_0088'))
    .toMatchObject({ latitude: 35.052805, longitude: 129.003083 });
});

it('재조사로 위치를 찾은 K-water 지점도 원래 코드를 유지한 채 가까운 자동선택 후보가 된다', async () => {
  const stations = [
    { stationCode: '9000195', name: '포항시(상사4교)', latitude: 36.25361111111111, longitude: 129.0886111111111 },
    { stationCode: '2021666', name: '청도군(당호리)', latitude: 35.67361111111111, longitude: 128.86694444444444 },
    { stationCode: '2021671', name: '청도군(임당리)', latitude: 35.70611111111111, longitude: 128.91666666666666 },
    { stationCode: '4104615', name: '순천시(주암조절지방수로)', latitude: 34.945277777777775, longitude: 127.42555555555556 },
    { stationCode: '8000122', name: '덕치', latitude: 35.49638888888889, longitude: 127.15 },
    { stationCode: '9000242', name: '두평', latitude: 36.53805555555555, longitude: 127.69416666666667 },
    { stationCode: '8000020', name: '주암조절지댐방수로', latitude: 34.945277777777775, longitude: 127.42555555555556 },
    { stationCode: '1005681', name: '강천보하류', latitude: 37.283888890123215, longitude: 127.68472220028876 },
    { stationCode: '1005691', name: '이포보하류', latitude: 37.408333329593674, longitude: 127.54138889950524 },
    { stationCode: '3001661', name: '동정교', latitude: 35.74995222990534, longitude: 127.5631420301808 },
    { stationCode: '3001664', name: '주고교', latitude: 35.82133340543839, longitude: 127.62396937507154 },
    { stationCode: '8000119', name: '충주보조수위', latitude: 37.00555555555555, longitude: 127.99194444444444 },
    { stationCode: '3001665', name: '진안군(주천교)', latitude: 35.970575000000004, longitude: 127.43061944444445 },
    { stationCode: '9000274', name: '진안군(하향교)', latitude: 35.82918611111111, longitude: 127.55282777777778 },
    { stationCode: '8000094', name: '청주시(대청댐보조수위)', latitude: 36.47841388888889, longitude: 127.48053055555556 },
    { stationCode: '9000259', name: '부사방조제 외수위', latitude: 36.18416666666666, longitude: 126.52 },
    { stationCode: '8000099', name: '구포(부산)', latitude: 35.203611111111115, longitude: 128.9933333333333 },
    { stationCode: '8000100', name: '삼랑진(부산)', latitude: 35.382777777777775, longitude: 128.82166666666666 },
    { stationCode: '8000101', name: '진동(부산)', latitude: 35.38333333333333, longitude: 128.4836111111111 },
  ];
  save('KWATER_RIVER_STATIONS', 'ALL', '2026-10-21', stations.map(({ stationCode, name }) => ({ stationCode, name })));
  for (const station of stations) save('KWATER_RIVER_LEVEL', `TEST:${station.stationCode}`, '2026-10-21', []);
  for (const station of stations) {
    const grid = kmaGridFromCoordinates(station.latitude, station.longitude);
    const response = await gridExtraRoutes.request(
      `/catalog?nx=${grid.nx}&ny=${grid.ny}&latitude=${station.latitude}&longitude=${station.longitude}`, {}, env);
    const groups = (await response.json() as any).groups;
    const river = groups.find((g: any) => g.source === 'HRFCO_RIVER_FLOW').targets;
    expect(river).toHaveLength(stations.length);
    // 같은 위치를 보완한 코드가 여러 개여도 별도 관측소로 남고 모두 최근접 후보이다.
    expect(river.find((t: any) => t.id === station.stationCode))
      .toMatchObject({ name: station.name, distanceKm: 0, hasData: false });
    expect(Math.min(...river.map((t: any) => t.distanceKm))).toBe(0);
    expect(groups.find((g: any) => g.source === 'KWATER_RIVER_LEVEL').targets
      .find((t: any) => t.id === `TEST:${station.stationCode}`).distanceKm).toBe(0);
  }
  // 같은 코드의 관측소 이름이 변경되면 과거 보완 위치를 재사용하지 않는다.
  save('KWATER_RIVER_STATIONS', 'ALL', '2026-10-22', [{ stationCode: '8000122', name: '새 관측 지점' }]);
  const response = await gridExtraRoutes.request('/catalog?nx=58&ny=125', {}, env);
  const river = (await response.json() as any).groups.find((g: any) => g.source === 'HRFCO_RIVER_FLOW').targets;
  expect(river.find((t: any) => t.id === '8000122').distanceKm).toBeUndefined();
});

it('하천·K-water 관측소 이름을 코드와 연결하고 이름이 없는 지점은 코드를 유지한다', async () => {
  vi.spyOn(Date, 'now').mockReturnValue(Date.parse('2026-10-21T02:00:00Z'));
  save('HRFCO_STATIONS', 'ALL', '2026-10-21', [
    { stationCode: '1001603', name: '예시교' },
  ]);
  save('HRFCO_RIVER_FLOW', 'ALL', '2026-10-21T01:00:00Z', { stations: [
    { stationCode: '1001603', levelM: 1 }, { stationCode: '1001604', levelM: 2 },
  ] });
  save('KWATER_RIVER_STATIONS', '1001210', '2026-10-21', [
    { stationCode: '9000266', name: '삼척시(갈밭교)' },
  ]);
  save('KWATER_RIVER_LEVEL', '1001210:9000266', '2026-10-21T01:00:00Z', [
    { observedAt: '2026-10-21 10:00', levelM: 3 },
  ]);
  const response = await gridExtraRoutes.request('/catalog?nx=60&ny=121', {}, env);
  const data = await response.json() as { groups: Array<{ source: string; targets: Array<{ id: string; name: string }> }> };
  expect(data.groups.find(g => g.source === 'HRFCO_RIVER_FLOW')?.targets.map(({ id, name }) => ({ id, name }))).toEqual([
    { id: '1001603', name: '예시교' }, { id: '1001604', name: '1001604' },
    { id: '9000266', name: '삼척시(갈밭교)' },
  ]);
  expect(data.groups.find(g => g.source === 'KWATER_RIVER_LEVEL')?.targets.map(({ id, name }) => ({ id, name }))).toEqual([
    { id: '1001210:9000266', name: '삼척시(갈밭교)' },
  ]);
  expect(data.groups.some(g => g.source === 'HRFCO_STATIONS')).toBe(false);
  expect(data.groups.find(g => g.source === 'KWATER_RIVER_LEVEL')?.targets[0])
    .toMatchObject({ hasData: true });
});

it('수위·유량은 제원 기준으로 중복을 제거하고 K-water 전용 관측소도 포함한다', async () => {
  vi.spyOn(Date, 'now').mockReturnValue(Date.parse('2026-10-21T02:00:00Z'));
  save('HRFCO_STATIONS', 'ALL', '2026-10-21', [
    { stationCode: '1001603', name: '공통교' },
    { stationCode: '1001604', name: '오늘 자료 없는 교량' },
  ]);
  save('HRFCO_RIVER_FLOW', 'ALL', '2026-10-21T01:00:00Z', { stations: [
    { stationCode: '1001603', observedAt: '202610211000', levelM: 1 },
  ] });
  save('KWATER_RIVER_STATIONS', 'DAM1', '2026-10-21', [
    { stationCode: '9000266', name: '공통교' },
  ]);
  for (const [dam, code] of [['DAM1', '1001603'], ['DAM1', '9000266'], ['DAM2', '9000266']]) {
    save('KWATER_RIVER_LEVEL', `${dam}:${code}`, '2026-10-21T01:00:00Z', [
      { observedAt: '2026-10-21 10:00', levelM: 3, flowM3PerSec: 4 },
    ]);
  }
  const response = await gridExtraRoutes.request('/catalog?nx=60&ny=121', {}, env);
  const targets = (await response.json() as any).groups.find((g: any) => g.source === 'HRFCO_RIVER_FLOW').targets;
  expect(targets).toHaveLength(3);
  expect(targets.find((t: any) => t.id === '1001603')).toMatchObject({ providers: ['한강홍수통제소', 'K-water'], hasData: true });
  expect(targets.find((t: any) => t.id === '1001604')).toMatchObject({ hasData: false });
  expect(targets.find((t: any) => t.id === '9000266')).toMatchObject({ name: '공통교', providers: ['K-water'] });
});

it('통합 관측소 코드로 K-water 이력을 읽고 같은 시각에는 HRFCO 값을 우선한다', async () => {
  save('HRFCO_RIVER_FLOW', 'ALL', '2026-10-21T01:00:00Z', { stations: [
    { stationCode: '1001603', observedAt: '202610211000', levelM: 1, flowM3PerSec: 2 },
  ] });
  save('KWATER_RIVER_LEVEL', 'DAM1:1001603', '2026-10-21T01:00:00Z', [
    { observedAt: '2026-10-21 10:00', levelM: 999 },
    { observedAt: '202610210000', levelM: 3, flowM3PerSec: 4 },
  ]);
  save('KWATER_RIVER_LEVEL', 'DAM1:9000266', '2026-10-21T01:00:00Z', [
    { observedAt: '202610210000', levelM: 5, flowM3PerSec: 6 },
  ]);
  const read = async (id: string) => (await (await gridExtraRoutes.request(
    `/records?source=HRFCO_RIVER_FLOW&targetId=${id}&nx=60&ny=121`, {}, env)).json() as any);
  const shared = await read('1001603');
  expect(shared.records.map((r: any) => r.values.levelM)).toEqual([1, 3]);
  expect(shared.records.map((r: any) => r.provider)).toEqual(['한강홍수통제소', 'K-water']);
  expect((await read('9000266')).records).toEqual([
    { time: '2026-10-21T00:00:00+09:00', values: { levelM: 5, flowM3PerSec: 6 }, provider: 'K-water' },
  ]);
  expect((await read('900026')).records).toEqual([]);
});

it('실측으로 검증한 서로 다른 코드는 제원 이름도 일치할 때만 연결한다', async () => {
  save('HRFCO_STATIONS', 'ALL', '2026-10-21', [
    { stationCode: '1009652', name: '화천군(평화나래교)' },
  ]);
  save('KWATER_RIVER_STATIONS', 'DAM1', '2026-10-21', [
    { stationCode: '1009654', name: '화천군(평화나래교)' },
  ]);
  save('KWATER_RIVER_LEVEL', 'DAM1:1009654', '2026-10-21T01:00:00Z', [
    { observedAt: '202610210000', levelM: 1, flowM3PerSec: 2 },
  ]);
  const readCatalog = async () => (await (await gridExtraRoutes.request('/catalog?nx=60&ny=121', {}, env)).json() as any)
    .groups.find((g: any) => g.source === 'HRFCO_RIVER_FLOW').targets;
  expect(await readCatalog()).toHaveLength(1);
  const response = await gridExtraRoutes.request('/records?source=HRFCO_RIVER_FLOW&targetId=1009652&nx=60&ny=121', {}, env);
  expect((await response.json() as any).records[0].values).toEqual({ levelM: 1, flowM3PerSec: 2 });
  save('KWATER_RIVER_STATIONS', 'DAM1', '2026-10-22', [
    { stationCode: '1009654', name: '다른 교량' },
  ]);
  expect(await readCatalog()).toHaveLength(2);
});

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
  expect(groups.find((group) => group.source === 'KWATER_DAM')?.targets.map(({ id, name }) => ({ id, name })))
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
