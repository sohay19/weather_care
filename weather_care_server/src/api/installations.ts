import { Hono } from 'hono';
import { ServerEnv, Installation } from '../types';
import { regionFromQuery } from '../utils';
import { upsertInstallation } from '../database/installationsRepository';
import { upsertNotificationSettings } from '../database/notificationSettingsRepository';

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
  const body = await c.req.json<any>();
  await upsertNotificationSettings(c.env.DB, {
    installationId,
    notificationEnabled: body.notificationEnabled ?? true,
    notificationTime: body.notificationTime ?? '07:00',
    umbrellaEnabled: body.umbrellaEnabled ?? true,
    parasolEnabled: body.parasolEnabled ?? true,
    heavySnowEnabled: body.heavySnowEnabled ?? true,
    outerwearEnabled: body.outerwearEnabled ?? true,
    maskEnabled: body.maskEnabled ?? true,
    waterEnabled: body.waterEnabled ?? true,
    sunscreenEnabled: body.sunscreenEnabled ?? true,
    dailyWeatherEnabled: body.dailyWeatherEnabled ?? true,
  });
  return c.json({ ok: true });
});

export default router;

