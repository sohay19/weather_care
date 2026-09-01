import { env } from 'cloudflare:test';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  isNotificationTimeDue,
  runRecommendationNotificationJob,
} from '../src/notification/notificationScheduler';
import { FcmPayload } from '../src/notification/fcmClient';
import { WeatherForecast } from '../src/providers/weather/weatherProvider';
import { ServerEnv, WeatherSnapshot } from '../src/types';

describe('notification scheduler', () => {
  beforeEach(async () => {
    await env.DB.batch([
      env.DB.prepare(
        `CREATE TABLE IF NOT EXISTS installations (
          installation_id TEXT PRIMARY KEY, fcm_token TEXT,
          nx INTEGER NOT NULL, ny INTEGER NOT NULL,
          region_topic TEXT NOT NULL, location_mode TEXT NOT NULL,
          platform TEXT, app_version TEXT,
          timezone TEXT NOT NULL DEFAULT 'Asia/Seoul',
          latitude REAL, longitude REAL,
          current_rain_state INTEGER NOT NULL DEFAULT 0,
          current_rain_observed_at TEXT,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL)`,
      ),
      env.DB.prepare(
        `CREATE TABLE IF NOT EXISTS notification_settings (
          installation_id TEXT PRIMARY KEY,
          notification_enabled INTEGER NOT NULL DEFAULT 1,
          notification_time TEXT NOT NULL DEFAULT '07:00',
          umbrella_enabled INTEGER NOT NULL DEFAULT 1,
          parasol_enabled INTEGER NOT NULL DEFAULT 1,
          heavy_snow_enabled INTEGER NOT NULL DEFAULT 1,
          outerwear_enabled INTEGER NOT NULL DEFAULT 1,
          mask_enabled INTEGER NOT NULL DEFAULT 1,
          water_enabled INTEGER NOT NULL DEFAULT 1,
          sunscreen_enabled INTEGER NOT NULL DEFAULT 1,
          daily_weather_enabled INTEGER NOT NULL DEFAULT 1,
          heavy_rain_enabled INTEGER NOT NULL DEFAULT 1,
          heatwave_enabled INTEGER NOT NULL DEFAULT 1,
          cold_wave_enabled INTEGER NOT NULL DEFAULT 1,
          shower_light_rain_enabled INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL)`,
      ),
      env.DB.prepare(
        `CREATE TABLE IF NOT EXISTS notification_history (
          installation_id TEXT NOT NULL, target_date TEXT NOT NULL,
          notification_key TEXT NOT NULL, sent_at TEXT NOT NULL,
          payload_hash TEXT,
          PRIMARY KEY (installation_id, target_date, notification_key))`,
      ),
      env.DB.prepare(
        `CREATE TABLE IF NOT EXISTS installation_warning_state (
          installation_id TEXT NOT NULL, warning_type TEXT NOT NULL,
          warning_name TEXT NOT NULL, level_code TEXT NOT NULL,
          level_name TEXT NOT NULL, region_name TEXT NOT NULL,
          effective_at TEXT NOT NULL, updated_at TEXT NOT NULL,
          PRIMARY KEY (installation_id, warning_type))`,
      ),
    ]);
    await env.DB.batch([
      env.DB.prepare('DELETE FROM installation_warning_state'),
      env.DB.prepare('DELETE FROM notification_history'),
      env.DB.prepare('DELETE FROM notification_settings'),
      env.DB.prepare('DELETE FROM installations'),
    ]);
  });

  it('sends a due brief once and records only a successful send', async () => {
    await insertInstallation('device-token');
    const sent: FcmPayload[][] = [];
    const sender = vi.fn(async (_env: ServerEnv, payloads: FcmPayload[]) => {
      sent.push(payloads);
      return payloads.map((payload) => ({
        token: payload.token,
        notificationKey: payload.notificationKey,
        success: true,
        unregistered: false,
        status: 200,
      }));
    });
    const dependencies = {
      now: new Date('2026-09-01T22:00:00Z'),
      forecastLoader: async () => rainyForecast(),
      sender,
    };
    const bindings = testBindings();

    await runRecommendationNotificationJob(bindings, dependencies);
    await runRecommendationNotificationJob(bindings, dependencies);

    expect(sent).toHaveLength(1);
    expect(sent[0][0]).toMatchObject({
      token: 'device-token',
      notificationKey: 'MORNING_BRIEF',
    });
    const history = await env.DB.prepare(
      'SELECT notification_key FROM notification_history',
    ).all<{ notification_key: string }>();
    expect(history.results).toEqual([
      { notification_key: 'MORNING_BRIEF' },
    ]);
  });

  it('removes an unregistered token without writing send history', async () => {
    await insertInstallation('expired-token');
    const bindings = testBindings();

    await runRecommendationNotificationJob(bindings, {
      now: new Date('2026-09-01T22:00:00Z'),
      forecastLoader: async () => rainyForecast(),
      sender: async (_env, payloads) =>
        payloads.map((payload) => ({
          token: payload.token,
          notificationKey: payload.notificationKey,
          success: false,
          unregistered: true,
          status: 404,
        })),
    });

    const installation = await env.DB.prepare(
      'SELECT fcm_token FROM installations WHERE installation_id = ?',
    )
      .bind('installation-1')
      .first<{ fcm_token: string | null }>();
    const history = await env.DB.prepare(
      'SELECT COUNT(*) AS count FROM notification_history',
    ).first<{ count: number }>();
    expect(installation?.fcm_token).toBeNull();
    expect(history?.count).toBe(0);
  });

  it('sends current rain once per rain episode only after both 500m sources agree', async () => {
    await insertInstallation('device-token', true);
    const sender = vi.fn(async (_env: ServerEnv, payloads: FcmPayload[]) =>
      payloads.map((payload) => ({
        token: payload.token,
        notificationKey: payload.notificationKey,
        success: true,
        unregistered: false,
        status: 200,
      })),
    );
    const dependencies = {
      now: new Date('2026-09-01T12:00:00Z'),
      forecastLoader: async () => rainyForecast(),
      precipitationLoader: async () => ({
        observedAt: '2026-09-01T20:50:00+09:00',
        latitude: 37.2636,
        longitude: 127.0286,
        analysisRainDetected: true,
        radarRainDetected: true,
        state: 'RAIN' as const,
        provider: 'KMA_ANALYSIS_RADAR' as const,
      }),
      warningLoader: async () => [],
      sender,
    };
    const bindings = testBindings('test-apihub-key');

    await runRecommendationNotificationJob(bindings, dependencies);
    await runRecommendationNotificationJob(bindings, dependencies);

    const currentRainPayloads = sender.mock.calls
      .flatMap((call) => call[1] as FcmPayload[])
      .filter((payload) => payload.notificationKey === 'CURRENT_RAIN');
    expect(currentRainPayloads).toEqual([
      expect.objectContaining({
        body: '비가 내리고 있을 수 있어요. 지금 외출한다면 우산을 챙기세요',
      }),
    ]);
    const state = await env.DB.prepare(
      'SELECT current_rain_state AS state FROM installations WHERE installation_id = ?',
    )
      .bind('installation-1')
      .first<{ state: number }>();
    expect(state?.state).toBe(1);
  });

  it('sends an active official warning only once and stores its state', async () => {
    await insertInstallation('device-token');
    const sent: FcmPayload[] = [];
    const dependencies = {
      now: new Date('2026-09-01T12:00:00Z'),
      forecastLoader: async () => rainyForecast(),
      warningLoader: async () => [officialWarning('R', '호우', '2')],
      sender: async (_env: ServerEnv, payloads: FcmPayload[]) => {
        sent.push(...payloads);
        return payloads.map(successResult);
      },
    };
    const bindings = testBindings('test-apihub-key');

    await runRecommendationNotificationJob(bindings, dependencies);
    await runRecommendationNotificationJob(bindings, dependencies);

    expect(sent.filter((item) => item.notificationKey.startsWith('OFFICIAL_WARNING')))
      .toEqual([
        expect.objectContaining({
          body: '호우특보가 발효 중이니, 하천변과 지하차도에 접근하지 마세요 수원에는 호우주의보가 발효 중이에요',
        }),
      ]);
    const state = await env.DB.prepare(
      `SELECT level_code AS levelCode FROM installation_warning_state
       WHERE installation_id = ? AND warning_type = 'R'`,
    )
      .bind('installation-1')
      .first<{ levelCode: string }>();
    expect(state?.levelCode).toBe('2');
  });

  it('announces an official level change and release', async () => {
    await insertInstallation('device-token');
    await insertWarningState('R', '호우', '2', '주의보');
    const sent: FcmPayload[] = [];
    const bindings = testBindings('test-apihub-key');

    await runRecommendationNotificationJob(bindings, {
      now: new Date('2026-09-01T12:00:00Z'),
      forecastLoader: async () => rainyForecast(),
      warningLoader: async () => [officialWarning('R', '호우', '3')],
      sender: collectingSender(sent),
    });
    expect(sent.find((item) => item.notificationKey.includes('CHANGED'))?.body)
      .toContain('기상청은 수원의 호우주의보를 호우경보로 변경했어요');

    sent.length = 0;
    await runRecommendationNotificationJob(bindings, {
      now: new Date('2026-09-01T12:10:00Z'),
      forecastLoader: async () => rainyForecast(),
      warningLoader: async () => [],
      sender: collectingSender(sent),
    });
    expect(sent.find((item) => item.notificationKey.includes('RELEASED'))?.body)
      .toBe('수원의 호우경보가 해제됐어요');
  });
});

describe('notification time slots', () => {
  it('runs at the next ten-minute cron slot', () => {
    expect(isNotificationTimeDue('07:00', '07:00')).toBe(true);
    expect(isNotificationTimeDue('07:10', '07:05')).toBe(true);
    expect(isNotificationTimeDue('07:00', '07:05')).toBe(false);
    expect(isNotificationTimeDue('00:00', '23:55')).toBe(true);
  });
});

async function insertInstallation(
  token: string,
  withCoordinates = false,
): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO installations
     (installation_id, fcm_token, nx, ny, region_topic, location_mode,
      timezone, latitude, longitude, created_at, updated_at)
     VALUES (?, ?, 60, 121, 'region_60_121', 'GPS', 'Asia/Seoul', ?, ?, ?, ?)`,
  )
    .bind(
      'installation-1',
      token,
      withCoordinates ? 37.2636 : null,
      withCoordinates ? 127.0286 : null,
      '2026-09-01T00:00:00Z',
      '2026-09-01T00:00:00Z',
    )
    .run();
}

function testBindings(apiHubKey = ''): ServerEnv {
  return {
    DB: env.DB,
    APP_ORIGIN: 'http://localhost:8787',
    FCM_PROJECT_ID: 'weather-care-2aaa8',
    KMA_SERVICE_KEY: 'test-key',
    KMA_APIHUB_KEY: apiHubKey,
    FCM_CLIENT_EMAIL: 'test@example.iam.gserviceaccount.com',
    FCM_PRIVATE_KEY: 'test-private-key',
  };
}

function rainyForecast(): WeatherForecast {
  const hourly = [7, 8, 9].map((hour) => snapshot(hour));
  return {
    current: hourly[0],
    hourly,
    daily: [],
    baseDate: '20260902',
    baseTime: '0500',
    dataSource: '기상청 단기예보',
  };
}

function snapshot(hour: number): WeatherSnapshot {
  const time = `2026-09-02T${String(hour).padStart(2, '0')}:00:00+09:00`;
  return {
    observedAt: time,
    forecastAt: time,
    validFrom: time,
    validTo: time,
    temperature: 24,
    humidity: 75,
    windSpeed: 2,
    precipitationType: 'RAIN',
    precipitationProbability: 80,
    precipitationAmount: 3,
    precipitationAmountRange: {
      type: 'VALUE',
      min: 3,
      max: 3,
      unit: 'MM',
      rawValue: '3mm',
    },
    snowfallAmount: 0,
  };
}

function officialWarning(
  typeCode: 'R',
  type: '호우',
  levelCode: '2' | '3',
) {
  return {
    typeCode,
    type,
    levelCode,
    level: levelCode === '2' ? '주의보' as const : '경보' as const,
    commandCode: '1' as const,
    regionId: 'L1011900',
    regionName: '수원',
    announcedAt: '2026-09-01T09:00:00+09:00',
    validFrom: '2026-09-01T10:00:00+09:00',
    provider: '기상청 특보현황' as const,
  };
}

function successResult(payload: FcmPayload) {
  return {
    token: payload.token,
    notificationKey: payload.notificationKey,
    success: true,
    unregistered: false,
    status: 200,
  };
}

function collectingSender(sent: FcmPayload[]) {
  return async (_env: ServerEnv, payloads: FcmPayload[]) => {
    sent.push(...payloads);
    return payloads.map(successResult);
  };
}

async function insertWarningState(
  typeCode: string,
  typeName: string,
  levelCode: string,
  levelName: string,
): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO installation_warning_state
     (installation_id, warning_type, warning_name, level_code, level_name,
      region_name, effective_at, updated_at)
     VALUES ('installation-1', ?, ?, ?, ?, '수원', ?, ?)`,
  )
    .bind(
      typeCode,
      typeName,
      levelCode,
      levelName,
      '2026-09-01T10:00:00+09:00',
      '2026-09-01T01:00:00Z',
    )
    .run();
}
