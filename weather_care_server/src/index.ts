import { Hono } from 'hono';
import { ServerEnv } from './types';
import weatherRoutes from './api/weather';
import comparisonRoutes from './api/comparison';
import installationsRoutes from './api/installations';
import notificationSettingsRoutes from './api/notificationSettings';
import installationOwnershipRoutes from './api/installationOwnership';
import { runRecommendationNotificationJobFromCron } from './cron/jobs';
import { safeErrorName } from './observability/providerErrorDiagnostics';

const app = new Hono<{ Bindings: ServerEnv }>();

// Hono's default handler logs the original exception, which may contain user data.
app.onError((error, c) => {
  console.error(JSON.stringify({ event: 'request_failed', error: safeErrorName(error) }));
  return c.json({ error: 'INTERNAL_SERVER_ERROR' }, 500);
});

app.get('/health', (c) => c.text('ok'));

app.route('/api/v1/weather', weatherRoutes);
app.route('/api/v1/weather/comparison', comparisonRoutes);
app.route('/api/v1/installations', installationOwnershipRoutes);
app.route('/api/v1/installations', installationsRoutes);
app.route('/api/v1/notification-settings', notificationSettingsRoutes);

app.get('/', (c) => c.json({ app: 'weather-care-server', version: '0.1.0' }));

export default {
  fetch: app.fetch,
  async scheduled(event: ScheduledController, env: ServerEnv) {
    try {
      await runRecommendationNotificationJobFromCron(env, event.scheduledTime);
    } catch {
      // Preserve failed-job semantics without exposing the original error/cause.
      throw new Error('SCHEDULED_JOB_FAILED');
    }
  },
} satisfies ExportedHandler<ServerEnv>;
