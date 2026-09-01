import { Hono } from 'hono';
import {
  getNotificationSettings,
  upsertNotificationSettings,
} from '../database/notificationSettingsRepository';
import { NotificationSettings, ServerEnv } from '../types';
import { notificationSettingsBodySchema } from '../validation/notificationSettings';

const router = new Hono<{ Bindings: ServerEnv }>();

router.get('/', async (c) => {
  const installationId = c.req.query('installationId');
  if (!installationId) {
    return c.json({ error: 'installationId required' }, 400);
  }
  return c.json(
    await getNotificationSettings(c.env.DB, installationId),
  );
});

router.put('/:installationId', async (c) => {
  const installationId = c.req.param('installationId');
  const parsed = notificationSettingsBodySchema.safeParse(
    await c.req.json<unknown>(),
  );
  if (!parsed.success) {
    return c.json({ error: 'INVALID_NOTIFICATION_SETTINGS' }, 400);
  }
  const current = await getNotificationSettings(c.env.DB, installationId);
  const settings: NotificationSettings = {
    ...current,
    ...parsed.data,
    installationId,
  };
  await upsertNotificationSettings(c.env.DB, settings);
  return c.json(settings);
});

export default router;
