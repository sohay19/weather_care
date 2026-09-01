import { runRecommendationNotificationJob } from '../notification/notificationScheduler';
import { ServerEnv } from '../types';

export async function runForecastRefreshJob(env: ServerEnv): Promise<void> {
  if (!env.DB) return;
  // TODO: 외부 API 호출 후 날씨 캐시 업데이트 및 active_regions 기반 refresh
  return;
}

export async function runRecommendationNotificationJobFromCron(
  env: ServerEnv,
  scheduledTime?: number,
): Promise<void> {
  await runRecommendationNotificationJob(env, {
    now: scheduledTime === undefined ? undefined : new Date(scheduledTime),
  });
}
