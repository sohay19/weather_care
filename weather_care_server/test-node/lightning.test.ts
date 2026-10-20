import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { collectGridLightning } from '../src/collection/gridExtraCollection';
import gridExtraRoutes from '../src/api/gridExtra';
import { lightningForGrid, lightningTime, readLightningFeed } from '../src/services/lightning';
import { runLightningNotificationJob } from '../src/notification/lightningNotificationJob';
import { sendBatch, type FcmPayload, type FcmSendResult } from '../src/notification/fcmClient';
import { getNotificationSettings, upsertNotificationSettings } from '../src/database/notificationSettingsRepository';
import { asD1Database, runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { kmaGridFromCoordinates } from '../src/regions/kmaGridFromCoordinates';
import type { ServerEnv } from '../src/types';

let sqlite: SqliteD1Database;
let env: ServerEnv;
const now = new Date('2026-10-20T03:15:00Z');
const point = { latitude: 37.2636, longitude: 127.0286 };
const grid = kmaGridFromCoordinates(point.latitude, point.longitude);

beforeEach(() => {
  sqlite = new SqliteD1Database(':memory:');
  runSqliteMigrations(sqlite);
  env = { DB: asD1Database(sqlite) } as ServerEnv;
});
afterEach(() => { sqlite.close(); vi.useRealTimers(); });

function state(status = 'AVAILABLE', end = '2026-10-20T03:10:00Z') {
  sqlite.sqlite.prepare('INSERT OR REPLACE INTO lightning_collection_state VALUES(1,?,?,?)')
    .run(now.toISOString(), end, status);
}

function snapshot(times: string[], slot = '2026-10-20T03:00:00Z', extra: unknown[] = []) {
  sqlite.sqlite.prepare('INSERT OR REPLACE INTO grid_extra_snapshots VALUES(?,?,?,?,?)')
    .run('KMA_LIGHTNING', 'ALL', slot,
      JSON.stringify({ events: [...times.map((observedAt) => ({ ...point, observedAt })), ...extra] }), now.toISOString());
}

function installation(id = 'test-installation') {
  sqlite.sqlite.prepare('INSERT INTO installation_credentials VALUES(?,?,?)').run(id, 'synthetic', now.toISOString());
  sqlite.sqlite.prepare(`INSERT INTO installations(installation_id,fcm_token,nx,ny,region_topic,
    location_mode,minimum_age_confirmed_at,age_policy_version,created_at,updated_at)
    VALUES(?,?,?,?,?,'GPS',?,1,?,?)`)
    .run(id, 'synthetic-token', grid.nx, grid.ny, 'synthetic', now.toISOString(), now.toISOString(), now.toISOString());
  sqlite.sqlite.prepare(`INSERT INTO notification_settings(installation_id,created_at,updated_at) VALUES(?,?,?)`)
    .run(id, now.toISOString(), now.toISOString());
}

function sender(sent: FcmPayload[], success = true) {
  return async (_env: ServerEnv, payloads: FcmPayload[]): Promise<FcmSendResult[]> => {
    sent.push(...payloads);
    return payloads.map((payload) => ({ token: payload.token, notificationKey: payload.notificationKey,
      success, unregistered: false, status: success ? 200 : 503 }));
  };
}

describe('낙뢰 관측 유효성·수집 상태', () => {
  it('한국 시각의 12/14자리 발생 시각을 보존하고 시간대 없는 값은 거부한다', () => {
    expect(lightningTime('20261020121001')).toBe('2026-10-20T03:10:01.000Z');
    expect(lightningTime('202610201210')).toBe('2026-10-20T03:10:00.000Z');
    expect(lightningTime('2026-10-20T12:10:00')).toBeUndefined();
    expect(lightningTime('not a date')).toBeUndefined();
    expect(lightningTime('202602301210')).toBeUndefined();
  });

  it('30분 미만만 사용하며 경계·미래·다른 격자·중복·잘못된 좌표를 제외한다', async () => {
    state();
    snapshot(['20261020124459', '20261020124500', '20261020124501', '202610201210',
      '202610201210'], '2026-10-20T03:00:00Z', [
      { observedAt: '202610201210', latitude: 35.1, longitude: 129.1 },
      { observedAt: '202610201210', latitude: null, longitude: null },
      { observedAt: 'invalid', ...point },
    ]);
    // 12:15 KST 기준: 12:45는 미래, 11:45는 정확히 30분 경계.
    snapshot(['20261020114459', '20261020114500', '20261020114501'], '2026-10-20T02:40:00Z');
    const summary = lightningForGrid(await readLightningFeed(env.DB, now), grid.nx, grid.ny, now);
    expect(summary.count).toBe(2);
    expect(summary.latestObservedAt).toBe('2026-10-20T03:10:00.000Z');
    expect(summary.expiresAt).toBe('2026-10-20T03:40:00.000Z');
    expect(summary.observations).toContain('2026-10-20T02:45:01.000Z');
  });

  it('수집 실패·미수집·20분 지연은 관측 없음과 구분하고 오래된 값을 반환하지 않는다', async () => {
    snapshot(['202610201210']);
    expect((await readLightningFeed(env.DB, now)).status).toBe('UNAVAILABLE');
    state('FAILED');
    expect(await readLightningFeed(env.DB, now)).toMatchObject({ status: 'FAILED', events: [] });
    state('AVAILABLE', '2026-10-20T02:55:00Z');
    expect(await readLightningFeed(env.DB, now)).toMatchObject({ status: 'STALE', events: [] });
    state();
    expect((await readLightningFeed(env.DB, now)).status).toBe('AVAILABLE');
  });

  it('HTTP API는 현재 격자 요약과 no-store를 반환하고 DB 실패는 503으로 표시한다', async () => {
    vi.useFakeTimers(); vi.setSystemTime(now);
    state(); snapshot(['202610201210']);
    const path = `/lightning?nx=${grid.nx}&ny=${grid.ny}`;
    const response = await gridExtraRoutes.request(path, {}, env);
    expect(response.headers.get('cache-control')).toBe('no-store');
    expect(await response.json()).toMatchObject({ status: 'AVAILABLE', count: 1, ...grid });
    expect((await gridExtraRoutes.request('/lightning?nx=0&ny=1', {}, env)).status).toBe(400);
    sqlite.sqlite.exec('DROP TABLE lightning_collection_state');
    const failed = await gridExtraRoutes.request(path, {}, env);
    expect(failed.status).toBe(503);
    expect(await failed.json()).toMatchObject({ status: 'FAILED', count: 0 });
  });

  it('수집 HTTP 실패를 기록하고 정상 재수집 시 복구한다', async () => {
    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await collectGridLightning({ db: env.DB, key: 'synthetic', now,
        fetcher: (async () => new Response('failed', { status: 503 })) as typeof fetch });
      expect((await readLightningFeed(env.DB, now)).status).toBe('FAILED');
      await collectGridLightning({ db: env.DB, key: 'synthetic', now,
        fetcher: (async () => new Response('# header\n202610201208 127.0286 37.2636 -4 G 0\n')) as typeof fetch });
      expect((await readLightningFeed(env.DB, now)).status).toBe('AVAILABLE');
      expect(lightningForGrid(await readLightningFeed(env.DB, now), grid.nx, grid.ny, now).count).toBe(1);
    } finally { errorLog.mockRestore(); }
  });

  it('정상 빈 관측은 성공으로 기록하고 형식 불명의 응답은 조회 실패로 기록한다', async () => {
    const errorLog = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await collectGridLightning({ db: env.DB, key: 'synthetic', now,
        fetcher: (async () => new Response('unrecognized response')) as typeof fetch });
      expect((await readLightningFeed(env.DB, now)).status).toBe('FAILED');
      await collectGridLightning({ db: env.DB, key: 'synthetic', now,
        fetcher: (async () => new Response('#START7777\n# observation header\n#END7777\n')) as typeof fetch });
      expect(await readLightningFeed(env.DB, now)).toMatchObject({ status: 'AVAILABLE', events: [] });
    } finally { errorLog.mockRestore(); }
  });
});

describe('낙뢰 전용 알림', () => {
  it('새 관측을 한 번 보내고 같은 자료·수집 갱신으로 반복 전송하지 않는다', async () => {
    installation(); state(); snapshot(['202610201210']);
    const sent: FcmPayload[] = [];
    await runLightningNotificationJob(env, { now: () => now, sender: sender(sent) });
    await runLightningNotificationJob(env, { now: () => now, sender: sender(sent) });
    expect(sent).toHaveLength(1);
    expect(sent[0]).toMatchObject({ notificationTopic: 'LIGHTNING', notificationTarget: 'WEATHER_DETAILS' });
    // 수집 만료가 연장돼도 이미 보낸 발생 건은 다시 보내지 않는다.
    state('AVAILABLE', '2026-10-20T03:20:00Z');
    sqlite.sqlite.prepare('UPDATE lightning_collection_state SET attempted_at=?').run('2026-10-20T03:25:00Z');
    await runLightningNotificationJob(env, { now: () => new Date('2026-10-20T03:25:00Z'), sender: sender(sent) });
    expect(sent).toHaveLength(1);
    snapshot(['202610201220']);
    await runLightningNotificationJob(env, { now: () => new Date('2026-10-20T03:25:00Z'), sender: sender(sent) });
    expect(sent).toHaveLength(2);
  });

  it('한국 날짜가 자정에 바뀌어도 같은 낙뢰를 다시 보내지 않는다', async () => {
    installation();
    snapshot(['202610202350'], '2026-10-20T14:40:00Z');
    sqlite.sqlite.prepare('INSERT INTO lightning_collection_state VALUES(1,?,?,?)')
      .run('2026-10-20T14:55:00.000Z', '2026-10-20T14:50:00.000Z', 'AVAILABLE');
    const sent: FcmPayload[] = [];
    await runLightningNotificationJob(env, { now: () => new Date('2026-10-20T14:59:00Z'), sender: sender(sent) });
    await runLightningNotificationJob(env, { now: () => new Date('2026-10-20T15:01:00Z'), sender: sender(sent) });
    expect(sent).toHaveLength(1);
  });

  it('전송을 기다리는 동안 지역이나 설정이 바뀌면 발송하지 않는다', async () => {
    installation(); state(); snapshot(['202610201210']);
    const sent: FcmPayload[] = [];
    let reads = 0;
    await runLightningNotificationJob(env, { now: () => {
      if (++reads === 3) sqlite.sqlite.prepare('UPDATE installations SET nx=1,ny=1').run();
      return now;
    }, sender: sender(sent) });
    expect(sent).toEqual([]);
  });

  it.each(['notification_enabled', 'lightning_enabled'])('%s 끄기는 발송을 막고 설정 저장에도 유지된다', async (column) => {
    installation(); state(); snapshot(['202610201210']);
    sqlite.sqlite.prepare(`UPDATE notification_settings SET ${column}=0`).run();
    const sent: FcmPayload[] = [];
    await runLightningNotificationJob(env, { now: () => now, sender: sender(sent) });
    expect(sent).toEqual([]);
    const settings = await getNotificationSettings(env.DB, 'test-installation');
    await upsertNotificationSettings(env.DB, { ...settings, lightningEnabled: false });
    expect((await getNotificationSettings(env.DB, 'test-installation')).lightningEnabled).toBe(false);
  });

  it('다른 지역·오래된 관측·수집 실패 시 발송하지 않는다', async () => {
    installation(); state(); snapshot(['202610201140']);
    const sent: FcmPayload[] = [];
    const dependencies = { now: () => now, sender: sender(sent) };
    await runLightningNotificationJob(env, dependencies);
    snapshot(['202610201210']); state('FAILED');
    await runLightningNotificationJob(env, dependencies);
    state(); sqlite.sqlite.prepare('UPDATE installations SET nx=1,ny=1').run();
    await runLightningNotificationJob(env, dependencies);
    expect(sent).toEqual([]);
  });

  it('겹친 실행은 중복 전송하지 않고 전송 실패 후에는 재시도한다', async () => {
    installation(); state(); snapshot(['202610201210']);
    const sent: FcmPayload[] = [];
    const dependencies = { now: () => now, sender: sender(sent) };
    await Promise.all([runLightningNotificationJob(env, dependencies), runLightningNotificationJob(env, dependencies)]);
    expect(sent).toHaveLength(1);
    snapshot(['202610201211']);
    await runLightningNotificationJob(env, { now: () => now, sender: sender(sent, false) });
    await runLightningNotificationJob(env, dependencies);
    expect(sent).toHaveLength(3);
    sqlite.sqlite.prepare('DELETE FROM installations').run();
    expect(sqlite.sqlite.prepare('SELECT COUNT(*) AS n FROM lightning_notification_claims').get()).toEqual({ n: 0 });
  });

  it('전송 직전 시간이 만료되면 보내지 않는다', async () => {
    installation(); state(); snapshot(['202610201210']);
    const sent: FcmPayload[] = [];
    let reads = 0;
    await runLightningNotificationJob(env, { now: () => ++reads < 4 ? now : new Date('2026-10-20T03:40:00Z'), sender: sender(sent) });
    expect(sent).toEqual([]);
  });

  it('FCM에 만료·TTL을 전달하고 만료된 메시지는 HTTP 요청을 보내지 않는다', async () => {
    const requests: Record<string, any>[] = [];
    const dependencies = { now: () => now.getTime(), accessTokenProvider: async () => 'synthetic',
      fetcher: (async (_url, init) => { requests.push(JSON.parse(String(init?.body))); return Response.json({ name: 'synthetic' }); }) as typeof fetch };
    const payload: FcmPayload = { token: 'synthetic', title: '낙뢰 관측', body: '본문', notificationKey: 'LIGHTNING_test',
      notificationTarget: 'WEATHER_DETAILS', notificationTopic: 'LIGHTNING', expiresAt: '2026-10-20T03:20:00Z' };
    await sendBatch({ projectId: 'synthetic', clientEmail: 'synthetic', privateKey: 'synthetic' }, [payload], dependencies);
    expect(requests[0].message.android.ttl).toBe('300s');
    expect(requests[0].message.apns.headers['apns-expiration']).toBe(`${Date.parse(payload.expiresAt!) / 1000}`);
    expect(requests[0].message.data.expiresAt).toBe(payload.expiresAt);
    const expired = await sendBatch({ projectId: 'synthetic', clientEmail: 'synthetic', privateKey: 'synthetic' },
      [{ ...payload, expiresAt: now.toISOString() }], dependencies);
    expect(expired[0].status).toBe(410);
    expect(requests).toHaveLength(1);
  });
});
