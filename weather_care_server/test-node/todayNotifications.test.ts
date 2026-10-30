import { resolve } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { app } from '../src/index';
import { defaultNotificationSettings, getNotificationSettings, upsertNotificationSettings } from '../src/database/notificationSettingsRepository';
import { nodeServerEnv } from '../src/node/runtime';
import { runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { runRecommendationNotificationJob } from '../src/notification/notificationScheduler';
import type { FcmPayload } from '../src/notification/fcmClient';
import { buildWeatherBriefResult } from '../src/presentation/weatherBrief';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import { secretHash } from '../src/security/installationAccess';
import type { NotificationSettings, WeatherSnapshot } from '../src/types';

const now = new Date('2026-10-30T07:00:00+09:00');
const fields = ['todayVisibilityEnabled', 'todayOzoneEnabled', 'todayWindEnabled',
  'todayHumidityEnabled', 'todayApparentTemperatureEnabled'] as const;
const allOff = Object.fromEntries(fields.map((field) => [field, false]));
const headers = { Authorization: `Bearer ${'a'.repeat(64)}`, 'Content-Type': 'application/json' };
let database: SqliteD1Database;

beforeEach(async () => {
  database = new SqliteD1Database(':memory:');
  runSqliteMigrations(database);
  vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('외부 요청 금지'));
  database.sqlite.prepare('INSERT INTO installation_credentials VALUES (?, ?, ?)')
    .run('today-test', await secretHash('a'.repeat(64)), now.toISOString());
  database.sqlite.prepare(`INSERT INTO installations
    (installation_id, fcm_token, nx, ny, region_topic, location_mode,
     minimum_age_confirmed_at, age_policy_version, created_at, updated_at)
    VALUES ('today-test', 'synthetic-token', 60, 127, 'test', 'GPS', ?, 1, ?, ?)`)
    .run(now.toISOString(), now.toISOString(), now.toISOString());
  await upsertNotificationSettings(database, defaultNotificationSettings('today-test'));
});
afterEach(() => { database.close(); vi.restoreAllMocks(); });

function forecast(values: Partial<WeatherSnapshot>): WeatherForecast {
  const current: WeatherSnapshot = {
    observedAt: now.toISOString(), forecastAt: now.toISOString(), dataRole: 'FORECAST', ...values,
  };
  return { current, hourly: [current], daily: [], baseDate: '20261030', baseTime: '0500', dataSource: '합성 자료' };
}

async function update(values: Partial<NotificationSettings>) {
  await upsertNotificationSettings(database, {
    ...await getNotificationSettings(database, 'today-test'), ...values,
  });
}

async function run(input: WeatherForecast, at = now) {
  const sent: FcmPayload[] = [];
  await runRecommendationNotificationJob(nodeServerEnv(database, {}), {
    now: at, retentionNow: at, forecastLoader: async () => input,
    warningLoader: async () => [],
    precipitationLoader: async () => undefined, roadIceLoader: async () => undefined,
    roadControlLoader: async () => undefined,
    sender: async (_env, payloads) => {
      sent.push(...payloads);
      return payloads.map((item) => ({ token: item.token, notificationKey: item.notificationKey,
        success: true, unregistered: false, status: 200 }));
    },
  });
  return sent;
}

describe('Today 정기 알림 항목 제어', () => {
  it.each([[true, true], [true, false], [false, true], [false, false]])(
    '챙겨요 %s·Today %s는 각 그룹의 요약만 허용한다', async (carry, today) => {
      const response = await app.fetch(new Request('http://localhost/api/v1/notification-settings/today-test', {
        method: 'PUT', headers, body: JSON.stringify({ carryNotificationEnabled: carry, todayNotificationEnabled: today }),
      }), nodeServerEnv(database, {}));
      expect(response.status).toBe(200);
      const settings = await getNotificationSettings(database, 'today-test');
      expect(settings.dailyWeatherEnabled).toBe(carry || today);
      const sent = await run(forecast({ precipitationType: 'RAIN', precipitationProbability: 80, windSpeed: 12 }));
      expect(sent).toHaveLength(carry || today ? 1 : 0);
      if (carry) expect(sent[0].body).toContain('우산');
      else if (today) {
        expect(sent[0].body).toContain('바람');
        expect(sent[0].body).not.toContain('우산');
      }
    });

  it.each(['/notification-settings/today-test', '/installations/today-test/notification-settings'])(
    '%s는 독립 그룹 OFF와 구버전 전체 스위치를 보존한다', async (path) => {
      const request = (body: object) => app.fetch(new Request('http://localhost/api/v1' + path, {
        method: 'PUT', headers, body: JSON.stringify(body),
      }), nodeServerEnv(database, {}));
      expect((await request({ carryNotificationEnabled: false, todayNotificationEnabled: true })).status).toBe(200);
      expect((await request({ notificationTime: '07:00' })).status).toBe(200);
      expect(await getNotificationSettings(database, 'today-test')).toMatchObject({
        carryNotificationEnabled: false, todayNotificationEnabled: true, dailyWeatherEnabled: true,
      });
      expect((await request({ dailyWeatherEnabled: false })).status).toBe(200);
      expect(await run(forecast({ windSpeed: 12 }))).toEqual([]);
      expect((await request({ dailyWeatherEnabled: true })).status).toBe(200);
      const sent = await run(forecast({ precipitationType: 'RAIN', precipitationProbability: 80, windSpeed: 12 }));
      expect(sent).toHaveLength(1);
      expect(sent[0].body).toContain('바람');
      expect(sent[0].body).not.toContain('우산');
    });

  it('Today 전체 OFF는 정보만 있는 알림을 끄고 챙겨요 전체 OFF는 준비물만 있는 알림을 끈다', async () => {
    await update({ carryNotificationEnabled: true, todayNotificationEnabled: false });
    expect(await run(forecast({ windSpeed: 12 }))).toEqual([]);
    await update({ carryNotificationEnabled: false, todayNotificationEnabled: true });
    expect(await run(forecast({ precipitationType: 'RAIN', precipitationProbability: 80 }))).toEqual([]);
  });
  it('동파 필드 없는 새 저장은 ON이며 기존 OFF는 기본값으로 덮어쓰지 않는다', async () => {
    database.sqlite.exec('DELETE FROM notification_settings');
    const settings = defaultNotificationSettings('today-test');
    delete settings.pipeFreezeEnabled;
    await upsertNotificationSettings(database, settings);
    expect((await getNotificationSettings(database, 'today-test')).pipeFreezeEnabled).toBe(true);
    await update({ pipeFreezeEnabled: false });
    await upsertNotificationSettings(database, settings);
    expect((await getNotificationSettings(database, 'today-test')).pipeFreezeEnabled).toBe(false);
  });
  it.each([
    ['todayVisibilityEnabled', { visibilityMeters: 500 }, 'VISIBILITY'],
    ['todayVisibilityEnabled', { visibilityMeters: 25000 }, 'CLEAR_COMFORTABLE'],
    ['todayOzoneEnabled', { ozone: 0.1 }, 'OZONE'],
    ['todayWindEnabled', { windSpeed: 12 }, 'WIND'],
    ['todayHumidityEnabled', { humidity: 90 }, 'HUMIDITY_HIGH'],
    ['todayApparentTemperatureEnabled', { apparentTemperature: 22, temperature: 22 }, 'THERMAL_COMFORTABLE'],
  ] as const)('%s로 %s 안내만 끄고 앱 브리핑은 유지한다', async (field, values, scene) => {
    const input = forecast(values);
    await update({ ...allOff, [field]: true });
    expect((await run(input)).map((item) => item.notificationKey)).toEqual(['MORNING_BRIEF']);
    database.sqlite.exec('DELETE FROM notification_history');
    await update({ [field]: false });
    expect(await run(input)).toEqual([]);
    expect(buildWeatherBriefResult(input, { now }).scene).toBe(scene);
  });

  it('높은 우선순위 항목을 끄면 다음 허용 항목으로 안내한다', async () => {
    await update({ todayWindEnabled: false });
    const sent = await run(forecast({ windSpeed: 12, humidity: 90 }));
    expect(sent).toHaveLength(1);
    expect(sent[0].body).toContain('눅눅');
    expect(sent[0].body).not.toContain('바람');
  });

  it('Today를 모두 꺼도 준비물과 추위·더위 안내는 유지한다', async () => {
    await update(allOff);
    const input = forecast({ precipitationType: 'RAIN', precipitationProbability: 80, temperature: 10 });
    const sent = await run(input);
    expect(sent).toHaveLength(1);
    expect(sent[0].body).toContain('우산');
  });

  it('체감온도 Today OFF가 더위 준비물이나 건조도 준비물을 끄지 않는다', async () => {
    await update({ ...allOff, drynessEnabled: true });
    const sent = await run(forecast({ temperature: 34, kmaApparentTemperature: 34, humidity: 20 }));
    expect(sent).toHaveLength(1);
    expect(sent[0].body).toContain('휴대용 선풍기');
    expect(sent[0].body).toContain('휴대용 가습기');
  });

  it('설정한 공통 시각에 하루 한 번 보내며 정기 알림 OFF를 따른다', async () => {
    await update({ notificationTime: '07:35' });
    const input = forecast({ windSpeed: 12 });
    expect(await run(input, new Date('2026-10-30T07:30:00+09:00'))).toEqual([]);
    expect(await run(input, new Date('2026-10-30T07:40:00+09:00'))).toHaveLength(1);
    expect(await run(input, new Date('2026-10-30T07:40:00+09:00'))).toEqual([]);
    database.sqlite.exec('DELETE FROM notification_history');
    await update({ dailyWeatherEnabled: false });
    expect(await run(input, new Date('2026-10-30T07:40:00+09:00'))).toEqual([]);
  });

  it.each(['/notification-settings/today-test', '/installations/today-test/notification-settings'])(
    '%s의 기본 ON·독립 OFF·구버전 부분 갱신 보존을 확인한다', async (path) => {
      const environment = nodeServerEnv(database, {});
      const request = (body: object) => app.fetch(new Request('http://localhost/api/v1' + path, {
        method: 'PUT', headers, body: JSON.stringify(body),
      }), environment);
      const initial = await getNotificationSettings(database, 'today-test');
      expect(fields.every((field) => initial[field])).toBe(true);
      for (const field of [...fields, 'snowPreparationEnabled', 'uvPreparationEnabled', 'pollenEnabled', 'blackIceEnabled'] as const) {
        expect((await request({ [field]: false })).status).toBe(200);
        expect((await getNotificationSettings(database, 'today-test'))[field]).toBe(false);
      }
      expect((await request({ notificationTime: '08:15' })).status).toBe(200);
      const loaded = await getNotificationSettings(database, 'today-test');
      expect(fields.every((field) => loaded[field] === false)).toBe(true);
      expect(loaded).toMatchObject({ snowPreparationEnabled: false, uvPreparationEnabled: false,
        pollenEnabled: false, blackIceEnabled: false });
      expect(loaded.commuteToWorkStart).toBe('07:00');
      for (const field of fields) expect((await request({ [field]: 'false' })).status).toBe(400);
    });

  it('실제 Node 사용자 DB 마이그레이션에서도 기본 ON과 재적용 안전성을 유지한다', () => {
    const users = new SqliteD1Database(':memory:');
    try {
      runSqliteMigrations(users, resolve('node-migrations/users'));
      expect(runSqliteMigrations(users, resolve('node-migrations/users'))).toEqual([]);
      const columns = users.sqlite.prepare('PRAGMA table_info(notification_settings)').all() as Array<{ name: string; dflt_value: string }>;
      const items = columns.filter((column) => column.name.startsWith('today_') && column.name !== 'today_notification_enabled');
      expect(items).toHaveLength(5);
      expect(items.every((column) => column.dflt_value === '1')).toBe(true);
    } finally { users.close(); }
  });
});
