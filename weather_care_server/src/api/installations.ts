import { Hono } from 'hono';
import { ServerEnv, Installation } from '../types';
import { regionFromQuery } from '../utils';
import { upsertInstallation } from '../database/installationsRepository';
import { upsertNotificationSettings } from '../database/notificationSettingsRepository';
import { getNotificationSettings } from '../database/notificationSettingsRepository';
import { notificationSettingsBodySchema } from '../validation/notificationSettings';

const router = new Hono<{ Bindings: ServerEnv }>();

router.put('/:installationId', async (c) => {
  const installationId = c.req.param('installationId');
  const body = await c.req.json<any>();
  const { nx, ny, topic } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
  const payload: Installation = {
    installationId,
    fcmToken: body.fcmToken,
    nx,
    ny,
    regionTopic: topic,
    locationMode: body.locationMode ?? 'GPS',
    platform: body.platform,
    appVersion: body.appVersion,
    timezone: body.timezone ?? 'Asia/Seoul',
  };
  await upsertInstallation(c.env.DB, payload);
  return c.json({ ok: true });
});

router.put('/:installationId/notification-settings', async (c) => {
  const installationId = c.req.param('installationId');
  const parsed = notificationSettingsBodySchema.safeParse(
    await c.req.json<unknown>(),
  );
  if (!parsed.success) {
    return c.json({ error: 'INVALID_NOTIFICATION_SETTINGS' }, 400);
  }
  const current = await getNotificationSettings(c.env.DB, installationId);
  await upsertNotificationSettings(c.env.DB, {
    ...current,
    ...parsed.data,
    installationId,
  });
  return c.json({ ok: true });
});

export default router;
