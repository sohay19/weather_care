export async function upsertNotificationSettings(db: any, payload: {
  installationId: string;
  notificationEnabled: boolean;
  notificationTime: string;
  umbrellaEnabled: boolean;
  parasolEnabled: boolean;
  heavySnowEnabled: boolean;
  outerwearEnabled: boolean;
  maskEnabled: boolean;
  waterEnabled: boolean;
  sunscreenEnabled: boolean;
  dailyWeatherEnabled: boolean;
}) {
  await db
    .prepare(
      `INSERT INTO notification_settings
      (installation_id, notification_enabled, notification_time, umbrella_enabled, parasol_enabled,
       heavy_snow_enabled, outerwear_enabled, mask_enabled, water_enabled, sunscreen_enabled, daily_weather_enabled, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        updated_at=excluded.updated_at`,
    )
    .bind(
      payload.installationId,
      payload.notificationEnabled ? 1 : 0,
      payload.notificationTime,
      payload.umbrellaEnabled ? 1 : 0,
      payload.parasolEnabled ? 1 : 0,
      payload.heavySnowEnabled ? 1 : 0,
      payload.outerwearEnabled ? 1 : 0,
      payload.maskEnabled ? 1 : 0,
      payload.waterEnabled ? 1 : 0,
      payload.sunscreenEnabled ? 1 : 0,
      payload.dailyWeatherEnabled ? 1 : 0,
      new Date().toISOString(),
      new Date().toISOString(),
    )
    .run();
}

