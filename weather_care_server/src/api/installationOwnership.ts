import { Hono } from 'hono';
import { bodyLimit } from 'hono/body-limit';
import { z } from 'zod';
import type { ServerEnv } from '../types';
import { sendOwnershipChallenge } from '../notification/fcmClient';
import { bearerSecret, clearExpiredEnrollmentData, deleteInstallationData,
  hasInstallationData, ownerForRequest, randomSecret, secretHash } from '../security/installationAccess';

const idSchema = z.string().regex(/^wc_[A-Za-z0-9_-]{20,80}$/);
const enrollSchema = z.object({ legacyInstallationId: idSchema.optional() }).strict();
const challengeSchema = z.object({ requestId: z.string().regex(/^[0-9a-f]{64}$/) }).strict();
const claimSchema = challengeSchema.extend({ proof: z.string().regex(/^[0-9a-f]{64}$/) });
const router = new Hono<{ Bindings: ServerEnv }>();
router.use('*', bodyLimit({ maxSize: 4096 }));
router.use('*', async (c, next) => { c.header('Cache-Control', 'no-store'); await next(); });

router.post('/enroll', async (c) => {
  const secret = bearerSecret(c.req.header('Authorization'));
  if (!secret) return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  const { success } = await c.env.INSTALLATION_ENROLL_LIMIT.limit({
    key: `enroll:${c.req.header('CF-Connecting-IP') ?? 'unknown'}`,
  });
  if (!success) {
    c.header('Retry-After', '60');
    return c.json({ error: 'ENROLL_RETRY_LATER' }, 429);
  }
  const parsed = enrollSchema.safeParse(await c.req.json<unknown>().catch(() => null));
  if (!parsed.success) return c.json({ error: 'INVALID_ENROLLMENT' }, 400);
  const legacyId = parsed.data.legacyInstallationId;
  if (legacyId && await hasInstallationData(c.env.DB, legacyId)) {
    if (await ownerForRequest(c, legacyId)) return c.json({ installationId: legacyId });
    // Knowing an old ID is never sufficient to adopt or delete it.
    return c.json({ error: 'LEGACY_VERIFICATION_REQUIRED' }, 409);
  }
  await clearExpiredEnrollmentData(c.env.DB);
  const id = `wc_${crypto.randomUUID()}`;
  await c.env.DB.prepare(`INSERT INTO installation_credentials
    (installation_id, secret_hash, created_at) VALUES (?, ?, ?)`)
    .bind(id, await secretHash(secret), new Date().toISOString()).run();
  return c.json({ installationId: id }, 201);
});

router.post('/:installationId/ownership-challenge', async (c) => {
  const id = c.req.param('installationId');
  const secret = bearerSecret(c.req.header('Authorization'));
  if (!secret) return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  const parsed = challengeSchema.safeParse(await c.req.json<unknown>().catch(() => null));
  if (!idSchema.safeParse(id).success || !parsed.success) return c.json({ error: 'INVALID_CHALLENGE' }, 400);
  const legacy = await c.env.DB.prepare(`SELECT fcm_token FROM legacy_installation_ownership
    WHERE installation_id = ? AND NOT EXISTS (SELECT 1 FROM installation_credentials
      WHERE installation_id = ?)`)
    .bind(id, id).first<{ fcm_token: string | null }>();
  if (!legacy?.fcm_token) return c.json({ error: 'OWNERSHIP_UNAVAILABLE' }, 409);
  const now = Date.now();
  const proof = randomSecret();
  const result = await c.env.DB.prepare(`INSERT INTO installation_ownership_challenges
    (installation_id, request_id, secret_hash, proof_hash, created_at, expires_at)
    SELECT ?, ?, ?, ?, ?, ? WHERE EXISTS (SELECT 1 FROM installations WHERE installation_id = ?)
      AND NOT EXISTS (SELECT 1 FROM installation_credentials WHERE installation_id = ?)
    ON CONFLICT(installation_id) DO UPDATE SET request_id=excluded.request_id,
      secret_hash=excluded.secret_hash, proof_hash=excluded.proof_hash,
      created_at=excluded.created_at, expires_at=excluded.expires_at
    WHERE installation_ownership_challenges.created_at < ?`)
    .bind(id, parsed.data.requestId, await secretHash(secret), await secretHash(proof),
      new Date(now).toISOString(), new Date(now + 5 * 60_000).toISOString(), id, id,
      new Date(now - 60_000).toISOString()).run();
  if (!result.meta.changes) return c.json({ error: 'CHALLENGE_RETRY_LATER' }, 429);
  try {
    // Send only to the pre-existing server token. Never accept a caller's token
    // here, and never include the proof in the HTTP response or logs.
    await sendOwnershipChallenge({ projectId: c.env.FCM_PROJECT_ID,
      clientEmail: c.env.FCM_CLIENT_EMAIL, privateKey: c.env.FCM_PRIVATE_KEY },
      legacy.fcm_token, { installationId: id, requestId: parsed.data.requestId, proof });
  } catch {
    return c.json({ error: 'OWNERSHIP_DELIVERY_FAILED' }, 503);
  }
  return c.json({ ok: true });
});

router.post('/:installationId/claim', async (c) => {
  const id = c.req.param('installationId');
  const secret = bearerSecret(c.req.header('Authorization'));
  if (!secret) return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  if (await ownerForRequest(c, id)) return c.json({ installationId: id });
  const parsed = claimSchema.safeParse(await c.req.json<unknown>().catch(() => null));
  if (!parsed.success) return c.json({ error: 'INVALID_PROOF' }, 400);
  const hash = await secretHash(secret);
  await c.env.DB.batch([
    c.env.DB.prepare(`INSERT OR IGNORE INTO installation_credentials
      (installation_id, secret_hash, created_at)
      SELECT installation_id, secret_hash, ? FROM installation_ownership_challenges ch
      WHERE installation_id = ? AND request_id = ? AND secret_hash = ?
        AND proof_hash = ? AND expires_at >= ?
        AND EXISTS (SELECT 1 FROM installations i WHERE i.installation_id = ch.installation_id)`)
      .bind(new Date().toISOString(), id, parsed.data.requestId, hash,
        await secretHash(parsed.data.proof), new Date().toISOString()),
    c.env.DB.prepare(`DELETE FROM installation_ownership_challenges WHERE installation_id = ?
      AND EXISTS (SELECT 1 FROM installation_credentials WHERE installation_id = ? AND secret_hash = ?)`)
      .bind(id, id, hash),
    c.env.DB.prepare(`DELETE FROM legacy_installation_ownership WHERE installation_id = ?
      AND EXISTS (SELECT 1 FROM installation_credentials WHERE installation_id = ? AND secret_hash = ?)`)
      .bind(id, id, hash),
  ]);
  if (!await ownerForRequest(c, id)) return c.json({ error: 'OWNERSHIP_PROOF_REJECTED' }, 403);
  return c.json({ installationId: id });
});

router.delete('/:installationId', async (c) => {
  const id = c.req.param('installationId');
  if (!idSchema.safeParse(id).success) return c.json({ error: 'INVALID_INSTALLATION' }, 400);
  if (!bearerSecret(c.req.header('Authorization'))) return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  const hash = await ownerForRequest(c, id);
  if (!hash) {
    // Idempotent response after an uncertain successful deletion. No data is
    // touched in this branch; an existing installation always requires proof.
    if (!await hasInstallationData(c.env.DB, id)) return c.body(null, 204);
    return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  }
  await deleteInstallationData(c.env.DB, id, hash);
  return c.body(null, 204);
});

router.get('/:installationId/status', async (c) => {
  const id = c.req.param('installationId');
  if (!idSchema.safeParse(id).success) return c.json({ error: 'INVALID_INSTALLATION' }, 400);
  if (!bearerSecret(c.req.header('Authorization'))) return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  // Same existence disclosure as idempotent DELETE. Never reveal any fields
  // from an existing installation to the holder of a different secret.
  if (!await hasInstallationData(c.env.DB, id)) return c.json({ error: 'INSTALLATION_GONE' }, 410);
  if (!await ownerForRequest(c, id)) return c.json({ error: 'INSTALLATION_AUTH_REQUIRED' }, 401);
  return c.json({ registered: true });
});

export default router;
