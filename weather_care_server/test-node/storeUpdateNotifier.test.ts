import Database from 'better-sqlite3';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { compareVersions, needsStoreUpdate, readAndroidRelease, readIosRelease,
  type StoreRelease } from '../src/node/storeRelease';
import { initializeStoreUpdateState, notifyStoreRelease, storeUpdateCandidates,
  UPDATE_PUSH_BODY, UPDATE_PUSH_TITLE } from '../src/node/storeUpdateNotifier';
import { sendPush, type FcmPayload } from '../src/notification/fcmClient';

const databases: Database.Database[] = [];
afterEach(() => { for (const db of databases.splice(0)) db.close(); });
function database() { const db = new Database(':memory:'); databases.push(db); return db; }
function setup() {
  const state = database(), installations = database();
  initializeStoreUpdateState(state);
  installations.exec(`CREATE TABLE installations (installation_id TEXT PRIMARY KEY, fcm_token TEXT,
    platform TEXT, app_version TEXT, updated_at TEXT);
    CREATE TABLE notification_settings (installation_id TEXT PRIMARY KEY,notification_enabled INTEGER);`);
  function add(id: string, platform = 'android', version: string | null = null, enabled = 1, token = id) {
    installations.prepare('INSERT INTO installations VALUES (?,?,?,?,?)').run(id, token, platform, version, '2026-10-23');
    installations.prepare('INSERT INTO notification_settings VALUES (?,?)').run(id, enabled);
  }
  const release: StoreRelease = { platform: 'android', version: '1.2.0', build: 120,
    url: 'https://play.google.com/store/apps/details?id=com.codesoha.weathercare' };
  const send = vi.fn(async (payload: FcmPayload) => ({ token: payload.token,
    notificationKey: payload.notificationKey, success: true, unregistered: false, status: 200 }));
  const run = (next = release) => notifyStoreRelease({ state, installations, release: next, send });
  const baseline = () => run({ ...release, version: '1.1.0', build: 110 });
  return { state, installations, add, release, send, run, baseline };
}
const response = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status });

describe('스토어 버전과 구버전 선별', () => {
  it('숫자 단위 비교와 잘못된 버전을 구분한다', () => {
    expect(compareVersions('1.10.0', '1.9.0')).toBe(1);
    expect(compareVersions('1.2', '1.2.0')).toBe(0);
    expect(compareVersions('bad', '1.2.0')).toBeNull();
  });
  it('버전 미보고는 포함하고 최신·미래 버전은 제외한다', () => {
    const { release } = setup();
    for (const version of [null, '', '  ', '1.0.0', '1.0.1', '1.1.0', '1.1.0+110']) {
      expect(needsStoreUpdate(version, release)).toBe(true);
    }
    for (const version of ['1.2.0+120', '1.3.0+130', '1.2.0', '1.3.0', 'broken']) {
      expect(needsStoreUpdate(version, release)).toBe(false);
    }
    expect(needsStoreUpdate('1.2.0+119', release)).toBe(true);
  });
  it('OS·전체알림·토큰을 확인하고 최신 설치본은 제외한다', () => {
    const { add, installations, release } = setup();
    add('legacy'); add('old', 'android', '1.0.1'); add('ios', 'iOS');
    add('new', 'android', '1.2.0+120'); add('off', 'android', null, 0);
    add('empty', 'android', null, 1, '');
    expect(storeUpdateCandidates(installations, release).map((r) => r.installation_id)).toEqual(['legacy', 'old']);
    expect(storeUpdateCandidates(installations, { ...release, platform: 'ios' }).map((r) => r.installation_id)).toEqual(['ios']);
  });
  it('같은 토큰의 최근 보고가 최신이면 이전 등록도 제외한다', () => {
    const { add, installations, release } = setup();
    add('old', 'android', null, 1, 'shared'); add('new', 'android', '1.2.0+120', 1, 'shared');
    installations.prepare('UPDATE installations SET updated_at=? WHERE installation_id=?').run('2026-10-24', 'new');
    expect(storeUpdateCandidates(installations, release)).toEqual([]);
  });
});

describe('버전별 한 번 발송', () => {
  it('최초 성공 조회는 기준만 저장하고 새 버전에서 한 번씩 보낸다', async () => {
    const t = setup(); t.add('legacy'); t.add('latest', 'android', '1.2.0+120');
    expect((await t.baseline()).baseline).toBe(true); expect(t.send).not.toHaveBeenCalled();
    expect((await t.run()).sent).toBe(1); expect((await t.run()).sent).toBe(0);
    expect(t.send.mock.calls[0][0]).toMatchObject({ title: UPDATE_PUSH_TITLE, body: UPDATE_PUSH_BODY,
      notificationTarget: 'STORE_UPDATE', notificationTopic: 'APP_UPDATE', storeUrl: t.release.url });
    expect((await t.run({ ...t.release, build: 130, version: '1.3.0' })).sent).toBe(2);
  });
  it('iOS도 기준 이후 새 버전을 감지하며 Android 이력과 분리한다', async () => {
    const t = setup(); t.add('ios', 'iOS');
    const ios: StoreRelease = { platform: 'ios', version: '1.0.1', url: 'https://apps.apple.com/kr/app/id123456789' };
    await t.run(ios);
    expect((await t.run({ ...ios, version: '1.1.0' })).sent).toBe(1);
    expect((await t.run({ ...ios, version: '1.1.0' })).sent).toBe(0);
    expect((await t.run(ios)).sent).toBe(0);
  });
  it('실패 응답만 재시도하고 성공·토큰 무효·응답 유실은 반복하지 않는다', async () => {
    const t = setup(); t.add('legacy'); await t.baseline();
    t.send.mockResolvedValueOnce({ token: 'legacy', notificationKey: '', success: false, unregistered: false, status: 429 });
    expect((await t.run()).failed).toBe(1); expect((await t.run()).sent).toBe(1);
    expect((await t.run()).sent).toBe(0);
    t.send.mockRejectedValueOnce(new Error('timeout'));
    const next = { ...t.release, build: 130 };
    expect((await t.run(next)).uncertain).toBe(1); expect((await t.run(next)).sent).toBe(0);
    t.send.mockResolvedValueOnce({ token: 'legacy', notificationKey: '', success: false, unregistered: true, status: 404 });
    const last = { ...t.release, build: 140 };
    expect((await t.run(last)).failed).toBe(1); expect((await t.run(last)).sent).toBe(0);
  });
  it('중복 실행에서 접수중 기록을 다시 보내지 않고 중복 토큰도 한 번 보낸다', async () => {
    const t = setup(); t.add('first', 'android', null, 1, 'shared'); t.add('second', 'android', null, 1, 'shared');
    await t.baseline();
    const both = await Promise.all([t.run(), t.run()]);
    expect(both.reduce((n, r) => n + r.sent, 0)).toBe(1);
    t.installations.prepare('DELETE FROM installations WHERE installation_id=?').run('first');
    expect((await t.run()).sent).toBe(0);
  });
  it('발송 중 다음 기기가 업데이트하거나 알림을 끄면 재확인하여 제외한다', async () => {
    const t = setup(); t.add('a'); t.add('b'); t.add('c'); await t.baseline();
    t.send.mockImplementationOnce(async (p) => {
      t.installations.prepare('UPDATE installations SET app_version=? WHERE installation_id=?').run('1.2.0+120', 'b');
      t.installations.prepare('UPDATE notification_settings SET notification_enabled=0 WHERE installation_id=?').run('c');
      return { token: p.token, notificationKey: p.notificationKey, success: true, unregistered: false, status: 200 };
    });
    expect((await t.run()).sent).toBe(1); expect(t.send).toHaveBeenCalledTimes(1);
  });
  it('실행기를 재구성해도 기존 발송 이력과 공개 버전 역행 방지를 유지한다', async () => {
    const t = setup(); t.add('legacy'); await t.baseline(); await t.run();
    initializeStoreUpdateState(t.state);
    expect((await t.run()).sent).toBe(0); expect((await t.baseline()).sent).toBe(0);
    expect((await t.run()).sent).toBe(0);
  });
});

describe('공식 스토어 응답 검증', () => {
  it('iOS는 한국 공개 앱의 버전·상세 주소를 조회한다', async () => {
    const fetcher = vi.fn(async () => response({ results: [{ bundleId: 'com.codesoha.weathercare',
      version: '1.1.0', trackViewUrl: 'https://apps.apple.com/kr/app/id123456789' }] }));
    expect(await readIosRelease(fetcher)).toMatchObject({ platform: 'ios', version: '1.1.0' });
    expect(fetcher.mock.calls[0][0]).toContain('country=kr');
  });
  it('iOS 미등록·타 앱은 알림 없음, 오류·임의 외부 주소는 실패로 처리한다', async () => {
    expect(await readIosRelease(async () => response({ results: [] }))).toBeNull();
    await expect(readIosRelease(async () => response({}, 503))).rejects.toThrow('APP_STORE_HTTP_503');
    await expect(readIosRelease(async () => response({ results: [{ bundleId: 'com.codesoha.weathercare',
      version: '1.1.0', trackViewUrl: 'https://example.com/id123' }] }))).rejects.toThrow('APP_STORE_RESPONSE_INVALID');
  });
  it('Android는 정식 전체 공개만 선택하고 조회용 edit를 폐기한다', async () => {
    const fetcher = vi.fn().mockResolvedValueOnce(response({ id: 'edit-1' }))
      .mockResolvedValueOnce(response({ track: 'production', releases: [
        { name: '1.3.0', status: 'inProgress', versionCodes: ['130'] },
        { name: '1.2.0', status: 'completed', versionCodes: ['120'] },
        { name: '1.4.0', status: 'draft', versionCodes: ['140'] },
        { name: '1.5.0', status: 'halted', versionCodes: ['150'] },
      ] })).mockResolvedValueOnce(new Response(null, { status: 204 }));
    expect(await readAndroidRelease({ clientEmail: '', privateKey: '' }, fetcher, async () => 'token'))
      .toMatchObject({ platform: 'android', version: '1.2.0', build: 120 });
    expect(fetcher.mock.calls.map((call) => call[1].method ?? 'GET')).toEqual(['POST', 'GET', 'DELETE']);
    expect(fetcher.mock.calls.some((call) => call[0].includes('commit'))).toBe(false);
  });
  it('Android 트랙 조회 실패 때도 edit를 폐기하고 기준/발송을 만들지 않는다', async () => {
    const fetcher = vi.fn().mockResolvedValueOnce(response({ id: 'edit-2' }))
      .mockResolvedValueOnce(response({}, 403)).mockResolvedValueOnce(new Response(null, { status: 204 }));
    await expect(readAndroidRelease({ clientEmail: '', privateKey: '' }, fetcher, async () => 'token'))
      .rejects.toThrow('PLAY_TRACK_HTTP_403');
    expect(fetcher.mock.calls[2][1].method).toBe('DELETE');
  });
  it('FCM에 동일한 원문과 스토어 이동 데이터를 전달한다', async () => {
    const fetcher = vi.fn(async () => response({ name: 'accepted' }));
    await sendPush({ projectId: 'test', clientEmail: 'test', privateKey: 'test' }, {
      token: 'token', title: UPDATE_PUSH_TITLE, body: UPDATE_PUSH_BODY,
      notificationKey: 'APP_UPDATE', notificationTarget: 'STORE_UPDATE', notificationTopic: 'APP_UPDATE',
      storeUrl: 'https://apps.apple.com/kr/app/id123456789',
    }, { fetcher, accessTokenProvider: async () => 'access' });
    const message = JSON.parse(fetcher.mock.calls[0][1].body as string).message;
    expect(message.notification.body).toBe(UPDATE_PUSH_BODY);
    expect(message.data).toMatchObject({ notificationTarget: 'STORE_UPDATE', storeUrl: 'https://apps.apple.com/kr/app/id123456789' });
  });
});
