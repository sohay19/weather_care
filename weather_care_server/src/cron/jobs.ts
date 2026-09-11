import { runRecommendationNotificationJob } from '../notification/notificationScheduler';
import { ServerEnv } from '../types';
import { clearExpiredEnrollmentData } from '../security/installationAccess';
import { runDataRetentionJob } from '../database/dataRetention';

export async function runForecastRefreshJob(env: ServerEnv): Promise<void> {
  if (!env.DB) return;
  // TODO: 외부 API 호출 후 날씨 캐시 업데이트 및 active_regions 기반 refresh
  return;
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
