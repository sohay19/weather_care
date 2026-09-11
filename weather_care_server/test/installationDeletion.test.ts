import { env } from 'cloudflare:test';
import { Hono } from 'hono';
import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest';
import ownership from '../src/api/installationOwnership';
import registrations from '../src/api/installations';
import settings from '../src/api/notificationSettings';
import * as fcm from '../src/notification/fcmClient';
import * as analyticsDeletion from '../src/analytics/analyticsDeletionClient';
import { deleteInstallationData, secretHash } from '../src/security/installationAccess';
import { upsertInstallation } from '../src/database/installationsRepository';
import { defaultNotificationSettings, upsertNotificationSettings } from '../src/database/notificationSettingsRepository';
import { testAuthHeaders, testSecret } from './installationAuthFixture';
import type { ServerEnv } from '../src/types';
import m1 from '../migrations/0001_init.sql?raw';
import m2 from '../migrations/0002_notification_preferences.sql?raw';
import m3 from '../migrations/0003_precise_precipitation_location.sql?raw';
import m4 from '../migrations/0004_official_warning_state.sql?raw';
import m5 from '../migrations/0005_road_ice_state.sql?raw';
import m6 from '../migrations/0006_road_control_state.sql?raw';
import m7 from '../migrations/0007_installation_access.sql?raw';
import m8 from '../migrations/0008_data_retention.sql?raw';

const legacyId = 'wc_legacy_synthetic_fixture_0001';
const noTokenId = 'wc_legacy_without_token_000001';
const path = '/api/v1/installations';
const app = new Hono<{ Bindings: ServerEnv }>();
app.route(path, ownership); app.route(path, registrations);
app.route('/api/v1/notification-settings', settings);
const request = (url: string, method = 'GET', body?: object, headers = testAuthHeaders) =>
  app.request(url, { method, headers, body: body ? JSON.stringify(body) : undefined },
    { ...env, INSTALLATION_ENROLL_LIMIT: { limit: async () => ({ success: true }) } });

async function apply(sql: string) {
  await env.DB.exec(sql.replace(/--[^\n]*/g, '').replace(/\r?\n/g, ' '));
}
async function enrollment() {
  const response = await request(`${path}/enroll`, 'POST', {});
  expect(response.status).toBe(201);
  return (await response.json<{ installationId: string }>()).installationId;
}
async function seed(id: string) {
  expect((await request(`${path}/${id}?nx=60&ny=121`, 'PUT', {
    fcmToken: 'synthetic-not-a-real-fcm-token', locationMode: 'GPS', latitude: 37.2, longitude: 127.1,
  })).status).toBe(200);
  expect((await request(`/api/v1/notification-settings/${id}`, 'PUT', { notificationEnabled: false })).status).toBe(200);
  await env.DB.prepare('INSERT INTO notification_history VALUES (?, ?, ?, ?, ?)')
    .bind(id, '2026-09-11', 'TEST', '2026-09-11T00:00:00Z', 'synthetic').run();
  await env.DB.prepare('INSERT INTO installation_warning_state VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
    .bind(id, 'R', '호우', '2', '경보', '테스트', '2026-09-11', '2026-09-11').run();
}
async function count(table: string, id: string) {
  return (await env.DB.prepare(`SELECT COUNT(*) AS count FROM ${table} WHERE installation_id = ?`)
    .bind(id).first<{ count: number }>())!.count;
}

beforeEach(async () => {
  await env.DB.exec('DROP TABLE IF EXISTS installation_activity');
  // Isolated test binding only. Production data is never used in this suite.
  await env.DB.exec(`DROP TABLE IF EXISTS installation_ownership_challenges; DROP TABLE IF EXISTS legacy_installation_ownership; DROP TABLE IF EXISTS installation_warning_state; DROP TABLE IF EXISTS notification_history; DROP TABLE IF EXISTS notification_settings; DROP TABLE IF EXISTS installations; DROP TABLE IF EXISTS installation_credentials; DROP TABLE IF EXISTS active_regions; DROP TABLE IF EXISTS weather_cache; DROP TABLE IF EXISTS daily_weather_snapshots;`);
  for (const migration of [m1, m2, m3, m4, m5, m6]) await apply(migration);
  for (const [id, token] of [[legacyId, 'original-delivery-token'], [noTokenId, null]]) {
    await env.DB.prepare(`INSERT INTO installations
      (installation_id, fcm_token, nx, ny, region_topic, location_mode, timezone, created_at, updated_at)
      VALUES (?, ?, 60, 121, 'region', 'GPS', 'Asia/Seoul', 'old', 'old')`).bind(id, token).run();
  }
  await apply(m7);
  await apply(m8);
  vi.spyOn(fcm, 'sendOwnershipChallenge').mockResolvedValue();
  vi.spyOn(analyticsDeletion, 'submitAnalyticsUserDeletion').mockResolvedValue({
    deletionRequestTime: '2026-09-11T01:02:03Z',
  });
});
afterEach(() => vi.restoreAllMocks());

describe('authenticated server data deletion', () => {
  it('accepts an authenticated Analytics deletion request and rejects other credentials', async () => {
    const id = await enrollment();
    const response = await request(`${path}/${id}/analytics-deletion`, 'POST', {
      appInstanceId: 'analytics-instance-1',
    });
    expect(response.status).toBe(202);
    expect(await response.json()).toEqual({
      deletionRequestTime: '2026-09-11T01:02:03Z',
    });
    expect(analyticsDeletion.submitAnalyticsUserDeletion).toHaveBeenCalledWith(
      expect.objectContaining({ propertyId: '549443110' }),
      'analytics-instance-1',
    );
    expect((await request(`${path}/${id}/analytics-deletion`, 'POST', {
      appInstanceId: 'analytics-instance-1',
    }, { ...testAuthHeaders, Authorization: `Bearer ${'b'.repeat(64)}` })).status).toBe(401);
    expect((await request(`${path}/${id}/analytics-deletion`, 'POST', {
      appInstanceId: '',
    })).status).toBe(400);
  });

  it('rate limits Analytics deletion before calling Google', async () => {
    const id = await enrollment();
    vi.mocked(analyticsDeletion.submitAnalyticsUserDeletion).mockClear();
    const response = await app.request(
      `${path}/${id}/analytics-deletion`,
      { method: 'POST', headers: testAuthHeaders,
        body: JSON.stringify({ appInstanceId: 'analytics-instance-1' }) },
      { ...env,
        INSTALLATION_ENROLL_LIMIT: { limit: async () => ({ success: true }) },
        ANALYTICS_DELETION_LIMIT: { limit: async () => ({ success: false }) } },
    );
    expect(response.status).toBe(429);
    expect(response.headers.get('Retry-After')).toBe('60');
    expect(analyticsDeletion.submitAnalyticsUserDeletion).not.toHaveBeenCalled();
  });

  it('limits anonymous enrollment without creating a credential', async () => {
    const response = await app.request(`${path}/enroll`, { method: 'POST', headers: testAuthHeaders, body: '{}' },
      { ...env, INSTALLATION_ENROLL_LIMIT: { limit: async () => ({ success: false }) } });
    expect(response.status).toBe(429); expect(response.headers.get('Retry-After')).toBe('60');
    expect(await env.DB.prepare('SELECT 1 FROM installation_credentials').first()).toBeNull();
  });
  it('deletes only the authenticated installation and preserves shared/other data', async () => {
    const id = await enrollment(); const other = await enrollment();
    await seed(id); await seed(other);
    await env.DB.prepare(`INSERT INTO weather_cache VALUES ('shared', 'region', 60, 121, 'weather', '{}', 'AVAILABLE', 'now')`).run();
    const response = await request(`${path}/${id}`, 'DELETE');
    expect(response.status).toBe(204); expect(response.headers.get('Cache-Control')).toBe('no-store');
    for (const table of ['installations', 'notification_settings', 'notification_history',
      'installation_warning_state', 'installation_credentials', 'installation_ownership_challenges', 'legacy_installation_ownership', 'installation_activity']) {
      expect(await count(table, id)).toBe(0);
    }
    expect(await count('installations', other)).toBe(1);
    expect(await count('notification_history', other)).toBe(1);
    expect(await env.DB.prepare('SELECT 1 FROM weather_cache').first()).not.toBeNull();
  });

  it('ID alone, another credential, or malformed authorization cannot delete/read/update', async () => {
    const id = await enrollment(); await seed(id);
    for (const Authorization of ['', `Bearer ${'b'.repeat(64)}`, 'Bearer short']) {
      const headers = { ...testAuthHeaders, Authorization };
      for (const [url, method, body] of [
        [`${path}/${id}`, 'DELETE', undefined], [`${path}/${id}`, 'PUT', {}],
        [`${path}/${id}/notification-settings`, 'PUT', {}],
        [`/api/v1/notification-settings/${id}`, 'PUT', {}],
        [`/api/v1/notification-settings?installationId=${id}`, 'GET', undefined],
      ] as const) expect((await request(url, method, body, headers)).status).toBe(401);
    }
    expect(await count('installations', id)).toBe(1);
  });

  it('retrying a completed delete succeeds without retaining a tombstone or recreating data', async () => {
    const id = await enrollment(); await seed(id);
    expect((await request(`${path}/${id}`, 'DELETE')).status).toBe(204);
    expect((await request(`${path}/${id}`, 'DELETE')).status).toBe(204);
    expect((await request(`${path}/${id}`, 'PUT', {})).status).toBe(401);
    expect((await request(`/api/v1/notification-settings/${id}`, 'PUT', {})).status).toBe(401);
    const fresh = await enrollment(); expect(fresh).not.toBe(id);
  });

  it('a DB error rolls back the entire deletion', async () => {
    const id = await enrollment(); await seed(id);
    await env.DB.prepare(`CREATE TRIGGER simulated_failure BEFORE DELETE ON notification_settings
      BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END`).run();
    await expect(deleteInstallationData(env.DB, id, await secretHash(testSecret))).rejects.toThrow();
    for (const table of ['installations', 'notification_settings', 'notification_history', 'installation_credentials']) {
      expect(await count(table, id)).toBe(1);
    }
  });

  it('delayed authorized writes and old Worker inserts cannot resurrect deleted data', async () => {
    const id = await enrollment(); await seed(id);
    const hash = await secretHash(testSecret);
    await deleteInstallationData(env.DB, id, hash);
    expect(await upsertInstallation(env.DB, { installationId: id, nx: 60, ny: 121,
      regionTopic: 'region', locationMode: 'GPS', timezone: 'Asia/Seoul' }, hash)).toBe(false);
    expect(await upsertNotificationSettings(env.DB, defaultNotificationSettings(id), hash)).toBe(false);
    await expect(upsertNotificationSettings(env.DB, defaultNotificationSettings(id))).rejects.toThrow();
    await env.DB.prepare('INSERT INTO notification_history VALUES (?, ?, ?, ?, ?)')
      .bind(id, 'date', 'late', 'now', 'late').run();
    expect(await count('notification_history', id)).toBe(0);
  });

  it('does not adopt an old ID or use a newly supplied FCM token as proof', async () => {
    expect((await request(`${path}/enroll`, 'POST', { legacyInstallationId: legacyId })).status).toBe(409);
    expect((await request(`${path}/${legacyId}`, 'PUT', { fcmToken: 'attacker-token' })).status).toBe(401);
    expect((await request(`${path}/${legacyId}`, 'DELETE')).status).toBe(401);
    expect((await request(`${path}/${noTokenId}/ownership-challenge`, 'POST', { requestId: '1'.repeat(64) })).status).toBe(409);
    expect(fcm.sendOwnershipChallenge).not.toHaveBeenCalled();
  });

  it('requires a short-lived proof delivered to the original token and bound to the new secret', async () => {
    const requestId = '1'.repeat(64);
    // Even a previous Worker changing the live token cannot redirect the proof.
    await env.DB.prepare('UPDATE installations SET fcm_token = ? WHERE installation_id = ?')
      .bind('changed-live-token', legacyId).run();
    const response = await request(`${path}/${legacyId}/ownership-challenge`, 'POST', { requestId });
    expect(response.status).toBe(200); expect(await response.json()).toEqual({ ok: true });
    const call = vi.mocked(fcm.sendOwnershipChallenge).mock.calls[0];
    expect(call[1]).toBe('original-delivery-token');
    const proof = call[2].proof;
    expect((await request(`${path}/${legacyId}/claim`, 'POST', { requestId, proof },
      { ...testAuthHeaders, Authorization: `Bearer ${'b'.repeat(64)}` })).status).toBe(403);
    expect((await request(`${path}/${legacyId}/claim`, 'POST', { requestId, proof: '0'.repeat(64) })).status).toBe(403);
    expect((await request(`${path}/${legacyId}/claim`, 'POST', { requestId, proof })).status).toBe(200);
    expect(await count('installation_ownership_challenges', legacyId)).toBe(0);
    expect(await count('legacy_installation_ownership', legacyId)).toBe(0);
    expect((await request(`${path}/${legacyId}`, 'DELETE')).status).toBe(204);
    expect((await request(`${path}/${legacyId}/claim`, 'POST', { requestId, proof })).status).toBe(403);
  });

  it('rate limits challenges and refuses expired proofs', async () => {
    const body = { requestId: '1'.repeat(64) };
    await request(`${path}/${legacyId}/ownership-challenge`, 'POST', body);
    expect((await request(`${path}/${legacyId}/ownership-challenge`, 'POST', body)).status).toBe(429);
    const proof = vi.mocked(fcm.sendOwnershipChallenge).mock.calls[0][2].proof;
    await env.DB.prepare('UPDATE installation_ownership_challenges SET expires_at = ?').bind('2000-01-01').run();
    expect((await request(`${path}/${legacyId}/claim`, 'POST', { ...body, proof })).status).toBe(403);
  });

  it('allows retry after a lost claim response using only the established credential', async () => {
    const body = { requestId: '1'.repeat(64) };
    await request(`${path}/${legacyId}/ownership-challenge`, 'POST', body);
    const proof = vi.mocked(fcm.sendOwnershipChallenge).mock.calls[0][2].proof;
    await request(`${path}/${legacyId}/claim`, 'POST', { ...body, proof });
    const response = await request(`${path}/enroll`, 'POST', { legacyInstallationId: legacyId });
    expect(await response.json()).toEqual({ installationId: legacyId });
  });
});
