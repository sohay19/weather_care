import { Hono } from 'hono';
import { ServerEnv, Installation } from '../types';
import { regionFromQuery } from '../utils';
import { upsertInstallation } from '../database/installationsRepository';
import { upsertNotificationSettings } from '../database/notificationSettingsRepository';
import { getNotificationSettings } from '../database/notificationSettingsRepository';
import { notificationSettingsBodySchema } from '../validation/notificationSettings';
import { z } from 'zod';
import { ownerForRequest } from '../security/installationAccess';
import { bodyLimit } from 'hono/body-limit';
import { minimumAgeAssertionShape } from '../validation/minimumAge';

const installationBodySchema = z
  .object({
    ...minimumAgeAssertionShape,
    fcmToken: z.string().min(1).nullable().optional(),
    locationMode: z.enum(['GPS', 'MANUAL']).default('GPS'),
    platform: z.string().max(32).optional(),
    appVersion: z.string().max(64).optional(),
    timezone: z.string().min(1).max(64).default('Asia/Seoul'),
    latitude: z.number().min(30).max(44).nullable().optional(),
    longitude: z.number().min(120).max(134).nullable().optional(),
  })
  .strict()
  .refine(
    (value) =>
      (value.latitude == null && value.longitude == null) ||
      (value.latitude != null && value.longitude != null),
    { message: 'latitude and longitude must be supplied together' },
  );

const router = new Hono<{ Bindings: ServerEnv }>();
router.use('*', bodyLimit({ maxSize: 8192 }));

router.put('/:installationId', async (c) => {
  const installationId = c.req.param('installationId');
  const ownerHash = await ownerForRequest(c, installationId);
  if (!ownerHash) return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  const parsed = installationBodySchema.safeParse(await c.req.json<unknown>());
  if (!parsed.success) {
    return c.json({ error: 'INVALID_INSTALLATION' }, 400);
  }
  const body = parsed.data;
  const { nx, ny, topic } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
  const payload: Installation = {
    installationId,
    fcmToken: body.fcmToken ?? undefined,
    nx,
    ny,
    regionTopic: topic,
    locationMode: body.locationMode ?? 'GPS',
    platform: body.platform,
    appVersion: body.appVersion,
    timezone: body.timezone ?? 'Asia/Seoul',
    latitude: body.latitude ?? undefined,
    longitude: body.longitude ?? undefined,
    minimumAgeConfirmed: body.minimumAgeConfirmed,
    agePolicyVersion: body.agePolicyVersion,
  };
  if (!await upsertInstallation(c.env.DB, payload, ownerHash)) {
    return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  }
  return c.json({ ok: true });
});

router.put('/:installationId/notification-settings', async (c) => {
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
  const saved = await upsertNotificationSettings(c.env.DB, {
    ...current,
    ...parsed.data,
    installationId,
  }, ownerHash);
  if (!saved) return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  return c.json({ ok: true });
});

export default router;
