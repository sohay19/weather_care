import { Hono } from 'hono';
import { ServerEnv } from '../types';
import { upsertNotificationSettings } from '../database/notificationSettingsRepository';

const router = new Hono<{ Bindings: ServerEnv }>();

router.get('/', async (c) => {
  const id = c.req.query('installationId');
  if (!id) {
    return c.json({ error: 'installationId required' }, 400);
  }
  const row = c.env.DB
    ? await c.env.DB.prepare('SELECT * FROM notification_settings WHERE installation_id = ?').bind(id).first()
    : null;
  return c.json(row ?? {});
});

router.put('/:installationId', async (c) => {
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

