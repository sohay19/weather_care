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
      parasolEnabled: true,
    });
  });

  it('rejects invalid times and unknown fields', async () => {
    for (const body of [
      { notificationTime: '25:00' },
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
