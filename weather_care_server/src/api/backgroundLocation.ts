import { Hono } from 'hono';
import { z } from 'zod';
import type { ServerEnv } from '../types';
import { ownerForRequest } from '../security/installationAccess';
import { kmaGridFromCoordinates } from '../regions/kmaGridFromCoordinates';
import { minimumAgePolicyVersion } from '../validation/minimumAge';

const router = new Hono<{ Bindings: ServerEnv }>();
const sessionSchema = z.object({ revision: z.string().uuid().nullable() }).strict();
const locationSchema = z.object({
  revision: z.string().uuid(),
  latitude: z.number().min(30).max(44),
  longitude: z.number().min(120).max(134),
  accuracy: z.number().positive().max(5000),
  precise: z.boolean(),
  measuredAt: z.string().datetime(),
}).strict();

router.put('/:installationId/background-location', async (c) => {
  const id = c.req.param('installationId');
  const hash = await ownerForRequest(c, id);
  if (!hash) return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  const parsed = sessionSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: 'INVALID_BACKGROUND_LOCATION' }, 400);
  const revision = parsed.data.revision;
  const result = await c.env.DB.prepare(`UPDATE installations
    SET background_location_revision = ?
    WHERE installation_id = ?
      AND EXISTS (SELECT 1 FROM installation_credentials WHERE installation_id = ? AND secret_hash = ?)
      AND (? IS NULL OR (location_mode = 'GPS' AND minimum_age_confirmed_at IS NOT NULL
        AND age_policy_version = ? AND EXISTS (SELECT 1 FROM notification_settings
          WHERE installation_id = ? AND notification_enabled = 1)))`)
    .bind(revision, id, id, hash, revision, minimumAgePolicyVersion, id).run();
  if (revision !== null && !result.meta.changes) return c.json({ error: 'BACKGROUND_LOCATION_INACTIVE' }, 409);
  return c.json({ ok: true });
});

router.put('/:installationId/location', async (c) => {
  const id = c.req.param('installationId');
  const hash = await ownerForRequest(c, id);
  if (!hash) return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  const parsed = locationSchema.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: 'INVALID_LOCATION' }, 400);
  const body = parsed.data;
  const measured = new Date(body.measuredAt);
  const age = Date.now() - measured.getTime();
  // Delayed offline events must never move today's alerts to an old location.
  if (age > 15 * 60_000 || age < -60_000) return c.json({ error: 'LOCATION_EXPIRED' }, 422);
  const measuredAt = measured.toISOString();
  const { nx, ny } = kmaGridFromCoordinates(body.latitude, body.longitude);
  const precise = body.precise && body.accuracy <= 500;
  const result = await c.env.DB.prepare(`UPDATE installations
    SET nx = ?, ny = ?, region_topic = ?, latitude = ?, longitude = ?,
      location_measured_at = ?, updated_at = ?
    WHERE installation_id = ? AND location_mode = 'GPS' AND background_location_revision = ?
      AND minimum_age_confirmed_at IS NOT NULL AND age_policy_version = ?
      AND (location_measured_at IS NULL OR location_measured_at < ?)
      AND EXISTS (SELECT 1 FROM installation_credentials WHERE installation_id = ? AND secret_hash = ?)
      AND EXISTS (SELECT 1 FROM notification_settings WHERE installation_id = ? AND notification_enabled = 1)`)
    .bind(nx, ny, `weather_${nx}_${ny}`, precise ? body.latitude : null,
      precise ? body.longitude : null, measuredAt, new Date().toISOString(), id,
      body.revision, minimumAgePolicyVersion, measuredAt, id, hash, id).run();
  // A duplicate or older event is acknowledged, but a revoked session is not.
  if (!result.meta.changes) {
    const active = await c.env.DB.prepare(`SELECT 1 FROM installations i
      JOIN notification_settings n ON n.installation_id = i.installation_id
      WHERE i.installation_id = ? AND i.location_mode = 'GPS'
        AND i.background_location_revision = ? AND n.notification_enabled = 1
        AND i.minimum_age_confirmed_at IS NOT NULL AND i.age_policy_version = ?`)
      .bind(id, body.revision, minimumAgePolicyVersion).first();
    if (!active) return c.json({ error: 'BACKGROUND_LOCATION_INACTIVE' }, 409);
  }
  return c.json({ ok: true, updated: result.meta.changes > 0 });
});

export default router;
