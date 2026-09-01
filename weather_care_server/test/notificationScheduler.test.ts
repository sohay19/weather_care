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
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL)`,
      ),
      env.DB.prepare(
        `CREATE TABLE IF NOT EXISTS notification_history (
          installation_id TEXT NOT NULL, target_date TEXT NOT NULL,
          notification_key TEXT NOT NULL, sent_at TEXT NOT NULL,
          payload_hash TEXT,
          PRIMARY KEY (installation_id, target_date, notification_key))`,
      ),
    ]);
    await env.DB.batch([
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
});

describe('notification time slots', () => {
  it('runs at the next ten-minute cron slot', () => {
    expect(isNotificationTimeDue('07:00', '07:00')).toBe(true);
    expect(isNotificationTimeDue('07:10', '07:05')).toBe(true);
    expect(isNotificationTimeDue('07:00', '07:05')).toBe(false);
    expect(isNotificationTimeDue('00:00', '23:55')).toBe(true);
  });
});

async function insertInstallation(token: string): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO installations
     (installation_id, fcm_token, nx, ny, region_topic, location_mode,
      timezone, created_at, updated_at)
     VALUES (?, ?, 60, 121, 'region_60_121', 'GPS', 'Asia/Seoul', ?, ?)`,
  )
    .bind(
      'installation-1',
      token,
      '2026-09-01T00:00:00Z',
      '2026-09-01T00:00:00Z',
    )
    .run();
}

function testBindings(): ServerEnv {
  return {
    DB: env.DB,
    APP_ORIGIN: 'http://localhost:8787',
    FCM_PROJECT_ID: 'weather-care-2aaa8',
    KMA_SERVICE_KEY: 'test-key',
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
