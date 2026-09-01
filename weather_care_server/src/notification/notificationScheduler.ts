import { runLifestyleWeatherEngine } from '../lifestyle/lifestyleWeatherEngine';
import {
  enrichForecastWithEnvironmentalData,
  loadEnvironmentalData,
} from '../providers/environmental/environmentalDataService';
import { KmaWeatherProvider } from '../providers/weather/kmaWeatherProvider';
import { WeatherForecast } from '../providers/weather/weatherProvider';
import { KmaPrecipitationObservationProvider } from '../providers/precipitation/precipitationObservationProvider';
import {
  KmaWarningProvider,
  OfficialWeatherWarning,
} from '../providers/warnings/kmaWarningProvider';
import { regionMetadataForGrid } from '../regions/regionCatalog';
import { runRecommendationEngine } from '../recommendations/recommendationEngine';
import { runWeatherRuleEngineForHourly } from '../rules/weatherRuleEngine';
import {
  CurrentPrecipitationObservation,
  NotificationSettings,
  ServerEnv,
} from '../types';
import { FcmPayload, FcmSendResult, sendBatch } from './fcmClient';
import { BuiltNotification, buildNotification } from './notificationBuilder';
import {
  activeWarningNotification,
  changedWarningNotification,
  releasedWarningNotification,
} from '../presentation/officialWarningMessages';

interface NotificationInstallationRow {
  installationId: string;
  token: string;
  nx: number;
  ny: number;
  timezone: string;
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
  latitude: number | null;
  longitude: number | null;
  currentRainState: number;
}

interface PendingNotification {
  installationId: string;
  targetDate: string;
  token: string;
  built: BuiltNotification;
  rainObservedAt?: string;
  warningStateMutation?: WarningStateMutation;
}

interface WarningStateRow {
  typeCode: string;
  typeName: string;
  levelCode: '2' | '3';
  levelName: '주의보' | '경보';
  regionName: string;
  effectiveAt: string;
}

type WarningStateMutation =
  | { operation: 'UPSERT'; warning: OfficialWeatherWarning }
  | { operation: 'DELETE'; typeCode: string };

interface SchedulerDependencies {
  now?: Date;
  forecastLoader?: (
    env: ServerEnv,
    nx: number,
    ny: number,
  ) => Promise<WeatherForecast>;
  sender?: (
    env: ServerEnv,
    payloads: FcmPayload[],
  ) => Promise<FcmSendResult[]>;
  precipitationLoader?: (
    env: ServerEnv,
    latitude: number,
    longitude: number,
  ) => Promise<CurrentPrecipitationObservation>;
  warningLoader?: (
    env: ServerEnv,
    regionIds: readonly string[],
  ) => Promise<OfficialWeatherWarning[]>;
}

export async function runRecommendationNotificationJob(
  env: ServerEnv,
  dependencies: SchedulerDependencies = {},
): Promise<void> {
  const now = dependencies.now ?? new Date();
  const rows = await notificationInstallations(env.DB);
  if (rows.length === 0) return;

  const loadForecast = dependencies.forecastLoader ?? defaultForecastLoader;
  const forecastByRegion = new Map<string, Promise<WeatherForecast>>();
  const precipitationByLocation = new Map<
    string,
    Promise<CurrentPrecipitationObservation>
  >();
  const warningsByRegion = new Map<
    string,
    Promise<OfficialWeatherWarning[]>
  >();
  const pending: PendingNotification[] = [];

  for (const row of rows) {
    const local = localNotificationTime(now, row.timezone);
    await collectCurrentRainNotification(
      env,
      row,
      local.date,
      pending,
      precipitationByLocation,
      dependencies.precipitationLoader ?? defaultPrecipitationLoader,
    );
    await collectOfficialWarningNotifications(
      env,
      row,
      local.date,
      pending,
      warningsByRegion,
      dependencies.warningLoader ?? defaultWarningLoader,
    );
    const regionKey = `${row.nx}:${row.ny}`;
    let forecastPromise = forecastByRegion.get(regionKey);
    if (!forecastPromise) {
      forecastPromise = loadForecast(env, row.nx, row.ny);
      forecastByRegion.set(regionKey, forecastPromise);
    }

    try {
      const forecast = await forecastPromise;
      const hourly = forecast.hourly.slice(0, 24);
      const rules = runWeatherRuleEngineForHourly(hourly);
      const insights = runLifestyleWeatherEngine(rules, hourly);
      const recommendations = runRecommendationEngine(
        insights,
        settingsFromRow(row),
      ).filter(
        (recommendation) =>
          recommendation.recommended && recommendation.notificationEligible,
      );
      const alreadySent = await sentNotificationKeys(
        env.DB,
        row.installationId,
        local.date,
      );
      const notifications = buildNotification(recommendations).filter(
        (notification) => {
          if (alreadySent.has(notification.notification_key)) return false;
          if (notification.notification_key === 'MORNING_BRIEF') {
            return (
              row.dailyWeatherEnabled === 1 &&
              isNotificationTimeDue(local.time, row.notificationTime)
            );
          }
          return true;
        },
      );

      for (const built of notifications) {
        pending.push({
          installationId: row.installationId,
          targetDate: local.date,
          token: row.token,
          built,
        });
      }
    } catch (error) {
      logNotificationError('recommendation_build_failed', error, {
        installationId: row.installationId,
        regionKey,
      });
    }
  }

  if (pending.length === 0) return;
  const payloads = pending.map<FcmPayload>((item) => ({
    token: item.token,
    title: item.built.title,
    body: item.built.body,
    notificationKey: item.built.notification_key,
  }));
  const results = await (dependencies.sender ?? defaultSender)(env, payloads);
  await recordResults(env.DB, pending, results, now.toISOString());
}

async function notificationInstallations(
  db: D1Database,
): Promise<NotificationInstallationRow[]> {
  const result = await db
    .prepare(
      `SELECT
         i.installation_id AS installationId,
         i.fcm_token AS token,
         i.nx,
         i.ny,
         i.timezone,
         COALESCE(s.notification_time, '07:00') AS notificationTime,
         COALESCE(s.umbrella_enabled, 1) AS umbrellaEnabled,
         COALESCE(s.parasol_enabled, 1) AS parasolEnabled,
         COALESCE(s.heavy_snow_enabled, 1) AS heavySnowEnabled,
         COALESCE(s.outerwear_enabled, 1) AS outerwearEnabled,
         COALESCE(s.mask_enabled, 1) AS maskEnabled,
         COALESCE(s.water_enabled, 1) AS waterEnabled,
         COALESCE(s.sunscreen_enabled, 1) AS sunscreenEnabled,
         COALESCE(s.daily_weather_enabled, 1) AS dailyWeatherEnabled,
         COALESCE(s.heavy_rain_enabled, 1) AS heavyRainEnabled,
         COALESCE(s.heatwave_enabled, 1) AS heatwaveEnabled,
         COALESCE(s.cold_wave_enabled, 1) AS coldWaveEnabled,
         COALESCE(s.shower_light_rain_enabled, 1) AS showerAndLightRainEnabled,
         i.latitude,
         i.longitude,
         COALESCE(i.current_rain_state, 0) AS currentRainState
       FROM installations i
       LEFT JOIN notification_settings s
         ON s.installation_id = i.installation_id
       WHERE i.fcm_token IS NOT NULL
         AND TRIM(i.fcm_token) <> ''
         AND COALESCE(s.notification_enabled, 1) = 1`,
    )
    .all<NotificationInstallationRow>();
  return result.results;
}

async function sentNotificationKeys(
  db: D1Database,
  installationId: string,
  targetDate: string,
): Promise<Set<string>> {
  const result = await db
    .prepare(
      `SELECT notification_key AS notificationKey
       FROM notification_history
       WHERE installation_id = ? AND target_date = ?`,
    )
    .bind(installationId, targetDate)
    .all<{ notificationKey: string }>();
  return new Set(result.results.map((row) => row.notificationKey));
}

async function defaultForecastLoader(
  env: ServerEnv,
  nx: number,
  ny: number,
): Promise<WeatherForecast> {
  const forecast = await new KmaWeatherProvider({
    serviceKey: env.KMA_SERVICE_KEY,
  }).getForecastByRegion(nx, ny);
  const environmental = await loadEnvironmentalData(
    env,
    regionMetadataForGrid(nx, ny),
  );
  return enrichForecastWithEnvironmentalData(forecast, environmental);
}

async function defaultSender(
  env: ServerEnv,
  payloads: FcmPayload[],
): Promise<FcmSendResult[]> {
  return sendBatch(
    {
      projectId: env.FCM_PROJECT_ID,
      clientEmail: env.FCM_CLIENT_EMAIL,
      privateKey: env.FCM_PRIVATE_KEY,
    },
    payloads,
  );
}

async function defaultPrecipitationLoader(
  env: ServerEnv,
  latitude: number,
  longitude: number,
): Promise<CurrentPrecipitationObservation> {
  return new KmaPrecipitationObservationProvider({
    serviceKey: env.KMA_APIHUB_KEY,
  }).getCurrentByLocation(latitude, longitude);
}

async function defaultWarningLoader(
  env: ServerEnv,
  regionIds: readonly string[],
): Promise<OfficialWeatherWarning[]> {
  return new KmaWarningProvider({
    serviceKey: env.KMA_APIHUB_KEY,
  }).getActiveForRegions(regionIds);
}

async function collectOfficialWarningNotifications(
  env: ServerEnv,
  row: NotificationInstallationRow,
  targetDate: string,
  pending: PendingNotification[],
  warningsByRegion: Map<string, Promise<OfficialWeatherWarning[]>>,
  loader: (
    env: ServerEnv,
    regionIds: readonly string[],
  ) => Promise<OfficialWeatherWarning[]>,
): Promise<void> {
  if (!env.KMA_APIHUB_KEY) return;
  const region = regionMetadataForGrid(row.nx, row.ny);
  if (!region || region.warningRegionIds.length === 0) return;
  const regionKey = region.warningRegionIds.join(',');
  let warningsPromise = warningsByRegion.get(regionKey);
  if (!warningsPromise) {
    warningsPromise = loader(env, region.warningRegionIds);
    warningsByRegion.set(regionKey, warningsPromise);
  }

  try {
    const current = highestWarningByType(await warningsPromise);
    const previous = await warningStates(env.DB, row.installationId);
    const previousByType = new Map(previous.map((item) => [item.typeCode, item]));

    for (const warning of current.values()) {
      const before = previousByType.get(warning.typeCode);
      if (!before) {
        await queueOrApplyWarningTransition(
          env.DB,
          row,
          targetDate,
          pending,
          warningKey('ACTIVE', warning.typeCode, warning.validFrom),
          activeWarningNotification(warning, region.name),
          { operation: 'UPSERT', warning },
        );
      } else if (before.levelCode !== warning.levelCode) {
        await queueOrApplyWarningTransition(
          env.DB,
          row,
          targetDate,
          pending,
          warningKey('CHANGED', warning.typeCode, warning.validFrom),
          changedWarningNotification(warning, before.levelName, region.name),
          { operation: 'UPSERT', warning },
        );
      } else if (
        before.effectiveAt !== warning.validFrom ||
        before.regionName !== warning.regionName
      ) {
        await applyWarningStateMutation(env.DB, row.installationId, {
          operation: 'UPSERT',
          warning,
        });
      }
      previousByType.delete(warning.typeCode);
    }

    for (const before of previousByType.values()) {
      await queueOrApplyWarningTransition(
        env.DB,
        row,
        targetDate,
        pending,
        warningKey('RELEASED', before.typeCode, before.effectiveAt),
        releasedWarningNotification(
          { type: before.typeName, level: before.levelName },
          region.name,
        ),
        { operation: 'DELETE', typeCode: before.typeCode },
      );
    }
  } catch (error) {
    logNotificationError('official_warning_build_failed', error, {
      installationId: row.installationId,
      regionKey,
    });
  }
}

async function queueOrApplyWarningTransition(
  db: D1Database,
  row: NotificationInstallationRow,
  targetDate: string,
  pending: PendingNotification[],
  notificationKey: string,
  content: { title: string; body: string },
  mutation: WarningStateMutation,
): Promise<void> {
  const typeCode =
    mutation.operation === 'UPSERT'
      ? mutation.warning.typeCode
      : mutation.typeCode;
  if (!isWarningNotificationEnabled(row, typeCode)) {
    await applyWarningStateMutation(db, row.installationId, mutation);
    return;
  }
  pending.push({
    installationId: row.installationId,
    targetDate,
    token: row.token,
    built: {
      notification_key: notificationKey,
      title: content.title,
      body: content.body,
    },
    warningStateMutation: mutation,
  });
}

function highestWarningByType(
  warnings: readonly OfficialWeatherWarning[],
): Map<string, OfficialWeatherWarning> {
  const selected = new Map<string, OfficialWeatherWarning>();
  for (const warning of warnings) {
    const current = selected.get(warning.typeCode);
    if (!current || Number(warning.levelCode) > Number(current.levelCode)) {
      selected.set(warning.typeCode, warning);
    }
  }
  return selected;
}

async function warningStates(
  db: D1Database,
  installationId: string,
): Promise<WarningStateRow[]> {
  const result = await db
    .prepare(
      `SELECT warning_type AS typeCode,
              warning_name AS typeName,
              level_code AS levelCode,
              level_name AS levelName,
              region_name AS regionName,
              effective_at AS effectiveAt
       FROM installation_warning_state
       WHERE installation_id = ?`,
    )
    .bind(installationId)
    .all<WarningStateRow>();
  return result.results;
}

async function applyWarningStateMutation(
  db: D1Database,
  installationId: string,
  mutation: WarningStateMutation,
): Promise<void> {
  if (mutation.operation === 'DELETE') {
    await db
      .prepare(
        `DELETE FROM installation_warning_state
         WHERE installation_id = ? AND warning_type = ?`,
      )
      .bind(installationId, mutation.typeCode)
      .run();
    return;
  }

  const warning = mutation.warning;
  await db
    .prepare(
      `INSERT INTO installation_warning_state
       (installation_id, warning_type, warning_name, level_code, level_name,
        region_name, effective_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(installation_id, warning_type) DO UPDATE SET
         warning_name = excluded.warning_name,
         level_code = excluded.level_code,
         level_name = excluded.level_name,
         region_name = excluded.region_name,
         effective_at = excluded.effective_at,
         updated_at = excluded.updated_at`,
    )
    .bind(
      installationId,
      warning.typeCode,
      warning.type,
      warning.levelCode,
      warning.level,
      warning.regionName,
      warning.validFrom,
      new Date().toISOString(),
    )
    .run();
}

function isWarningNotificationEnabled(
  row: NotificationInstallationRow,
  typeCode: string,
): boolean {
  if (typeCode === 'R') return row.heavyRainEnabled === 1;
  if (typeCode === 'S') return row.heavySnowEnabled === 1;
  if (typeCode === 'H') return row.heatwaveEnabled === 1;
  if (typeCode === 'C') return row.coldWaveEnabled === 1;
  return true;
}

function warningKey(
  transition: 'ACTIVE' | 'CHANGED' | 'RELEASED',
  typeCode: string,
  effectiveAt: string,
): string {
  return `OFFICIAL_WARNING_${transition}_${typeCode}_${effectiveAt.replace(/\D/g, '')}`;
}

async function collectCurrentRainNotification(
  env: ServerEnv,
  row: NotificationInstallationRow,
  targetDate: string,
  pending: PendingNotification[],
  precipitationByLocation: Map<
    string,
    Promise<CurrentPrecipitationObservation>
  >,
  loader: (
    env: ServerEnv,
    latitude: number,
    longitude: number,
  ) => Promise<CurrentPrecipitationObservation>,
): Promise<void> {
  if (row.latitude === null || row.longitude === null) return;
  if (!env.KMA_APIHUB_KEY) return;
  const locationKey = `${row.latitude.toFixed(5)}:${row.longitude.toFixed(5)}`;
  let observationPromise = precipitationByLocation.get(locationKey);
  if (!observationPromise) {
    observationPromise = loader(env, row.latitude, row.longitude);
    precipitationByLocation.set(locationKey, observationPromise);
  }

  try {
    const observation = await observationPromise;
    if (observation.state === 'MISMATCH') return;
    if (observation.state === 'DRY') {
      if (row.currentRainState === 1) {
        await updateCurrentRainState(
          env.DB,
          row.installationId,
          false,
          observation.observedAt,
        );
      }
      return;
    }
    if (row.currentRainState === 1) return;
    if (row.umbrellaEnabled !== 1 || row.showerAndLightRainEnabled !== 1) {
      await updateCurrentRainState(
        env.DB,
        row.installationId,
        true,
        observation.observedAt,
      );
      return;
    }
    pending.push({
      installationId: row.installationId,
      targetDate,
      token: row.token,
      built: {
        notification_key: 'CURRENT_RAIN',
        title: '현재 강수 안내',
        body: '비가 내리고 있을 수 있어요. 지금 외출한다면 우산을 챙기세요',
      },
      rainObservedAt: observation.observedAt,
    });
  } catch (error) {
    logNotificationError('current_rain_build_failed', error, {
      installationId: row.installationId,
      locationKey,
    });
  }
}

async function updateCurrentRainState(
  db: D1Database,
  installationId: string,
  raining: boolean,
  observedAt: string,
): Promise<void> {
  await db
    .prepare(
      `UPDATE installations
       SET current_rain_state = ?, current_rain_observed_at = ?, updated_at = ?
       WHERE installation_id = ?`,
    )
    .bind(
      raining ? 1 : 0,
      observedAt,
      new Date().toISOString(),
      installationId,
    )
    .run();
}

async function recordResults(
  db: D1Database,
  pending: PendingNotification[],
  results: FcmSendResult[],
  sentAt: string,
): Promise<void> {
  const statements: D1PreparedStatement[] = [];
  results.forEach((result, index) => {
    const item = pending[index];
    if (!item) return;
    if (result.success) {
      statements.push(
        db
          .prepare(
            `INSERT OR IGNORE INTO notification_history
             (installation_id, target_date, notification_key, sent_at, payload_hash)
             VALUES (?, ?, ?, ?, ?)`,
          )
          .bind(
            item.installationId,
            item.targetDate,
            item.built.notification_key,
            sentAt,
            `${item.built.title}\n${item.built.body}`.slice(0, 160),
          ),
      );
      if (item.rainObservedAt) {
        statements.push(
          db
            .prepare(
              `UPDATE installations
               SET current_rain_state = 1,
                   current_rain_observed_at = ?,
                   updated_at = ?
               WHERE installation_id = ?`,
            )
            .bind(item.rainObservedAt, sentAt, item.installationId),
        );
      }
      if (item.warningStateMutation) {
        const mutation = item.warningStateMutation;
        if (mutation.operation === 'DELETE') {
          statements.push(
            db
              .prepare(
                `DELETE FROM installation_warning_state
                 WHERE installation_id = ? AND warning_type = ?`,
              )
              .bind(item.installationId, mutation.typeCode),
          );
        } else {
          const warning = mutation.warning;
          statements.push(
            db
              .prepare(
                `INSERT INTO installation_warning_state
                 (installation_id, warning_type, warning_name, level_code,
                  level_name, region_name, effective_at, updated_at)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                 ON CONFLICT(installation_id, warning_type) DO UPDATE SET
                   warning_name = excluded.warning_name,
                   level_code = excluded.level_code,
                   level_name = excluded.level_name,
                   region_name = excluded.region_name,
                   effective_at = excluded.effective_at,
                   updated_at = excluded.updated_at`,
              )
              .bind(
                item.installationId,
                warning.typeCode,
                warning.type,
                warning.levelCode,
                warning.level,
                warning.regionName,
                warning.validFrom,
                sentAt,
              ),
          );
        }
      }
    } else {
      logNotificationError('fcm_send_failed', undefined, {
        installationId: item.installationId,
        notificationKey: item.built.notification_key,
        status: result.status,
      });
    }
    if (result.unregistered) {
      statements.push(
        db
          .prepare(
            `UPDATE installations
             SET fcm_token = NULL, updated_at = ?
             WHERE installation_id = ? AND fcm_token = ?`,
          )
          .bind(sentAt, item.installationId, item.token),
      );
    }
  });
  if (statements.length > 0) await db.batch(statements);
}

function settingsFromRow(
  row: NotificationInstallationRow,
): Partial<NotificationSettings> {
  return {
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
  };
}

export function isNotificationTimeDue(
  currentTime: string,
  notificationTime: string,
): boolean {
  const current = minutesOfDay(currentTime);
  const target = minutesOfDay(notificationTime);
  if (current === undefined || target === undefined) return false;
  return current === (Math.ceil(target / 10) * 10) % (24 * 60);
}

function localNotificationTime(
  now: Date,
  timezone: string,
): { date: string; time: string } {
  try {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(now);
    const part = (type: Intl.DateTimeFormatPartTypes) =>
      parts.find((item) => item.type === type)?.value ?? '';
    return {
      date: `${part('year')}-${part('month')}-${part('day')}`,
      time: `${part('hour')}:${part('minute')}`,
    };
  } catch {
    return localNotificationTime(now, 'Asia/Seoul');
  }
}

function minutesOfDay(value: string): number | undefined {
  const match = /^(\d{2}):(\d{2})$/.exec(value);
  if (!match) return undefined;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return undefined;
  return hour * 60 + minute;
}

function logNotificationError(
  event:
    | 'recommendation_build_failed'
    | 'current_rain_build_failed'
    | 'official_warning_build_failed'
    | 'fcm_send_failed',
  error: unknown,
  context: Record<string, string | number>,
): void {
  console.error(
    JSON.stringify({
      event,
      ...context,
      error: error instanceof Error ? error.name : undefined,
    }),
  );
}
