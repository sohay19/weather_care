import { SELF, env } from 'cloudflare:test';
import { beforeEach, describe, expect, it } from 'vitest';
import { authorizeFixture, testAuthHeaders } from './installationAuthFixture';

describe('notification settings API', () => {
  beforeEach(async () => {
    await authorizeFixture();
    await env.DB.prepare(
      `CREATE TABLE IF NOT EXISTS notification_settings (
        installation_id TEXT PRIMARY KEY,
        notification_enabled INTEGER NOT NULL DEFAULT 1,
        notification_time TEXT NOT NULL DEFAULT '07:00',
        commute_to_work_start TEXT NOT NULL DEFAULT '07:00',
        commute_to_work_end TEXT NOT NULL DEFAULT '10:00',
        commute_from_work_start TEXT NOT NULL DEFAULT '17:00',
        commute_from_work_end TEXT NOT NULL DEFAULT '20:00',
        umbrella_enabled INTEGER NOT NULL DEFAULT 1,
        parasol_enabled INTEGER NOT NULL DEFAULT 1,
        heavy_snow_enabled INTEGER NOT NULL DEFAULT 1,
        outerwear_enabled INTEGER NOT NULL DEFAULT 1,
        mask_enabled INTEGER NOT NULL DEFAULT 1,
        water_enabled INTEGER NOT NULL DEFAULT 1,
        sunscreen_enabled INTEGER NOT NULL DEFAULT 1,
        dryness_enabled INTEGER,
        carry_notification_enabled INTEGER,
        today_notification_enabled INTEGER,
        weather_notification_enabled INTEGER,
        snow_preparation_enabled INTEGER,
        uv_preparation_enabled INTEGER,
        pollen_enabled INTEGER,
        black_ice_enabled INTEGER,
        today_visibility_enabled INTEGER NOT NULL DEFAULT 1,
        today_ozone_enabled INTEGER NOT NULL DEFAULT 1,
        today_wind_enabled INTEGER NOT NULL DEFAULT 1,
        today_humidity_enabled INTEGER NOT NULL DEFAULT 1,
        today_apparent_temperature_enabled INTEGER NOT NULL DEFAULT 1,
        daily_weather_enabled INTEGER NOT NULL DEFAULT 1,
        heavy_rain_enabled INTEGER NOT NULL DEFAULT 1,
        heatwave_enabled INTEGER NOT NULL DEFAULT 1,
        cold_wave_enabled INTEGER NOT NULL DEFAULT 1,
        shower_light_rain_enabled INTEGER NOT NULL DEFAULT 1,
        lightning_enabled INTEGER NOT NULL DEFAULT 1,
        lightning_supported INTEGER NOT NULL DEFAULT 0,
          pipe_freeze_enabled INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL)`,
    ).run();
    await env.DB.prepare('DELETE FROM notification_settings').run();
  });

  it('persists partial updates and returns camel-case settings', async () => {
    const update = await SELF.fetch(
      'https://example.com/api/v1/notification-settings/device-1',
      {
        method: 'PUT',
        headers: testAuthHeaders,
        body: JSON.stringify({
          notificationTime: '06:35',
          umbrellaEnabled: false,
          heavyRainEnabled: false,
          lightningEnabled: false,
        }),
      },
    );
    expect(update.status).toBe(200);

    const response = await SELF.fetch(
      'https://example.com/api/v1/notification-settings?installationId=device-1',
      { headers: testAuthHeaders },
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      installationId: 'device-1',
      notificationTime: '06:35',
      umbrellaEnabled: false,
      heavyRainEnabled: false,
      lightningEnabled: false,
      parasolEnabled: true,
      pipeFreezeEnabled: true,
    });
  });

  it('동파 알림 선택을 저장하고 구 앱의 필드 없는 부분 갱신에도 유지한다', async () => {
    for (const body of [{pipeFreezeEnabled: true}, {notificationTime: '08:00'}]) {
      const response = await SELF.fetch('https://example.com/api/v1/notification-settings/device-1', {
        method: 'PUT', headers: testAuthHeaders, body: JSON.stringify(body),
      });
      expect(response.status).toBe(200);
      expect(await response.json()).toMatchObject({pipeFreezeEnabled: true});
    }
  });

  it.each(['/api/v1/notification-settings/device-1', '/api/v1/installations/device-1/notification-settings'])(
    '%s는 신규 동파 기본 ON과 저장한 OFF를 보존한다', async (path) => {
      for (const [body, enabled] of [
        [{ notificationTime: '08:00' }, true],
        [{ pipeFreezeEnabled: false }, false],
        [{ notificationTime: '09:00' }, false],
      ] as const) {
        const saved = await SELF.fetch('https://example.com' + path, {
          method: 'PUT', headers: testAuthHeaders, body: JSON.stringify(body),
        });
        expect(saved.status).toBe(200);
        const current = await SELF.fetch('https://example.com/api/v1/notification-settings?installationId=device-1', {
          headers: testAuthHeaders,
        });
        expect(await current.json()).toMatchObject({ pipeFreezeEnabled: enabled });
      }
    });

  it('출퇴근 시간과 야간 구간을 저장하고 구 앱의 부분 갱신에도 유지한다', async () => {
    const schedule = { commuteToWorkStart: '23:00', commuteToWorkEnd: '01:00',
      commuteFromWorkStart: '10:00', commuteFromWorkEnd: '11:00' };
    for (const body of [schedule, { notificationTime: '08:30' }]) {
      const response = await SELF.fetch('https://example.com/api/v1/notification-settings/device-1', {
        method: 'PUT', headers: testAuthHeaders, body: JSON.stringify(body),
      });
      expect(response.status).toBe(200);
      expect(await response.json()).toMatchObject(schedule);
    }
    const response = await SELF.fetch('https://example.com/api/v1/notification-settings?installationId=device-1',
      { headers: testAuthHeaders });
    expect(await response.json()).toMatchObject(schedule);
  });

  it.each(['/api/v1/notification-settings/device-1', '/api/v1/installations/device-1/notification-settings'])(
    '%s는 기존 종료와 같아지는 부분 변경을 거부한다', async (path) => {
      const response = await SELF.fetch(`https://example.com${path}`, {
        method: 'PUT', headers: testAuthHeaders,
        body: JSON.stringify({ commuteToWorkStart: '10:00' }),
      });
      expect(response.status).toBe(400);
      const current = await SELF.fetch('https://example.com/api/v1/notification-settings?installationId=device-1',
        { headers: testAuthHeaders });
      expect(await current.json()).toMatchObject({ commuteToWorkStart: '07:00', commuteToWorkEnd: '10:00' });
    });

  it('rejects invalid times and unknown fields', async () => {
    for (const body of [
      { notificationTime: '25:00' },
      { commuteToWorkStart: '24:00' },
      { commuteFromWorkEnd: '18:60' },
      { commuteFromWorkStart: '8:00' },
      { commuteToWorkStart: null },
      { commuteFromWorkStart: '20:00' },
      { unsupportedSetting: true },
    ]) {
      const response = await SELF.fetch(
        'https://example.com/api/v1/notification-settings/device-1',
        {
          method: 'PUT',
          headers: testAuthHeaders,
          body: JSON.stringify(body),
        },
      );
      expect(response.status).toBe(400);
    }
  });
});
