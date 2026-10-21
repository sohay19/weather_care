import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import routes from '../src/api/installations';
import { asD1Database, runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { secretHash } from '../src/security/installationAccess';
import { kmaGridFromCoordinates } from '../src/regions/kmaGridFromCoordinates';
import type { ServerEnv } from '../src/types';

let sqlite: SqliteD1Database;
let env: ServerEnv;
const now = new Date('2026-10-21T03:00:00.000Z');
const id = 'device-movement';
const revision = '12345678-1234-4234-8234-123456789012';
const newerRevision = '12345678-1234-4234-8234-123456789013';
const headers = { Authorization: `Bearer ${'a'.repeat(64)}`, 'Content-Type': 'application/json' };
const sample = { revision, latitude: 35.1796, longitude: 129.0756,
  accuracy: 50, precise: true, measuredAt: now.toISOString() };

beforeEach(async () => {
  vi.useFakeTimers(); vi.setSystemTime(now);
  sqlite = new SqliteD1Database(':memory:');
  runSqliteMigrations(sqlite);
  env = { DB: asD1Database(sqlite) } as ServerEnv;
  sqlite.sqlite.prepare('INSERT INTO installation_credentials VALUES(?,?,?)')
    .run(id, await secretHash('a'.repeat(64)), now.toISOString());
  sqlite.sqlite.prepare(`INSERT INTO installations(installation_id,fcm_token,nx,ny,region_topic,
    location_mode,minimum_age_confirmed_at,age_policy_version,created_at,updated_at)
    VALUES(?,'existing-token',60,121,'weather_60_121','GPS',?,1,?,?)`)
    .run(id, now.toISOString(), now.toISOString(), now.toISOString());
  sqlite.sqlite.prepare('INSERT INTO notification_settings(installation_id,created_at,updated_at) VALUES(?,?,?)')
    .run(id, now.toISOString(), now.toISOString());
});
afterEach(() => { sqlite.close(); vi.useRealTimers(); });

function request(path: string, body: unknown, method = 'PUT', auth = headers) {
  return routes.request(`/${id}/${path}`, { method, headers: auth, body: JSON.stringify(body) }, env);
}
function stored() { return sqlite.sqlite.prepare('SELECT * FROM installations WHERE installation_id = ?').get(id) as Record<string, unknown>; }
async function enable() { expect((await request('background-location', { revision })).status).toBe(200); }

describe('백그라운드 이동에 따른 서버 알림 지역 갱신', () => {
  it('소유자 인증 없이 감시를 켜거나 위치를 변경할 수 없다', async () => {
    expect((await request('background-location', { revision }, 'PUT', { ...headers, Authorization: '' })).status).toBe(401);
    expect((await request('location', sample, 'PUT', { ...headers, Authorization: `Bearer ${'b'.repeat(64)}` })).status).toBe(401);
  });
  it('갱신은 알림 지역·최신 좌표만 바꾸고 토큰과 알림 설정을 보존한다', async () => {
    await enable();
    const response = await request('location', sample, 'PUT');
    expect(await response.json()).toEqual({ ok: true, updated: true });
    const grid = kmaGridFromCoordinates(sample.latitude, sample.longitude);
    expect(stored()).toMatchObject({ ...grid, region_topic: `weather_${grid.nx}_${grid.ny}`,
      latitude: sample.latitude, longitude: sample.longitude, fcm_token: 'existing-token',
      location_measured_at: sample.measuredAt, location_mode: 'GPS' });
    expect(sqlite.sqlite.prepare('SELECT notification_enabled, lightning_enabled FROM notification_settings').get())
      .toEqual({ notification_enabled: 1, lightning_enabled: 1 });
  });
  it('꺼진 기능과 이전 감시 세션에서 온 요청을 거부한다', async () => {
    expect((await request('location', sample, 'PUT')).status).toBe(409);
    await enable();
    await request('background-location', { revision: newerRevision });
    expect((await request('location', sample, 'PUT')).status).toBe(409);
    await request('background-location', { revision: null });
    expect((await request('location', { ...sample, revision: newerRevision }, 'PUT')).status).toBe(409);
    expect(stored().nx).toBe(60);
  });
  it('중복·역순 측정은 최신 지역을 덮어쓰지 않는다', async () => {
    await enable();
    await request('location', sample, 'PUT');
    for (const measuredAt of [sample.measuredAt, '2026-10-21T02:59:00.000Z']) {
      const response = await request('location', { ...sample, latitude: 37.5, measuredAt }, 'PUT');
      expect(await response.json()).toEqual({ ok: true, updated: false });
    }
    expect(stored().latitude).toBe(sample.latitude);
  });
  it.each(['2026-10-21T02:44:59.999Z', '2026-10-21T03:01:00.001Z'])('오래되거나 미래인 측정을 거부한다: %s', async (measuredAt) => {
    await enable();
    expect((await request('location', { ...sample, measuredAt }, 'PUT')).status).toBe(422);
    expect(stored().nx).toBe(60);
  });
  it.each([{ latitude: 0 }, { longitude: null }, { accuracy: -1 }, { accuracy: 5001 },
    { measuredAt: 'invalid' }, { fcmToken: 'must-not-change' }])('잘못된 좌표·정밀도·추가 필드를 거부한다: %j', async (change) => {
    await enable();
    expect((await request('location', { ...sample, ...change }, 'PUT')).status).toBe(400);
  });
  it.each([{ precise: false }, { accuracy: 800 }])('대략적인 위치는 격자만 저장하고 정밀 좌표를 지운다: %j', async (change) => {
    await enable();
    await request('location', { ...sample, ...change }, 'PUT');
    expect(stored()).toMatchObject({ ...kmaGridFromCoordinates(sample.latitude, sample.longitude), latitude: null, longitude: null });
  });
  it('수동 지역 전환은 세션을 해제하고 뒤늦은 이동을 무시한다', async () => {
    await enable();
    const response = await routes.request(`/${id}?nx=58&ny=125`, {
      method: 'PUT', headers, body: JSON.stringify({ locationMode: 'MANUAL', minimumAgeConfirmed: true, agePolicyVersion: 1 }),
    }, env);
    expect(response.status).toBe(200);
    expect(stored()).toMatchObject({ background_location_revision: null, location_mode: 'MANUAL', nx: 58, ny: 125 });
    expect((await request('location', sample, 'PUT')).status).toBe(409);
    expect((await request('background-location', { revision })).status).toBe(409);
  });
  it('전체 알림 끄기는 세션을 해제하며 다시 켜도 이전 요청을 되살리지 않는다', async () => {
    await enable();
    sqlite.sqlite.prepare('UPDATE notification_settings SET notification_enabled = 0').run();
    expect(stored().background_location_revision).toBeNull();
    expect((await request('background-location', { revision })).status).toBe(409);
    sqlite.sqlite.prepare('UPDATE notification_settings SET notification_enabled = 1').run();
    expect((await request('location', sample, 'PUT')).status).toBe(409);
  });
  it('연령 미확인·삭제된 설치는 이동 감시로 복구할 수 없다', async () => {
    sqlite.sqlite.prepare('UPDATE installations SET minimum_age_confirmed_at = NULL').run();
    expect((await request('background-location', { revision })).status).toBe(409);
    sqlite.sqlite.prepare('DELETE FROM installations').run();
    expect((await request('location', sample, 'PUT')).status).toBe(409);
    expect(sqlite.sqlite.prepare('SELECT count(*) AS count FROM installations').get()).toEqual({ count: 0 });
  });
  it('늦게 완료된 앱 전경 등록도 더 최신인 이동 측정을 덮어쓰지 않는다', async () => {
    await enable();
    await request('location', sample, 'PUT');
    const response = await routes.request(`/${id}?nx=60&ny=121`, { method: 'PUT', headers,
      body: JSON.stringify({ minimumAgeConfirmed: true, agePolicyVersion: 1, locationMode: 'GPS',
        locationMeasuredAt: '2026-10-21T02:00:00.000Z', fcmToken: 'refreshed-token', latitude: 37.5, longitude: 127 }) }, env);
    expect(response.status).toBe(200);
    expect(stored()).toMatchObject({ latitude: sample.latitude, longitude: sample.longitude,
      fcm_token: 'refreshed-token', location_measured_at: sample.measuredAt, background_location_revision: revision });
  });
});
