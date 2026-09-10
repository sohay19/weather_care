import { NotificationSettings } from '../types';

interface NotificationSettingsRow {
  installationId: string;
  notificationEnabled: number;
  notificationTime: string;
  umbrellaEnabled: number;
  parasolEnabled: number;
  heavySnowEnabled: number;
  outerwearEnabled: number;
  maskEnabled: number;
  waterEnabled: number;
  sunscreenEnabled: number;
  dailyWeatherEnabled: number;
  heavyRainEnabled: number;
  heatwaveEnabled: number;
  coldWaveEnabled: number;
  showerAndLightRainEnabled: number;
}

export function defaultNotificationSettings(
  installationId: string,
): NotificationSettings {
  return {
    installationId,
    notificationEnabled: true,
    notificationTime: '07:00',
    umbrellaEnabled: true,
    parasolEnabled: true,
    heavySnowEnabled: true,
    outerwearEnabled: true,
    maskEnabled: true,
    waterEnabled: true,
    sunscreenEnabled: true,
    dailyWeatherEnabled: true,
    heavyRainEnabled: true,
    heatwaveEnabled: true,
    coldWaveEnabled: true,
    showerAndLightRainEnabled: true,
  };
}

export async function getNotificationSettings(
  db: D1Database,
  installationId: string,
): Promise<NotificationSettings> {
  const row = await db
    .prepare(
      `SELECT
         installation_id AS installationId,
         notification_enabled AS notificationEnabled,
         notification_time AS notificationTime,
         umbrella_enabled AS umbrellaEnabled,
         parasol_enabled AS parasolEnabled,
         heavy_snow_enabled AS heavySnowEnabled,
         outerwear_enabled AS outerwearEnabled,
         mask_enabled AS maskEnabled,
         water_enabled AS waterEnabled,
         sunscreen_enabled AS sunscreenEnabled,
         daily_weather_enabled AS dailyWeatherEnabled,
         heavy_rain_enabled AS heavyRainEnabled,
         heatwave_enabled AS heatwaveEnabled,
         cold_wave_enabled AS coldWaveEnabled,
         shower_light_rain_enabled AS showerAndLightRainEnabled
       FROM notification_settings
       WHERE installation_id = ?`,
    )
    .bind(installationId)
    .first<NotificationSettingsRow>();
  if (!row) return defaultNotificationSettings(installationId);
  return {
    installationId: row.installationId,
    notificationEnabled: row.notificationEnabled === 1,
    notificationTime: row.notificationTime,
    umbrellaEnabled: row.umbrellaEnabled === 1,
    parasolEnabled: row.parasolEnabled === 1,
    heavySnowEnabled: row.heavySnowEnabled === 1,
    outerwearEnabled: row.outerwearEnabled === 1,
    maskEnabled: row.maskEnabled === 1,
    waterEnabled: row.waterEnabled === 1,
    sunscreenEnabled: row.sunscreenEnabled === 1,
    dailyWeatherEnabled: row.dailyWeatherEnabled === 1,
    heavyRainEnabled: row.heavyRainEnabled === 1,
    heatwaveEnabled: row.heatwaveEnabled === 1,
    coldWaveEnabled: row.coldWaveEnabled === 1,
    showerAndLightRainEnabled: row.showerAndLightRainEnabled === 1,
  };
}

export async function upsertNotificationSettings(
  db: D1Database,
  payload: NotificationSettings,
  ownerHash?: string,
): Promise<boolean> {
  const now = new Date().toISOString();
  const result = await db
    .prepare(
      `INSERT INTO notification_settings
      (installation_id, notification_enabled, notification_time,
       umbrella_enabled, parasol_enabled, heavy_snow_enabled,
       outerwear_enabled, mask_enabled, water_enabled, sunscreen_enabled,
       daily_weather_enabled, heavy_rain_enabled, heatwave_enabled,
       cold_wave_enabled, shower_light_rain_enabled, created_at, updated_at)
      SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      ${ownerHash === undefined ? 'WHERE 1' : `WHERE EXISTS (SELECT 1 FROM installation_credentials
        WHERE installation_id = ? AND secret_hash = ?)`}
      ON CONFLICT(installation_id) DO UPDATE SET
        notification_enabled=excluded.notification_enabled,
        notification_time=excluded.notification_time,
        umbrella_enabled=excluded.umbrella_enabled,
        parasol_enabled=excluded.parasol_enabled,
        heavy_snow_enabled=excluded.heavy_snow_enabled,
        outerwear_enabled=excluded.outerwear_enabled,
        mask_enabled=excluded.mask_enabled,
        water_enabled=excluded.water_enabled,
        sunscreen_enabled=excluded.sunscreen_enabled,
        daily_weather_enabled=excluded.daily_weather_enabled,
        heavy_rain_enabled=excluded.heavy_rain_enabled,
        heatwave_enabled=excluded.heatwave_enabled,
        cold_wave_enabled=excluded.cold_wave_enabled,
        shower_light_rain_enabled=excluded.shower_light_rain_enabled,
        updated_at=excluded.updated_at`,
    )
    .bind(
      payload.installationId,
      booleanInteger(payload.notificationEnabled),
      payload.notificationTime,
      booleanInteger(payload.umbrellaEnabled),
      booleanInteger(payload.parasolEnabled),
      booleanInteger(payload.heavySnowEnabled),
      booleanInteger(payload.outerwearEnabled),
      booleanInteger(payload.maskEnabled),
      booleanInteger(payload.waterEnabled),
      booleanInteger(payload.sunscreenEnabled),
      booleanInteger(payload.dailyWeatherEnabled),
      booleanInteger(payload.heavyRainEnabled),
      booleanInteger(payload.heatwaveEnabled),
      booleanInteger(payload.coldWaveEnabled),
      booleanInteger(payload.showerAndLightRainEnabled),
      now,
      now,
      ...(ownerHash === undefined ? [] : [payload.installationId, ownerHash]),
    )
    .run();
  return result.meta.changes > 0;
}

function booleanInteger(value: boolean): number {
  return value ? 1 : 0;
}
