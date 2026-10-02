import { runRecommendationNotificationJob } from '../notification/notificationScheduler';
import { ServerEnv } from '../types';
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

export async function runForecastRefreshJob(env: ServerEnv): Promise<void> {
  if (!env.DB) return;
  await runWeatherCollectionJob(env, { collectCore: true });
}

export async function runScheduledJobs(
  env: ServerEnv,
  cron: string,
  scheduledTime?: number,
): Promise<void> {
  const now = scheduledTime === undefined ? new Date() : new Date(scheduledTime);
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

export async function runRecommendationNotificationJobFromCron(
  env: ServerEnv,
  scheduledTime?: number,
): Promise<void> {
  // Use execution time, not a potentially delayed scheduledTime, for retention.
  const retention = await runDataRetentionJob(env.DB);
  console.log(JSON.stringify({ event: 'data_retention_completed', ...retention }));
  await clearExpiredEnrollmentData(env.DB);
  await runRecommendationNotificationJob(env, {
    now: scheduledTime === undefined ? undefined : new Date(scheduledTime),
    retentionNow: new Date(),
  });
}
