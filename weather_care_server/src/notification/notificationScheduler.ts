import { runLifestyleWeatherEngine } from '../lifestyle/lifestyleWeatherEngine';
import {
  enrichForecastWithEnvironmentalData,
  loadEnvironmentalData,
} from '../providers/environmental/environmentalDataService';
import { KmaWeatherProvider } from '../providers/weather/kmaWeatherProvider';
import { WeatherForecast } from '../providers/weather/weatherProvider';
import { regionMetadataForGrid } from '../regions/regionCatalog';
import { runRecommendationEngine } from '../recommendations/recommendationEngine';
import { runWeatherRuleEngineForHourly } from '../rules/weatherRuleEngine';
import { NotificationSettings, ServerEnv } from '../types';
import { FcmPayload, FcmSendResult, sendBatch } from './fcmClient';
import { BuiltNotification, buildNotification } from './notificationBuilder';

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
}

interface PendingNotification {
  installationId: string;
  targetDate: string;
  token: string;
  built: BuiltNotification;
}

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
  const pending: PendingNotification[] = [];

  for (const row of rows) {
    const local = localNotificationTime(now, row.timezone);
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
         COALESCE(s.daily_weather_enabled, 1) AS dailyWeatherEnabled
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
  event: 'recommendation_build_failed' | 'fcm_send_failed',
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
