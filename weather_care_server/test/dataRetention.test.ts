import { env } from 'cloudflare:test';
import { beforeEach, describe, expect, it, vi, afterEach } from 'vitest';
import { Hono } from 'hono';
import { installationExpirySql, historyExpirySql, recordInstallationActivity, runDataRetentionJob } from '../src/database/dataRetention';
import { installationOwnerHash, secretHash } from '../src/security/installationAccess';
import { runRecommendationNotificationJobFromCron } from '../src/cron/jobs';
import ownership from '../src/api/installationOwnership';
import type { ServerEnv } from '../src/types';
import { testSecret, testAuthHeaders } from './installationAuthFixture';
import m1 from '../migrations/0001_init.sql?raw';
import m2 from '../migrations/0002_notification_preferences.sql?raw';
import m3 from '../migrations/0003_precise_precipitation_location.sql?raw';
import m4 from '../migrations/0004_official_warning_state.sql?raw';
import m5 from '../migrations/0005_road_ice_state.sql?raw';
import m6 from '../migrations/0006_road_control_state.sql?raw';
import m7 from '../migrations/0007_installation_access.sql?raw';
import m8 from '../migrations/0008_data_retention.sql?raw';
import m9 from '../migrations/0009_minimum_age_policy.sql?raw';
import m10 from '../migrations/0010_weekly_forecast_records.sql?raw';
import m11 from '../migrations/0011_central_weather_collection.sql?raw';
import recoveryReset from '../ops/recovery-reset.sql?raw';
import recoveryVerify from '../ops/recovery-verify.sql?raw';

const now = new Date('2026-09-11T03:00:00.000Z');
const old = '2025-09-11T03:00:00.000Z';
const id = 'wc_retention_synthetic_install_01';
const other = 'wc_retention_synthetic_install_02';
const tables = ['installations', 'notification_settings', 'notification_history',
  'installation_warning_state', 'installation_credentials', 'installation_activity',
  'installation_ownership_challenges', 'legacy_installation_ownership'];
const app = new Hono<{ Bindings: ServerEnv }>();
app.route('/api/v1/installations', ownership);
const apply = (sql: string) => env.DB.exec(sql.replace(/--[^\n]*/g, '').replace(/\r?\n/g, ' '));
async function count(table: string, target = id) {
  return (await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${table} WHERE installation_id = ?`)
    .bind(target).first<{ n: number }>())!.n;
}
async function seed(target: string, activeAt: string) {
  await env.DB.batch([
    env.DB.prepare('INSERT INTO installation_credentials VALUES (?, ?, ?)')
      .bind(target, await secretHash(testSecret), activeAt),
    env.DB.prepare(`INSERT INTO installations (installation_id, fcm_token, nx, ny, region_topic,
      location_mode, timezone, created_at, updated_at) VALUES (?, NULL, 60, 121, 'region', 'MANUAL',
      'Asia/Seoul', ?, ?)`).bind(target, activeAt, now.toISOString()),
    env.DB.prepare('INSERT INTO installation_activity VALUES (?, ?)').bind(target, activeAt),
    env.DB.prepare('INSERT INTO notification_settings (installation_id, created_at, updated_at) VALUES (?, ?, ?)')
      .bind(target, activeAt, activeAt),
    env.DB.prepare('INSERT INTO notification_history VALUES (?, ?, ?, ?, ?)')
      .bind(target, '2026-09-11', 'TEST', now.toISOString(), 'synthetic'),
    env.DB.prepare('INSERT INTO installation_warning_state VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
      .bind(target, 'R', '호우', '2', '경보', '테스트', activeAt, activeAt),
    env.DB.prepare('INSERT INTO legacy_installation_ownership VALUES (?, NULL)').bind(target),
    env.DB.prepare('INSERT INTO installation_ownership_challenges VALUES (?, ?, ?, ?, ?, ?)')
      .bind(target, 'request', 'hash', 'proof', activeAt, activeAt),
  ]);
}

beforeEach(async () => {
  // This suite uses only an isolated local test binding, never production D1.
  await env.DB.exec('DROP TABLE IF EXISTS installation_activity; DROP TABLE IF EXISTS installation_ownership_challenges; DROP TABLE IF EXISTS legacy_installation_ownership; DROP TABLE IF EXISTS installation_warning_state; DROP TABLE IF EXISTS notification_history; DROP TABLE IF EXISTS notification_settings; DROP TABLE IF EXISTS installations; DROP TABLE IF EXISTS installation_credentials; DROP TABLE IF EXISTS active_regions; DROP TABLE IF EXISTS weather_cache; DROP TABLE IF EXISTS daily_weather_snapshots; DROP TABLE IF EXISTS weekly_forecast_records;');
  for (const sql of [m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11]) await apply(sql);
});
afterEach(() => vi.restoreAllMocks());

describe('one-year data retention', () => {
  it('clears restored personal data regardless of age, preserves shared weather, and is repeatable', async () => {
    await seed(id, old);
    await seed(other, now.toISOString());
    await env.DB.exec("INSERT INTO active_regions VALUES ('r','t',60,121,2,'now'); INSERT INTO weather_cache VALUES ('shared','r',60,121,'weather','{}','AVAILABLE','now'); INSERT INTO daily_weather_snapshots (region_id, observation_date) VALUES ('r','2026-09-11'); INSERT INTO weekly_forecast_records VALUES ('r','2026-09-11','{}','KMA_SHORT_TERM',NULL,'now');");
    const checks = recoveryVerify.replace(/--[^\n]*/g, '').split(';').map(s => s.trim()).filter(Boolean);
    expect((await env.DB.prepare(checks[0]).all<{remaining: number}>()).results.some(r => r.remaining > 0)).toBe(true);
    for (let attempt = 0; attempt < 2; attempt++) {
      await apply(recoveryReset);
      for (const table of tables) {
        expect(await count(table, id)).toBe(0);
        expect(await count(table, other)).toBe(0);
      }
      for (const check of checks.slice(0, 9)) {
        expect(await env.DB.prepare(check).first('remaining')).toBe(0);
      }
      expect((await env.DB.prepare(checks[9]).all()).results).toEqual([]);
      expect((await env.DB.prepare(checks[10]).all()).results).toEqual([]);
      expect(await env.DB.prepare('SELECT COUNT(*) AS n FROM weather_cache').first('n')).toBe(1);
      expect(await env.DB.prepare('SELECT COUNT(*) AS n FROM daily_weather_snapshots').first('n')).toBe(1);
      expect(await env.DB.prepare('SELECT COUNT(*) AS n FROM weekly_forecast_records').first('n')).toBe(1);
    }
    await env.DB.exec('CREATE TABLE recovery_unreviewed_personal_data (id TEXT);');
    try {
      expect((await env.DB.prepare(checks[9]).all()).results).toContainEqual({ unreviewed_table: 'recovery_unreviewed_personal_data' });
    } finally { await env.DB.exec('DROP TABLE recovery_unreviewed_personal_data;'); }
  });
  it('expires at exactly one year and deletes all related data, but no active/shared data', async () => {
    await seed(id, old);
    await seed(other, '2025-09-11T03:00:00.001Z');
    await env.DB.prepare(`INSERT INTO weather_cache VALUES ('shared', 'region', 60, 121, 'weather', '{}', 'AVAILABLE', 'now')`).run();
    expect(await runDataRetentionJob(env.DB, new Date(now.getTime() - 1))).toEqual({ installations: 0, notificationHistory: 0 });
    expect(await runDataRetentionJob(env.DB, now)).toEqual({ installations: 1, notificationHistory: 1 });
    for (const table of tables) {
      expect(await count(table)).toBe(0);
      expect(await count(table, other)).toBe(1);
    }
    expect(await env.DB.prepare('SELECT 1 FROM weather_cache').first()).not.toBeNull();
    expect(await runDataRetentionJob(env.DB, now)).toEqual({ installations: 0, notificationHistory: 0 });
  });

  it('keeps a renewed installation and never lets a late request recreate a deleted marker', async () => {
    await seed(id, old);
    const hash = await secretHash(testSecret);
    await recordInstallationActivity(env.DB, id, hash, now);
    await recordInstallationActivity(env.DB, id, hash, new Date(old)); // late earlier request
    await runDataRetentionJob(env.DB, now);
    expect(await count('installations')).toBe(1);
    await runDataRetentionJob(env.DB, new Date('2027-09-11T03:00:00Z'));
    await recordInstallationActivity(env.DB, id, hash, now);
    for (const table of tables) expect(await count(table)).toBe(0);
  });

  it('records authenticated app use, not incorrect credentials or scheduler updated_at', async () => {
    await seed(id, old);
    await installationOwnerHash(env.DB, id, `Bearer ${'b'.repeat(64)}`);
    expect(await env.DB.prepare('SELECT last_active_at FROM installation_activity WHERE installation_id = ?')
      .bind(id).first('last_active_at')).toBe(old);
    await installationOwnerHash(env.DB, id, testAuthHeaders.Authorization);
    expect(await env.DB.prepare('SELECT last_active_at FROM installation_activity WHERE installation_id = ?')
      .bind(id).first('last_active_at')).not.toBe(old);
  });

  it.each([
    ['2024-02-29T00:00:00+09:00', '2025-02-28T00:00:00+09:00'],
    ['2023-03-01T00:00:00+09:00', '2024-03-01T00:00:00+09:00'],
    ['2024-02-28T23:59:59.999+09:00', '2025-02-28T23:59:59.999+09:00'],
  ])('uses a Korean calendar year including leap dates: %s', async (start, end) => {
    await seed(id, start);
    await env.DB.prepare('UPDATE notification_history SET sent_at = ?').bind(start).run();
    for (const [table, expression] of [['installation_activity', installationExpirySql], ['notification_history', historyExpirySql]]) {
      const due = async (time: Date) => (await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${table} WHERE ${expression} <= julianday(?)`)
        .bind(time.toISOString()).first<{ n: number }>())!.n;
      expect(await due(new Date(new Date(end).getTime() - 1))).toBe(0);
      expect(await due(new Date(end))).toBe(1);
    }
  });

  it('expires history by sent_at rather than target_date, regardless of timezone/string form', async () => {
    await seed(id, now.toISOString());
    for (const [key, date] of [['oldZ', old], ['oldKST', '2025-09-11T12:00:00+09:00'],
      ['new', '2025-09-11T03:00:00.001Z'], ['invalid', 'unknown']]) {
      await env.DB.prepare('INSERT INTO notification_history VALUES (?, ?, ?, ?, NULL)')
        .bind(id, '2099-01-01', key, date).run();
    }
    expect(await runDataRetentionJob(env.DB, now)).toEqual({ installations: 0, notificationHistory: 2 });
    expect(await count('notification_history')).toBe(3);
    expect(await count('installations')).toBe(1);
  });

  it('rolls back all deletes on a trigger error and safely retries', async () => {
    await seed(id, old);
    await env.DB.prepare(`CREATE TRIGGER fail_retention BEFORE DELETE ON notification_settings
      BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END`).run();
    await expect(runDataRetentionJob(env.DB, now)).rejects.toThrow();
    for (const table of tables) expect(await count(table)).toBe(1);
    await env.DB.prepare('DROP TRIGGER fail_retention').run();
    await runDataRetentionJob(env.DB, now);
    for (const table of tables) expect(await count(table)).toBe(0);
  });

  it('bounds cleanup batches and handles settings-only/orphan markers without skipping related rows', async () => {
    await seed(id, old);
    await env.DB.prepare('DELETE FROM installations WHERE installation_id = ?').bind(id).run();
    await env.DB.batch(Array.from({ length: 100 }, (_, i) =>
      env.DB.prepare('INSERT INTO installation_activity VALUES (?, ?)').bind(`synthetic-${i}`, old)));
    await runDataRetentionJob(env.DB, now);
    expect((await env.DB.prepare('SELECT COUNT(*) AS n FROM installation_activity').first<{ n: number }>())!.n).toBe(1);
    await runDataRetentionJob(env.DB, now);
    for (const table of tables) expect(await count(table)).toBe(0);
    expect(await env.DB.prepare('SELECT 1 FROM installation_activity').first()).toBeNull();
  });

  it('rejects invalid run time before writes', async () => {
    await seed(id, old);
    await expect(runDataRetentionJob(env.DB, new Date('invalid'))).rejects.toThrow();
    expect(await count('installations')).toBe(1);
  });

  it('uses execution time for cleanup even when the cron event is delayed', async () => {
    await seed(id, '2000-01-01T00:00:00Z');
    await runRecommendationNotificationJobFromCron(env, new Date('2000-01-02').getTime());
    for (const table of tables) expect(await count(table)).toBe(0);
  });

  it('reports missing registration after expiry, but never discloses an existing registration to a wrong owner', async () => {
    await seed(id, old);
    const status = (headers = testAuthHeaders) => app.request(`/api/v1/installations/${id}/status`, { headers }, env);
    expect((await status({ ...testAuthHeaders, Authorization: `Bearer ${'b'.repeat(64)}` })).status).toBe(401);
    await runDataRetentionJob(env.DB, now);
    const response = await status();
    expect(response.status).toBe(410);
    expect(await response.json()).toEqual({ error: 'INSTALLATION_GONE' });
    expect(await count('installation_credentials')).toBe(0);
  });

  it('backfills old installations from rollout time rather than scheduler updates or guessed past use', async () => {
    await env.DB.prepare('DROP TRIGGER credential_delete_clears_activity').run();
    await env.DB.prepare('DROP TABLE installation_activity').run();
    await env.DB.prepare('DROP INDEX notification_history_expiry').run();
    await env.DB.prepare('INSERT INTO installation_credentials VALUES (?, ?, ?)')
      .bind(id, await secretHash(testSecret), '2000-01-01').run();
    await apply(m8);
    const activity = await env.DB.prepare('SELECT last_active_at FROM installation_activity WHERE installation_id = ?')
      .bind(id).first<string>('last_active_at');
    expect(Math.abs(Date.now() - Date.parse(activity!))).toBeLessThan(5000);
    await runDataRetentionJob(env.DB);
    expect(await count('installation_credentials')).toBe(1);
  });
});
