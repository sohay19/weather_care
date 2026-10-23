import { weatherDatabase } from '../database/weatherDatabase';
import { runRecommendationNotificationJob } from '../notification/notificationScheduler';
import { runLightningNotificationJob } from '../notification/lightningNotificationJob';
import { ServerEnv } from '../types';
import { collectGridHourly, collectGridLightning, collectGridRiverFlow,
  type GridExtraConfig } from '../collection/gridExtraCollection';
import { selectGridCollectionStations } from '../collection/gridStationSelection';
import { clearExpiredEnrollmentData } from '../security/installationAccess';
import { runDataRetentionJob } from '../database/dataRetention';
import {
  runCurrentObservationCollectionJob,
  runWeatherCollectionJob,
} from '../collection/weatherCollectionJob';

export const RADAR_COLLECTION_CRON = '2-59/15 * * * *';
export const ROAD_ICE_COLLECTION_CRON = '7-59/30 * * * *';
export const CORE_COLLECTION_CRON = '*/10 * * * *';
export const CURRENT_OBSERVATION_CRON = '*/2 * * * *';
export const GRID_HOURLY_CRON = '6 * * * *';
export const GRID_LIGHTNING_CRON = '5-59/10 * * * *';
export const GRID_RIVER_FLOW_CRON = '19 * * * *';

const emptyGridConfig: GridExtraConfig = {
  tideStations: [], buoyStations: [], forecastStations: [], ripCurrentBeaches: [],
  romsAreas: [], riverStations: [], dams: [],
};

export async function runForecastRefreshJob(env: ServerEnv): Promise<void> {
  if (!env.DB || env.WEATHER_COLLECTION_ENABLED === 'false') return;
  await runWeatherCollectionJob(env, { collectCore: true });
}

export async function runScheduledJobs(
  env: ServerEnv,
  cron: string,
  scheduledTime?: number,
  gridConfig?: GridExtraConfig,
): Promise<void> {
  if (env.WEATHER_COLLECTION_ENABLED === 'false') {
    if (cron === GRID_LIGHTNING_CRON) await runLightningNotificationJob(env);
    else if (cron === CORE_COLLECTION_CRON) await runRecommendationNotificationJobFromCron(env, scheduledTime);
    return;
  }
  const now = scheduledTime === undefined ? new Date() : new Date(scheduledTime);
  if (cron === GRID_HOURLY_CRON) {
    const config = await selectGridCollectionStations(env.DB, gridConfig ?? emptyGridConfig, env.COLLECTION_USER_DATABASES);
    await collectGridHourly({ db: weatherDatabase(env), config, now,
      khoaKey: decodePublicDataKey(env.KHOA_SERVICE_KEY || env.KMA_SERVICE_KEY),
      kwaterKey: decodePublicDataKey(env.KWATER_SERVICE_KEY || env.KMA_SERVICE_KEY),
      nifsKey: env.NIFS_API_KEY });
    return;
  }
  if (cron === GRID_LIGHTNING_CRON) {
    await collectGridLightning({ db: weatherDatabase(env), key: env.KMA_APIHUB_KEY, now });
    await runLightningNotificationJob(env);
    return;
  }
  if (cron === GRID_RIVER_FLOW_CRON) {
    if (env.HRFCO_API_KEY)
      await collectGridRiverFlow({ db: weatherDatabase(env), key: env.HRFCO_API_KEY, now });
    return;
  }
  if (cron === ROAD_ICE_COLLECTION_CRON) {
    await runWeatherCollectionJob(env, {
      now,
      collectCore: false,
      collectRoadIce: true,
    });
    return;
  }
  if (cron === RADAR_COLLECTION_CRON) {
    await runWeatherCollectionJob(env, {
      now,
      collectCore: false,
      collectRadar: true,
    });
    return;
  }
  if (cron === CURRENT_OBSERVATION_CRON) {
    if (now.getUTCMinutes() % 10 !== 0) {
      await runCurrentObservationCollectionJob(env, now);
    }
    return;
  }
  await runWeatherCollectionJob(env, {
    now,
    collectCore: true,
    collectRadar: false,
    collectRoadIce: false,
  });
  await runRecommendationNotificationJobFromCron(env, scheduledTime);
}

function decodePublicDataKey(key: string | undefined): string | undefined {
  if (!key) return undefined;
  try { return decodeURIComponent(key); }
  catch { return key; }
}

export async function runRecommendationNotificationJobFromCron(
  env: ServerEnv,
  scheduledTime?: number,
): Promise<void> {
  // Use execution time, not a potentially delayed scheduledTime, for retention.
  const retention = await runDataRetentionJob(env.DB, new Date(),
    env.WEATHER_COLLECTION_ENABLED === 'false' ? null : weatherDatabase(env));
  console.log(JSON.stringify({ event: 'data_retention_completed', ...retention }));
  await clearExpiredEnrollmentData(env.DB);
  await runRecommendationNotificationJob(env, {
    now: scheduledTime === undefined ? undefined : new Date(scheduledTime),
    retentionNow: new Date(),
  });
}
