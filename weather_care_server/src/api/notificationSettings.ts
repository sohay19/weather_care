import { Hono } from 'hono';
import {
  getNotificationSettings,
  upsertNotificationSettings,
} from '../database/notificationSettingsRepository';
import { NotificationSettings, ServerEnv } from '../types';
import { notificationSettingsBodySchema } from '../validation/notificationSettings';
import { ownerForRequest } from '../security/installationAccess';
import { bodyLimit } from 'hono/body-limit';

const router = new Hono<{ Bindings: ServerEnv }>();
router.use('*', bodyLimit({ maxSize: 8192 }));

router.get('/', async (c) => {
  const installationId = c.req.query('installationId');
  if (!installationId) {
    return c.json({ error: 'installationId required' }, 400);
  }
  if (!await ownerForRequest(c, installationId)) return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  return c.json(
    await getNotificationSettings(c.env.DB, installationId),
  );
});

router.put('/:installationId', async (c) => {
  const installationId = c.req.param('installationId');
  const ownerHash = await ownerForRequest(c, installationId);
  if (!ownerHash) return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
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
  if (!await upsertNotificationSettings(c.env.DB, settings, ownerHash)) {
    return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  }
  return c.json(settings);
});

export default router;
