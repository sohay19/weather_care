import { runRecommendationNotificationJob } from '../notification/notificationScheduler';

export async function runForecastRefreshJob(env: any): Promise<void> {
  if (!env.DB) return;
  // TODO: 외부 API 호출 후 날씨 캐시 업데이트 및 active_regions 기반 refresh
  return;
}

export async function runRecommendationNotificationJobFromCron(env: any): Promise<void> {
  if (!env.DB) return;
  await runRecommendationNotificationJob(env);
}

