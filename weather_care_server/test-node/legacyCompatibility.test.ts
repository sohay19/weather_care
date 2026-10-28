import { mkdtempSync, readdirSync, copyFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { app } from '../src/index';
import { nextForecastSnapshot } from '../src/api/weather';
import { nodeServerEnv } from '../src/node/runtime';
import { runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { saveCollectedCache } from '../src/database/collectedWeatherRepository';
import { secretHash } from '../src/security/installationAccess';
import { runLightningNotificationJob } from '../src/notification/lightningNotificationJob';
import type { FcmPayload } from '../src/notification/fcmClient';
import type { TodayWeatherResponse, WeatherSnapshot } from '../src/types';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import '../test/homeWidgetSnapshot.test';
import '../test/widgetSettings.test';

let database: SqliteD1Database;
const now = new Date('2026-10-22T09:10:00+09:00');
const headers = { Authorization: `Bearer ${'a'.repeat(64)}`, 'Content-Type': 'application/json' };
const id = 'legacy-device';

beforeEach(() => {
  database = new SqliteD1Database(':memory:');
  runSqliteMigrations(database);
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(now);
  vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('외부 호출 금지'));
});
afterEach(() => { database.close(); vi.restoreAllMocks(); vi.useRealTimers(); });

function environment() { return nodeServerEnv(database, {}); }
function request(path: string, body?: object, auth = headers) {
  return app.fetch(new Request(`http://localhost/api/v1/${path}`, {
    method: body ? 'PUT' : 'GET', headers: auth, body: body ? JSON.stringify(body) : undefined,
  }), environment());
}
function sample(hour: number, values: Partial<WeatherSnapshot> = {}): WeatherSnapshot {
  const at = `2026-10-22T${String(hour).padStart(2, '0')}:00:00+09:00`;
  return { observedAt: at, forecastAt: at, dataRole: 'FORECAST', provider: '기상청 단기예보',
    temperature: 17, humidity: 60, windSpeed: 2, skyCondition: '맑음', ...values };
}
async function seedWeather(hourly = [sample(9), sample(11), sample(10)]) {
  const env = environment();
  const forecast: WeatherForecast = { current: sample(9), hourly,
    daily: [{ date: '20261022', minTemperature: 12, maxTemperature: 20,
      skyCondition: '맑음', precipitationProbability: 0, precipitationAmount: 0 }],
    baseDate: '20261022', baseTime: '0800', dataSource: '기상청' };
  await saveCollectedCache(env.DB, {
    key: 'COLLECTED_REGION_60_127', type: 'COLLECTED_REGION', nx: 60, ny: 127, updatedAt: now,
    value: { forecast, environmental: { sources: {
      uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNAVAILABLE' },
      airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' },
    } } },
  });
  await saveCollectedCache(env.DB, {
    key: 'COLLECTED_WEEKLY_60_127', type: 'COLLECTED_WEEKLY', nx: 60, ny: 127, updatedAt: now,
    value: { forecast, midTermDays: [], observedDays: [], airQuality: [], collectedAt: now.toISOString() },
  });
}
async function seedInstallation() {
  database.sqlite.prepare('INSERT INTO installation_credentials VALUES(?,?,?)')
    .run(id, await secretHash('a'.repeat(64)), now.toISOString());
  database.sqlite.prepare(`INSERT INTO installations(installation_id,fcm_token,nx,ny,region_topic,
    location_mode,minimum_age_confirmed_at,age_policy_version,created_at,updated_at)
    VALUES(?,'synthetic-token',60,127,'weather_60_127','GPS',?,1,?,?)`)
    .run(id, now.toISOString(), now.toISOString(), now.toISOString());
  database.sqlite.prepare('INSERT INTO notification_settings(installation_id,created_at,updated_at) VALUES(?,?,?)')
    .run(id, now.toISOString(), now.toISOString());
}
function support() {
  return database.sqlite.prepare('SELECT lightning_supported AS supported, lightning_enabled AS enabled FROM notification_settings')
    .get() as { supported: number; enabled: number };
}

describe('기존 날씨·위젯 응답 계약', () => {
  it.each(['main', 'today'])('%s는 가장 가까운 미래 예보를 별도 필드로 유지한다', async (route) => {
    await seedWeather();
    const response = await request(`weather/${route}?nx=60&ny=127`);
    expect(response.status).toBe(200);
    const data = await response.json() as TodayWeatherResponse;
    expect(data.nextForecast).toMatchObject({ forecastAt: '2026-10-22T10:00:00+09:00', temperature: 17,
      humidity: 60, windSpeed: 2 });
    expect(data.current).toBeDefined();
    expect(globalThis.fetch).not.toHaveBeenCalled();
  });

  it.each(['main', 'today'])('%s는 미래 슬롯이 없을 때 기존처럼 현재 예보를 보존한다', async (route) => {
    await seedWeather([]);
    const response = await request(`weather/${route}?nx=60&ny=127`);
    expect(response.status).toBe(200);
    expect((await response.json() as TodayWeatherResponse).nextForecast)
      .toMatchObject({ temperature: 17, forecastAt: '2026-10-22T09:00:00+09:00' });
  });

  it('과거·현재·잘못된 시각은 미래 예보로 고르지 않고 한국 날짜별 대기질을 연결한다', () => {
    const snapshots = [sample(9), sample(23), sample(10), { observedAt: 'invalid' }];
    expect(nextForecastSnapshot(snapshots, now, [{ date: '20261022', pm25Grade: '나쁨' }]))
      .toMatchObject({ forecastAt: sample(10).forecastAt, pm25ForecastGrade: '나쁨' });
    expect(nextForecastSnapshot(snapshots, new Date('2026-10-22T23:00:00+09:00'))).toBeUndefined();
    expect(snapshots[2]).not.toHaveProperty('pm25ForecastGrade');
  });

  it.each(['', '&recommendationCatalog=PREPARATION_15', '&recommendationCatalog=UNKNOWN'])
  ('기존 위젯 URL %s에는 새 종류를 섞지 않는다', async (catalog) => {
    await seedWeather([sample(9), sample(10)]);
    const response = await request(`weather/widget?nx=60&ny=127${catalog}`);
    expect(response.status).toBe(200);
    const widget = await response.json() as { schemaVersion: number; preparationCatalog: { type: string }[];
      briefingTimeline: { recommendedItems: string[] }[]; nextTemperature: string };
    expect(widget.schemaVersion).toBe(3);
    expect(widget.nextTemperature).toBe('17°');
    const types = [...widget.preparationCatalog.map((item) => item.type),
      ...widget.briefingTimeline.flatMap((item) => item.recommendedItems)];
    expect(types).not.toContain('LIGHT_OUTERWEAR');
    expect(types).not.toContain('SUN_HAT');
    expect(types).not.toContain('SLIP_RESISTANT_SHOES');
  });

  it('새 위젯은 지원 카탈로그를 명시하면 18종 정책을 계속 사용한다', async () => {
    await seedWeather([sample(9), sample(10)]);
    const response = await request('weather/widget?nx=60&ny=127&recommendationCatalog=PREPARATION_18');
    expect(response.status).toBe(200);
    const widget = await response.json() as { preparationCatalog: { type: string }[] };
    expect(widget.preparationCatalog.map((item) => item.type)).toContain('LIGHT_OUTERWEAR');
    expect(globalThis.fetch).not.toHaveBeenCalled();
  });
});

describe('구버전 설치와 낙뢰 알림 지원 확인', () => {
  it.each(['notification-settings/', 'installations/'])('기존 %s 요청과 인증·위치·알림 시각을 유지한다', async (prefix) => {
    await seedInstallation();
    const path = prefix === 'installations/' ? `${prefix}${id}/notification-settings` : `${prefix}${id}`;
    expect((await request(path, { notificationTime: '06:35', umbrellaEnabled: false })).status).toBe(200);
    expect(support()).toEqual({ supported: 0, enabled: 1 });
    expect(await (await request(`notification-settings?installationId=${id}`)).json())
      .toMatchObject({ notificationTime: '06:35', umbrellaEnabled: false });
    expect((await request(`installations/${id}?nx=60&ny=127`, { minimumAgeConfirmed: true, agePolicyVersion: 1,
      fcmToken: 'synthetic-token', locationMode: 'GPS' })).status).toBe(200);
    expect(database.sqlite.prepare('SELECT fcm_token,background_location_revision FROM installations').get())
      .toEqual({ fcm_token: 'synthetic-token', background_location_revision: null });
    expect(globalThis.fetch).not.toHaveBeenCalled();
  });

  it.each(['notification-settings/legacy-device', 'installations/legacy-device/notification-settings'])
  ('%s는 낙뢰 설정을 명시한 인증된 앱만 지원으로 기록한다', async (path) => {
    await seedInstallation();
    expect((await request(path, { lightningEnabled: true }, { ...headers, Authorization: '' })).status).toBe(401);
    expect(support().supported).toBe(0);
    expect((await request(path, { lightningEnabled: true })).status).toBe(200);
    expect(support()).toEqual({ supported: 1, enabled: 1 });
    expect((await request(path, { notificationTime: '22:35' })).status).toBe(200);
    expect(support()).toEqual({ supported: 1, enabled: 1 });
  });

  it('실제 새 관측이 있어도 구버전에는 보내지 않고 지원 앱의 개별·전체 끄기를 따른다', async () => {
    await seedInstallation();
    database.sqlite.prepare('INSERT INTO lightning_collection_state VALUES(1,?,?,?)')
      .run(now.toISOString(), '2026-10-22T00:10:00Z', 'AVAILABLE');
    database.sqlite.prepare('INSERT INTO grid_extra_snapshots VALUES(?,?,?,?,?)')
      .run('KMA_LIGHTNING', 'ALL', '2026-10-22T00:00:00Z', JSON.stringify({ events: [
        { latitude: 37.5665, longitude: 126.978, observedAt: '202610220905' },
      ] }), now.toISOString());
    const sent: FcmPayload[] = [];
    const dependencies = { now: () => now, sender: async (_env: unknown, payloads: FcmPayload[]) => {
      sent.push(...payloads);
      return payloads.map((item) => ({ token: item.token, notificationKey: item.notificationKey,
        success: true, unregistered: false, status: 200 }));
    } };
    const run = () => runLightningNotificationJob(environment(), dependencies);
    await run(); expect(sent).toEqual([]);
    await request(`notification-settings/${id}`, { lightningEnabled: false });
    await run(); expect(sent).toEqual([]);
    await request(`notification-settings/${id}`, { lightningEnabled: true, notificationEnabled: false });
    await run(); expect(sent).toEqual([]);
    await request(`notification-settings/${id}`, { notificationEnabled: true });
    await run(); expect(sent).toHaveLength(1);
    await run(); expect(sent).toHaveLength(1);
    expect(globalThis.fetch).not.toHaveBeenCalled();
  });
});

describe('운영 DB 대신 합성 구버전 DB로 검증하는 마이그레이션', () => {
  it.each([14, 17, 19])('00%s에서 설치·인증·설정·이력·캐시를 유지하며 0021까지 한 번만 적용한다', async (version) => {
    database.close();
    database = new SqliteD1Database(':memory:');
    const directory = mkdtempSync(join(tmpdir(), 'weather-care-legacy-migrations-'));
    try {
      for (const name of readdirSync('migrations').filter((name) =>
        name.endsWith('.sql') && Number(name.slice(0, 4)) <= version)) {
        copyFileSync(resolve('migrations', name), join(directory, name));
      }
      expect(runSqliteMigrations(database, directory)).toHaveLength(version);
      await seedInstallation();
      database.sqlite.prepare("UPDATE notification_settings SET notification_time='22:35', umbrella_enabled=0").run();
      database.sqlite.prepare('INSERT INTO notification_history VALUES(?,?,?,?,?)')
        .run(id, '2026-10-22', 'MORNING_BRIEF', now.toISOString(), 'synthetic-history');
      await seedWeather();
      const tables = ['installations', 'installation_credentials', 'notification_settings', 'notification_history', 'weather_cache'];
      const before = tables.map((table) => ({ table,
        columns: database.sqlite.pragma(`table_info(${table})`).map((column: any) => column.name as string),
        rows: database.sqlite.prepare(`SELECT * FROM ${table} ORDER BY 1`).all(),
      }));
      const pending = ['0015_grid_extra_snapshots.sql', '0016_lightning_alerts.sql',
        '0017_background_location.sql', '0018_lightning_client_support.sql', '0019_pipe_freeze_alert.sql',
        '0020_commute_notification_schedule.sql', '0021_notification_regions.sql'];
      expect(runSqliteMigrations(database)).toEqual(pending.filter((name) => Number(name.slice(0, 4)) > version));
      expect(runSqliteMigrations(database)).toEqual([]);
      for (const { table, columns, rows } of before) {
        expect(database.sqlite.prepare(`SELECT ${columns.join(',')} FROM ${table} ORDER BY 1`).all()).toEqual(rows);
      }
      expect(support()).toEqual({ supported: 0, enabled: 1 });
      expect(database.sqlite.prepare('SELECT pipe_freeze_enabled AS enabled FROM notification_settings').get()).toEqual({enabled:0});
      expect(database.sqlite.prepare(`SELECT commute_to_work_start AS start, commute_to_work_end AS end,
        commute_from_work_start AS returnStart, commute_from_work_end AS returnEnd
        FROM notification_settings`).get()).toEqual({ start: '07:00', end: '10:00', returnStart: '17:00', returnEnd: '20:00' });
      expect((await request(`notification-settings/${id}`, { notificationTime: '06:35' })).status).toBe(200);
      expect(support().supported).toBe(0);
      expect(database.sqlite.pragma('foreign_key_check')).toEqual([]);
    } finally { rmSync(directory, { recursive: true, force: true }); }
  });
});
