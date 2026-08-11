import { Hono } from 'hono';
import { ServerEnv } from './types';
import weatherRoutes from './api/weather';
import comparisonRoutes from './api/comparison';
import installationsRoutes from './api/installations';
import notificationSettingsRoutes from './api/notificationSettings';
import { runRecommendationNotificationJobFromCron } from './cron/jobs';

const app = new Hono<{ Bindings: ServerEnv }>();

app.get('/health', (c) => c.text('ok'));

app.route('/api/v1/weather', weatherRoutes);
app.route('/api/v1/weather/comparison', comparisonRoutes);
app.route('/api/v1/installations', installationsRoutes);
app.route('/api/v1/notification-settings', notificationSettingsRoutes);

app.get('/', (c) => c.json({ app: 'weather-care-server', version: '0.1.0' }));

export default {
  fetch: app.fetch,
  async scheduled(event: any, env: ServerEnv) {
    if (event.cron === '0 7 * * *' || event.cron === '10 5 * * *') {
      await runRecommendationNotificationJobFromCron(env);
    }
  },
};

