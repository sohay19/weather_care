import { mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { app } from '../src/index';
import { loadCollectionTargets } from '../src/collection/collectionTargets';
import { runWeatherCollectionJob } from '../src/collection/weatherCollectionJob';
import { saveCollectedCache } from '../src/database/collectedWeatherRepository';
import { weatherDatabase } from '../src/database/weatherDatabase';
import { createNodeRuntime, type NodeRuntime } from '../src/node/runtime';
import { splitLegacyDatabases, type SplitDatabasePaths } from '../src/node/splitDatabases';
import { runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { runLightningNotificationJob } from '../src/notification/lightningNotificationJob';
import { runRecommendationNotificationJob } from '../src/notification/notificationScheduler';
import { CORE_COLLECTION_CRON, GRID_LIGHTNING_CRON, runScheduledJobs } from '../src/cron/jobs';
import type { FcmPayload } from '../src/notification/fcmClient';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import type { TodayWeatherResponse } from '../src/types';

const cleanup: Array<() => void> = [];
const execute = promisify(execFile);
const now = new Date('2026-10-23T09:10:00+09:00');
afterEach(() => {
  vi.restoreAllMocks();
  vi.useRealTimers();
  while (cleanup.length) cleanup.pop()!();
});

function directory(): string {
  const path = mkdtempSync(join(tmpdir(), 'weather-care-shared-'));
  cleanup.push(() => rmSync(path, { recursive: true, force: true }));
  return path;
}

function runtime(root: string, kind: string, extra: NodeJS.ProcessEnv = {}): NodeRuntime {
  const value = createNodeRuntime({ environment: {
    NODE_DATABASE_PATH: join(root, `${kind}.sqlite`),
    NODE_WEATHER_DATABASE_PATH: join(root, 'weather.sqlite'),
    ...extra,
  } });
  cleanup.push(() => value.close());
  return value;
}

function seedUser(db: SqliteD1Database, token: string, nx = 60): void {
  const stamp = now.toISOString();
  db.sqlite.prepare('INSERT INTO installation_credentials VALUES(?,?,?)').run('same-id', `secret-${token}`, stamp);
  db.sqlite.prepare(`INSERT INTO installations(installation_id,fcm_token,nx,ny,region_topic,
    location_mode,minimum_age_confirmed_at,age_policy_version,created_at,updated_at)
    VALUES('same-id',?,?,127,'weather','MANUAL',?,1,?,?)`).run(token, nx, stamp, stamp, stamp);
  db.sqlite.prepare(`INSERT INTO notification_settings(installation_id,lightning_supported,created_at,updated_at)
    VALUES('same-id',1,?,?)`).run(stamp, stamp);
}

function tables(db: SqliteD1Database): string[] {
  return (db.sqlite.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
    .all() as Array<{ name: string }>).map(row => row.name);
}

async function seedWeather(db: D1Database, rainy = false): Promise<void> {
  const current = { observedAt: now.toISOString(), forecastAt: now.toISOString(), dataRole: 'FORECAST' as const,
    temperature: 17, humidity: 60, windSpeed: 2, skyCondition: rainy ? '비' : '맑음',
    precipitationProbability: rainy ? 90 : 0, precipitationAmount: rainy ? 2 : 0 };
  const forecast: WeatherForecast = { current, hourly: [0, 1, 2].map(hour => ({ ...current,
    forecastAt: new Date(now.getTime() + hour * 3_600_000).toISOString() })),
    daily: [{ date: '20261023', minTemperature: 12, maxTemperature: 20,
      skyCondition: '맑음', precipitationProbability: 0, precipitationAmount: 0 }],
    baseDate: '20261023', baseTime: '0800', dataSource: '기상청' };
  await saveCollectedCache(db, { key: 'COLLECTED_REGION_60_127', type: 'COLLECTED_REGION', nx: 60, ny: 127,
    updatedAt: now, value: { forecast, environmental: { sources: {
      uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNAVAILABLE' },
      airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' },
    } } } });
}

describe('공용 날씨 DB와 환경별 사용자 DB', () => {
  it('한 번 저장한 날씨를 두 API가 즉시 읽고 사용자 테이블은 공용 DB에 만들지 않는다', async () => {
    vi.useFakeTimers({ toFake: ['Date'] }); vi.setSystemTime(now);
    const external = vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('외부 호출 금지'));
    const root = directory();
    const production = runtime(root, 'production');
    const test = runtime(root, 'test');
    seedUser(production.database, '운영 토큰');
    seedUser(test.database, '시험 토큰');
    await seedWeather(weatherDatabase(production.env));
    for (const env of [production.env, test.env]) {
      const response = await app.fetch(new Request('http://localhost/api/v1/weather/main?nx=60&ny=127'), env);
      expect(response.status).toBe(200);
      expect(((await response.json()) as TodayWeatherResponse).nextForecast.temperature).toBe(17);
    }
    expect(external).not.toHaveBeenCalled();
    expect(tables(production.weatherDatabase!)).not.toContain('installations');
    expect(tables(production.weatherDatabase!)).not.toContain('notification_history');
    expect(tables(production.database)).not.toContain('weather_cache');
    expect(tables(test.database)).not.toContain('grid_extra_snapshots');
    test.database.sqlite.exec('DELETE FROM installations');
    expect(production.database.sqlite.prepare('SELECT fcm_token FROM installations').get()).toEqual({ fcm_token: '운영 토큰' });
    expect(await weatherDatabase(test.env).prepare('SELECT COUNT(*) AS count FROM weather_cache').first('count')).toBe(1);
  });

  it('공용 낙뢰로 알림을 판단하고 같은 설치 ID의 발송 이력·중복 방지는 환경별로 유지한다', async () => {
    const root = directory();
    const production = runtime(root, 'production');
    const test = runtime(root, 'test');
    seedUser(production.database, '운영 토큰'); seedUser(test.database, '시험 토큰');
    const shared = production.weatherDatabase!.sqlite;
    shared.prepare('INSERT INTO lightning_collection_state VALUES(1,?,?,?)')
      .run(now.toISOString(), now.toISOString(), 'AVAILABLE');
    shared.prepare('INSERT INTO grid_extra_snapshots VALUES(?,?,?,?,?)')
      .run('KMA_LIGHTNING', 'ALL', now.toISOString(), JSON.stringify({ events: [
        { latitude: 37.5665, longitude: 126.978, observedAt: new Date(now.getTime() - 60_000).toISOString() },
      ] }), now.toISOString());
    const payloads: FcmPayload[] = [];
    const sender = async (_env: unknown, batch: FcmPayload[]) => {
      payloads.push(...batch); return batch.map(item => ({ token: item.token, notificationKey: item.notificationKey,
        success: true, unregistered: false, status: 200 }));
    };
    for (const env of [production.env, test.env, production.env, test.env]) {
      await runLightningNotificationJob(env, { now: () => now, sender });
    }
    expect(payloads).toHaveLength(2);
    expect(payloads.map(payload => payload.token).sort()).toEqual(['시험 토큰', '운영 토큰'].sort());
    for (const db of [production.database, test.database]) {
      expect(db.sqlite.prepare('SELECT COUNT(*) AS count FROM notification_history').get()).toEqual({ count: 1 });
      expect(db.sqlite.prepare('SELECT COUNT(*) AS count FROM lightning_notification_claims').get()).toEqual({ count: 1 });
    }
  });

  it('중앙 수집기는 두 환경의 대상 지역을 읽고 다른 환경 DB에는 쓰지 못한다', async () => {
    const root = directory();
    const test = runtime(root, 'test'); seedUser(test.database, '시험', 98);
    const production = runtime(root, 'production', {
      NODE_COLLECTION_USER_DATABASE_PATHS: JSON.stringify([join(root, 'test.sqlite')]),
    });
    seedUser(production.database, '운영');
    expect((await loadCollectionTargets(production.env)).map(row => row.nx).sort()).toEqual([60, 98]);
    await expect(production.env.COLLECTION_USER_DATABASES![1].prepare('DELETE FROM installations').run())
      .rejects.toThrow(/readonly/);
  });

  it('일반 날씨 알림도 공용 예보를 읽으며 환경별 알림 끄기와 발송 이력을 따른다', async () => {
    vi.useFakeTimers({ toFake: ['Date'] }); vi.setSystemTime(now);
    const root = directory();
    const production = runtime(root, 'production'); const test = runtime(root, 'test');
    seedUser(production.database, '운영'); seedUser(test.database, '시험');
    await seedWeather(weatherDatabase(production.env), true);
    await saveCollectedCache(weatherDatabase(production.env), { key: 'COLLECTED_WARNING_STATIONS',
      type: 'WARNING_STATIONS', value: [], updatedAt: now });
    production.database.sqlite.exec("UPDATE notification_settings SET notification_time='09:10'");
    test.database.sqlite.exec("UPDATE notification_settings SET notification_time='09:10',notification_enabled=0");
    const sent: string[] = [];
    const dependencies = { now, sender: async (_env: unknown, batch: FcmPayload[]) => {
      sent.push(...batch.map(item => item.token));
      return batch.map(item => ({ token: item.token, notificationKey: item.notificationKey,
        success: true, unregistered: false, status: 200 }));
    } };
    await runRecommendationNotificationJob(production.env, dependencies);
    await runRecommendationNotificationJob(test.env, dependencies);
    expect(sent).toEqual(['운영']);
    test.database.sqlite.exec('UPDATE notification_settings SET notification_enabled=1');
    await runRecommendationNotificationJob(test.env, dependencies);
    await runRecommendationNotificationJob(production.env, dependencies);
    expect(sent).toEqual(['운영', '시험']);
  });

  it('수집을 끈 환경은 예약 작업에서 외부 API를 호출하지 않는다', async () => {
    const value = runtime(directory(), 'test', { WEATHER_COLLECTION_ENABLED: 'false' });
    const external = vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('외부 호출 금지'));
    await runScheduledJobs(value.env, CORE_COLLECTION_CRON, now.getTime());
    await runScheduledJobs(value.env, GRID_LIGHTNING_CRON, now.getTime());
    await runWeatherCollectionJob(value.env, { now });
    expect(external).not.toHaveBeenCalled();
  });

  it('동일 경로의 사용자·날씨 DB와 전환 전 통합 DB를 거부한다', () => {
    const root = directory();
    const path = join(root, 'old.sqlite');
    expect(() => createNodeRuntime({ environment: { NODE_DATABASE_PATH: path, NODE_WEATHER_DATABASE_PATH: path } }))
      .toThrow('NODE_DATABASE_PATH_CONFLICT');
    const old = new SqliteD1Database(path); runSqliteMigrations(old); old.close();
    expect(() => createNodeRuntime({ environment: { NODE_DATABASE_PATH: path } }))
      .toThrow('NODE_LEGACY_DATABASE_REQUIRES_SPLIT');
  });

  it.each([1, 2, 3])('두 프로세스가 동시에 초기화해도 공용 마이그레이션을 한 번만 적용한다 (%i)', async () => {
    const root = directory();
    const script = "const {createNodeRuntime}=await import('./src/node/runtime.ts'); const r=createNodeRuntime(); r.close();";
    const results = await Promise.allSettled(['production', 'test'].map(kind => execute(process.execPath,
      ['--import', 'tsx', '--input-type=module', '-e', script], { windowsHide: true, env: {
        ...process.env, NODE_DATABASE_PATH: join(root, `${kind}.sqlite`),
        NODE_WEATHER_DATABASE_PATH: join(root, 'weather.sqlite'), NODE_COLLECTION_USER_DATABASE_PATHS: '[]',
      } })));
    for (const result of results) if (result.status === 'rejected') throw result.reason;
    const value = runtime(root, 'production');
    expect(value.weatherDatabase!.sqlite.prepare('SELECT COUNT(*) AS count FROM d1_migrations').get()).toEqual({ count: 1 });
  });

  it('백업 명령이 환경별 사용자 DB와 공용 날씨 DB를 함께 보관한다', async () => {
    const root = directory();
    const value = runtime(root, 'production'); seedUser(value.database, '운영');
    await seedWeather(weatherDatabase(value.env));
    const backupDirectory = join(root, 'backups');
    await execute(process.execPath, ['--import', 'tsx', 'src/node/backup.ts'], { windowsHide: true, env: {
      ...process.env, NODE_DATABASE_PATH: join(root, 'production.sqlite'),
      NODE_WEATHER_DATABASE_PATH: join(root, 'weather.sqlite'), NODE_COLLECTION_USER_DATABASE_PATHS: '[]',
      NODE_BACKUP_DIR: backupDirectory,
    } });
    const files = readdirSync(backupDirectory).sort(); expect(files).toHaveLength(2);
    for (const file of files) {
      const db = new SqliteD1Database(join(backupDirectory, file), { readonly: true });
      try {
        expect(db.sqlite.prepare(`SELECT COUNT(*) AS count FROM ${file.startsWith('production-') ? 'installations' : 'weather_cache'}`)
          .get()).toEqual({ count: 1 });
      } finally { db.close(); }
    }
  });
});

describe('기존 DB 무손실 분리', () => {
  it('각 환경의 인증·설정·이력을 보존하고 최신 날씨와 시험 전용 수집 자료를 공용으로 합친다', () => {
    const root = directory();
    const paths: SplitDatabasePaths = { productionSource: join(root, 'old-production.sqlite'),
      testSource: join(root, 'old-test.sqlite'), weather: join(root, 'weather.sqlite'),
      productionUsers: join(root, 'production.sqlite'), testUsers: join(root, 'test.sqlite') };
    for (const [path, token, stamp] of [[paths.productionSource, '운영', '2026-10-23T00:00:00Z'],
      [paths.testSource, '시험', '2026-10-23T00:10:00Z']]) {
      const db = new SqliteD1Database(path); runSqliteMigrations(db); seedUser(db, token);
      db.sqlite.prepare(`INSERT INTO weather_cache VALUES('common','전국',0,0,'RAW',?,'AVAILABLE',?)`).run(token, stamp);
      db.sqlite.prepare(`INSERT INTO notification_history VALUES('same-id','2026-10-23',?,?,NULL)`).run(token, stamp);
      db.sqlite.prepare(`INSERT INTO lightning_notification_claims VALUES('same-id',?,?,?,?)`)
        .run(`claim-${token}`, stamp, '2026-10-24T00:00:00Z', stamp);
      db.sqlite.prepare('INSERT INTO installation_activity VALUES(?,?)').run('same-id', stamp);
      db.sqlite.prepare(`UPDATE notification_settings SET notification_time='12:40',umbrella_enabled=0`).run();
      db.sqlite.prepare(`INSERT INTO api_usage_daily VALUES('2026-10-23','KMA',10,20,?)`).run(stamp);
      db.sqlite.prepare('INSERT INTO administrative_boundary_dataset VALUES(1,?,?,?)').run(token, '{}', stamp);
      db.sqlite.prepare('INSERT INTO administrative_boundary_grid_regions VALUES(?,?,?)').run(token === '운영' ? 60 : 98, 127, token);
      if (token === '시험') {
        db.sqlite.prepare(`INSERT INTO grid_extra_snapshots VALUES('SEA','BUSAN','20261023','수집 자료',?)`).run(stamp);
        db.sqlite.prepare(`INSERT INTO grid_extra_snapshots VALUES('KMA_LIGHTNING_TEST','ALL','20261023','합성 자료',?)`).run(stamp);
      }
      db.sqlite.pragma('wal_checkpoint(TRUNCATE)'); db.close();
    }
    const before = [paths.productionSource, paths.testSource].map(path => readFileSync(path));
    splitLegacyDatabases(paths);
    expect([paths.productionSource, paths.testSource].map(path => readFileSync(path))).toEqual(before);
    const production = runtime(root, 'production'); const test = runtime(root, 'test');
    for (const [db, token] of [[production.database, '운영'], [test.database, '시험']] as const) {
      expect(db.sqlite.prepare('SELECT fcm_token FROM installations').get()).toEqual({ fcm_token: token });
      expect(db.sqlite.prepare('SELECT secret_hash FROM installation_credentials').get()).toEqual({ secret_hash: `secret-${token}` });
      expect(db.sqlite.prepare('SELECT notification_key FROM notification_history').get()).toEqual({ notification_key: token });
      expect(db.sqlite.prepare('SELECT lightning_supported FROM notification_settings').get()).toEqual({ lightning_supported: 1 });
      expect(db.sqlite.prepare('SELECT notification_time,umbrella_enabled FROM notification_settings').get())
        .toEqual({ notification_time: '12:40', umbrella_enabled: 0 });
      expect(db.sqlite.prepare('SELECT notification_key FROM lightning_notification_claims').get())
        .toEqual({ notification_key: `claim-${token}` });
      expect(() => db.sqlite.prepare(`INSERT INTO installation_credentials VALUES('same-id','other','now')`).run()).toThrow();
      expect(() => db.sqlite.prepare(`INSERT INTO installations(installation_id,nx,ny,region_topic,location_mode,created_at,updated_at)
        VALUES('unknown',60,127,'region','GPS','now','now')`).run()).toThrow('installation authentication required');
    }
    const shared = production.weatherDatabase!.sqlite;
    expect(shared.prepare('SELECT payload FROM weather_cache').get()).toEqual({ payload: '시험' });
    expect(shared.prepare('SELECT payload FROM grid_extra_snapshots').all()).toEqual([{ payload: '수집 자료' }]);
    expect(shared.prepare('SELECT version FROM administrative_boundary_dataset').get()).toEqual({ version: '시험' });
    expect(shared.prepare('SELECT nx,kma_code FROM administrative_boundary_grid_regions').all()).toEqual([{ nx: 98, kma_code: '시험' }]);
    expect(shared.prepare('SELECT request_count,response_bytes FROM api_usage_daily').get()).toEqual({ request_count: 20, response_bytes: 40 });
    expect(() => splitLegacyDatabases(paths)).toThrow('DATABASE_SPLIT_OUTPUT_EXISTS');
  });
});
