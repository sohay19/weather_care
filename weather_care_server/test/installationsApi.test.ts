import { SELF, env } from 'cloudflare:test';
import { beforeEach, describe, expect, it } from 'vitest';

describe('installation API precise location', () => {
  beforeEach(async () => {
    await env.DB.prepare(
      `CREATE TABLE IF NOT EXISTS installations (
        installation_id TEXT PRIMARY KEY,
        fcm_token TEXT,
        nx INTEGER NOT NULL,
        ny INTEGER NOT NULL,
        region_topic TEXT NOT NULL,
        location_mode TEXT NOT NULL,
        platform TEXT,
        app_version TEXT,
        timezone TEXT NOT NULL DEFAULT 'Asia/Seoul',
        latitude REAL,
        longitude REAL,
        current_rain_state INTEGER NOT NULL DEFAULT 0,
        current_rain_observed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL)`,
    ).run();
    await env.DB.prepare('DELETE FROM installations').run();
  });

  it('stores GPS coordinates used by the current-rain scheduler', async () => {
    const response = await SELF.fetch(
      'https://example.com/api/v1/installations/device-1?nx=60&ny=121',
      {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fcmToken: 'token-1',
          locationMode: 'GPS',
          platform: 'android',
          timezone: 'Asia/Seoul',
          latitude: 37.2636,
          longitude: 127.0286,
        }),
      },
    );

    expect(response.status).toBe(200);
    const stored = await env.DB.prepare(
      `SELECT latitude, longitude, current_rain_state AS currentRainState
       FROM installations WHERE installation_id = ?`,
    )
      .bind('device-1')
      .first<{
        latitude: number;
        longitude: number;
        currentRainState: number;
      }>();
    expect(stored).toEqual({
      latitude: 37.2636,
      longitude: 127.0286,
      currentRainState: 0,
    });
  });

  it('rejects an incomplete coordinate pair', async () => {
    const response = await SELF.fetch(
      'https://example.com/api/v1/installations/device-1?nx=60&ny=121',
      {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          locationMode: 'GPS',
          latitude: 37.2636,
        }),
      },
    );

    expect(response.status).toBe(400);
  });
});
