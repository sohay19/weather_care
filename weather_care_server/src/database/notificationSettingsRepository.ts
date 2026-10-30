import { NotificationSettings } from '../types';
import { defaultCommuteSchedule } from '../notification/commuteSchedule';

interface NotificationSettingsRow {
  installationId: string;
  notificationEnabled: number;
  notificationTime: string;
  commuteToWorkStart: string;
  commuteToWorkEnd: string;
  commuteFromWorkStart: string;
  commuteFromWorkEnd: string;
  umbrellaEnabled: number;
  parasolEnabled: number;
  heavySnowEnabled: number;
  outerwearEnabled: number;
  maskEnabled: number;
  waterEnabled: number;
  sunscreenEnabled: number;
  drynessEnabled: number | null;
  todayVisibilityEnabled: number;
  todayOzoneEnabled: number;
  todayWindEnabled: number;
  todayHumidityEnabled: number;
  todayApparentTemperatureEnabled: number;
  snowPreparationEnabled: number | null;
  uvPreparationEnabled: number | null;
  pollenEnabled: number | null;
  blackIceEnabled: number | null;
  carryNotificationEnabled: number | null;
  todayNotificationEnabled: number | null;
  weatherNotificationEnabled: number | null;
  dailyWeatherEnabled: number;
  heavyRainEnabled: number;
  heatwaveEnabled: number;
  coldWaveEnabled: number;
  showerAndLightRainEnabled: number;
  lightningEnabled: number;
  pipeFreezeEnabled: number;
}

export function defaultNotificationSettings(
  installationId: string,
): NotificationSettings {
  return {
    installationId,
    notificationEnabled: true,
    notificationTime: '07:00',
    ...defaultCommuteSchedule,
    umbrellaEnabled: true,
    parasolEnabled: true,
    heavySnowEnabled: true,
    outerwearEnabled: true,
    maskEnabled: true,
    waterEnabled: true,
    sunscreenEnabled: true,
    todayVisibilityEnabled: true,
    todayOzoneEnabled: true,
    todayWindEnabled: true,
    todayHumidityEnabled: true,
    todayApparentTemperatureEnabled: true,
    dailyWeatherEnabled: true,
    heavyRainEnabled: true,
    heatwaveEnabled: true,
    coldWaveEnabled: true,
    showerAndLightRainEnabled: true,
    lightningEnabled: true,
    pipeFreezeEnabled: true,
  };
}

export function mergeNotificationSettings(
  current: NotificationSettings,
  update: Partial<NotificationSettings>,
): NotificationSettings {
  const merged = { ...current, ...update };
  if (update.carryNotificationEnabled !== undefined || update.todayNotificationEnabled !== undefined) {
    merged.carryNotificationEnabled = update.carryNotificationEnabled ??
      current.carryNotificationEnabled ?? current.dailyWeatherEnabled;
    merged.todayNotificationEnabled = update.todayNotificationEnabled ??
      current.todayNotificationEnabled ?? current.dailyWeatherEnabled;
    merged.dailyWeatherEnabled = merged.carryNotificationEnabled || merged.todayNotificationEnabled;
  }
  return merged;
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
         commute_to_work_start AS commuteToWorkStart,
         commute_to_work_end AS commuteToWorkEnd,
         commute_from_work_start AS commuteFromWorkStart,
         commute_from_work_end AS commuteFromWorkEnd,
         umbrella_enabled AS umbrellaEnabled,
         parasol_enabled AS parasolEnabled,
         heavy_snow_enabled AS heavySnowEnabled,
         outerwear_enabled AS outerwearEnabled,
         mask_enabled AS maskEnabled,
         water_enabled AS waterEnabled,
         sunscreen_enabled AS sunscreenEnabled,
         dryness_enabled AS drynessEnabled,
         today_visibility_enabled AS todayVisibilityEnabled,
         today_ozone_enabled AS todayOzoneEnabled,
         today_wind_enabled AS todayWindEnabled,
         today_humidity_enabled AS todayHumidityEnabled,
         today_apparent_temperature_enabled AS todayApparentTemperatureEnabled,
         snow_preparation_enabled AS snowPreparationEnabled,
         uv_preparation_enabled AS uvPreparationEnabled,
         pollen_enabled AS pollenEnabled,
         black_ice_enabled AS blackIceEnabled,
         carry_notification_enabled AS carryNotificationEnabled,
         today_notification_enabled AS todayNotificationEnabled,
         weather_notification_enabled AS weatherNotificationEnabled,
         daily_weather_enabled AS dailyWeatherEnabled,
         heavy_rain_enabled AS heavyRainEnabled,
         heatwave_enabled AS heatwaveEnabled,
         cold_wave_enabled AS coldWaveEnabled,
         shower_light_rain_enabled AS showerAndLightRainEnabled,
         lightning_enabled AS lightningEnabled,
         pipe_freeze_enabled AS pipeFreezeEnabled
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
    commuteToWorkStart: row.commuteToWorkStart,
    commuteToWorkEnd: row.commuteToWorkEnd,
    commuteFromWorkStart: row.commuteFromWorkStart,
    commuteFromWorkEnd: row.commuteFromWorkEnd,
    umbrellaEnabled: row.umbrellaEnabled === 1,
    parasolEnabled: row.parasolEnabled === 1,
    heavySnowEnabled: row.heavySnowEnabled === 1,
    outerwearEnabled: row.outerwearEnabled === 1,
    maskEnabled: row.maskEnabled === 1,
    waterEnabled: row.waterEnabled === 1,
    sunscreenEnabled: row.sunscreenEnabled === 1,
    drynessEnabled: row.drynessEnabled == null ? undefined : row.drynessEnabled === 1,
    todayVisibilityEnabled: row.todayVisibilityEnabled !== 0,
    todayOzoneEnabled: row.todayOzoneEnabled !== 0,
    todayWindEnabled: row.todayWindEnabled !== 0,
    todayHumidityEnabled: row.todayHumidityEnabled !== 0,
    todayApparentTemperatureEnabled: row.todayApparentTemperatureEnabled !== 0,
    snowPreparationEnabled: row.snowPreparationEnabled == null ? undefined : row.snowPreparationEnabled === 1,
    uvPreparationEnabled: row.uvPreparationEnabled == null ? undefined : row.uvPreparationEnabled === 1,
    pollenEnabled: row.pollenEnabled == null ? undefined : row.pollenEnabled === 1,
    blackIceEnabled: row.blackIceEnabled == null ? undefined : row.blackIceEnabled === 1,
    carryNotificationEnabled: row.carryNotificationEnabled == null ? undefined : row.carryNotificationEnabled === 1,
    todayNotificationEnabled: row.todayNotificationEnabled == null ? undefined : row.todayNotificationEnabled === 1,
    weatherNotificationEnabled: row.weatherNotificationEnabled == null ? undefined : row.weatherNotificationEnabled === 1,
    dailyWeatherEnabled: row.dailyWeatherEnabled === 1,
    heavyRainEnabled: row.heavyRainEnabled === 1,
    heatwaveEnabled: row.heatwaveEnabled === 1,
    coldWaveEnabled: row.coldWaveEnabled === 1,
    showerAndLightRainEnabled: row.showerAndLightRainEnabled === 1,
    lightningEnabled: row.lightningEnabled === 1,
    pipeFreezeEnabled: row.pipeFreezeEnabled === 1,
  };
}

export async function upsertNotificationSettings(
  db: D1Database,
  payload: NotificationSettings,
  ownerHash?: string,
  // 요청 본문에 낙뢰 설정이 있는 경우만 true. 기본값 1과 앱 지원을 구분한다.
  lightningSupported = false,
): Promise<boolean> {
  const now = new Date().toISOString();
  const result = await db
    .prepare(
      `INSERT INTO notification_settings
      (installation_id, notification_enabled, notification_time,
       umbrella_enabled, parasol_enabled, heavy_snow_enabled,
       outerwear_enabled, mask_enabled, water_enabled, sunscreen_enabled,
       daily_weather_enabled, heavy_rain_enabled, heatwave_enabled,
       cold_wave_enabled, shower_light_rain_enabled, lightning_enabled, created_at, updated_at, lightning_supported, pipe_freeze_enabled,
       commute_to_work_start, commute_to_work_end, commute_from_work_start, commute_from_work_end, dryness_enabled,
       today_visibility_enabled, today_ozone_enabled, today_wind_enabled, today_humidity_enabled, today_apparent_temperature_enabled,
       snow_preparation_enabled, uv_preparation_enabled, pollen_enabled, black_ice_enabled, carry_notification_enabled, today_notification_enabled, weather_notification_enabled)
      SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      ${ownerHash === undefined ? 'WHERE 1' : `WHERE EXISTS (SELECT 1 FROM installation_credentials
        WHERE installation_id = ? AND secret_hash = ?)`}
      ON CONFLICT(installation_id) DO UPDATE SET
        notification_enabled=excluded.notification_enabled,
        notification_time=excluded.notification_time,
        commute_to_work_start=${payload.commuteToWorkStart === undefined ? 'notification_settings.commute_to_work_start' : 'excluded.commute_to_work_start'},
        commute_to_work_end=${payload.commuteToWorkEnd === undefined ? 'notification_settings.commute_to_work_end' : 'excluded.commute_to_work_end'},
        commute_from_work_start=${payload.commuteFromWorkStart === undefined ? 'notification_settings.commute_from_work_start' : 'excluded.commute_from_work_start'},
        commute_from_work_end=${payload.commuteFromWorkEnd === undefined ? 'notification_settings.commute_from_work_end' : 'excluded.commute_from_work_end'},
        umbrella_enabled=excluded.umbrella_enabled,
        parasol_enabled=excluded.parasol_enabled,
        heavy_snow_enabled=excluded.heavy_snow_enabled,
        outerwear_enabled=excluded.outerwear_enabled,
        mask_enabled=excluded.mask_enabled,
        water_enabled=excluded.water_enabled,
        sunscreen_enabled=excluded.sunscreen_enabled,
        dryness_enabled=${payload.drynessEnabled === undefined ? 'notification_settings.dryness_enabled' : 'excluded.dryness_enabled'},
        today_visibility_enabled=${payload.todayVisibilityEnabled === undefined ? 'notification_settings.today_visibility_enabled' : 'excluded.today_visibility_enabled'},
        today_ozone_enabled=${payload.todayOzoneEnabled === undefined ? 'notification_settings.today_ozone_enabled' : 'excluded.today_ozone_enabled'},
        today_wind_enabled=${payload.todayWindEnabled === undefined ? 'notification_settings.today_wind_enabled' : 'excluded.today_wind_enabled'},
        today_humidity_enabled=${payload.todayHumidityEnabled === undefined ? 'notification_settings.today_humidity_enabled' : 'excluded.today_humidity_enabled'},
        today_apparent_temperature_enabled=${payload.todayApparentTemperatureEnabled === undefined ? 'notification_settings.today_apparent_temperature_enabled' : 'excluded.today_apparent_temperature_enabled'},
        snow_preparation_enabled=${payload.snowPreparationEnabled === undefined ? 'notification_settings.snow_preparation_enabled' : 'excluded.snow_preparation_enabled'},
        uv_preparation_enabled=${payload.uvPreparationEnabled === undefined ? 'notification_settings.uv_preparation_enabled' : 'excluded.uv_preparation_enabled'},
        pollen_enabled=${payload.pollenEnabled === undefined ? 'notification_settings.pollen_enabled' : 'excluded.pollen_enabled'},
        black_ice_enabled=${payload.blackIceEnabled === undefined ? 'notification_settings.black_ice_enabled' : 'excluded.black_ice_enabled'},
        carry_notification_enabled=${payload.carryNotificationEnabled === undefined ? 'notification_settings.carry_notification_enabled' : 'excluded.carry_notification_enabled'},
        today_notification_enabled=${payload.todayNotificationEnabled === undefined ? 'notification_settings.today_notification_enabled' : 'excluded.today_notification_enabled'},
        weather_notification_enabled=${payload.weatherNotificationEnabled === undefined ? 'notification_settings.weather_notification_enabled' : 'excluded.weather_notification_enabled'},
        daily_weather_enabled=excluded.daily_weather_enabled,
        heavy_rain_enabled=excluded.heavy_rain_enabled,
        heatwave_enabled=excluded.heatwave_enabled,
        cold_wave_enabled=excluded.cold_wave_enabled,
        shower_light_rain_enabled=excluded.shower_light_rain_enabled,
        lightning_enabled=excluded.lightning_enabled,
        pipe_freeze_enabled=${payload.pipeFreezeEnabled === undefined ? 'notification_settings.pipe_freeze_enabled' : 'excluded.pipe_freeze_enabled'},
        lightning_supported=MAX(notification_settings.lightning_supported, excluded.lightning_supported),
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
      booleanInteger(payload.lightningEnabled),
      now,
      now,
      booleanInteger(lightningSupported),
      booleanInteger(payload.pipeFreezeEnabled !== false),
      payload.commuteToWorkStart ?? defaultCommuteSchedule.commuteToWorkStart,
      payload.commuteToWorkEnd ?? defaultCommuteSchedule.commuteToWorkEnd,
      payload.commuteFromWorkStart ?? defaultCommuteSchedule.commuteFromWorkStart,
      payload.commuteFromWorkEnd ?? defaultCommuteSchedule.commuteFromWorkEnd,
      payload.drynessEnabled === undefined ? null : booleanInteger(payload.drynessEnabled),
      booleanInteger(payload.todayVisibilityEnabled ?? true),
      booleanInteger(payload.todayOzoneEnabled ?? true),
      booleanInteger(payload.todayWindEnabled ?? true),
      booleanInteger(payload.todayHumidityEnabled ?? true),
      booleanInteger(payload.todayApparentTemperatureEnabled ?? true),
      payload.snowPreparationEnabled === undefined ? null : booleanInteger(payload.snowPreparationEnabled),
      payload.uvPreparationEnabled === undefined ? null : booleanInteger(payload.uvPreparationEnabled),
      payload.pollenEnabled === undefined ? null : booleanInteger(payload.pollenEnabled),
      payload.blackIceEnabled === undefined ? null : booleanInteger(payload.blackIceEnabled),
      payload.carryNotificationEnabled === undefined ? null : booleanInteger(payload.carryNotificationEnabled),
      payload.todayNotificationEnabled === undefined ? null : booleanInteger(payload.todayNotificationEnabled),
      payload.weatherNotificationEnabled === undefined ? null : booleanInteger(payload.weatherNotificationEnabled),
      ...(ownerHash === undefined ? [] : [payload.installationId, ownerHash]),
    )
    .run();
  return result.meta.changes > 0;
}

function booleanInteger(value: boolean): number {
  return value ? 1 : 0;
}
