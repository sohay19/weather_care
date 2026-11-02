import { Hono } from 'hono';
import { bodyLimit } from 'hono/body-limit';
import { z } from 'zod';
import type { ServerEnv } from '../types';
import { bearerSecret, randomSecret, secretHash } from '../security/installationAccess';

// 폰의 설치 인증과 분리한 읽기/쓰기 권한이다. 원문 토큰/연결 코드는 저장하지 않는다.
const router = new Hono<{ Bindings: ServerEnv }>();
const CODE_TTL = 5 * 60_000;
const DATA_TTL = 24 * 3600_000;
const LINK_TTL = 90 * DATA_TTL;
const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const text = z.string().max(1200);
const preparation = z.object({ type: text, label: text });
const timeline = z.object({
  briefingId: text.optional(), sceneId: text.optional(), validFrom: text, validUntil: text,
  shortMessage: text, mediumMessage: text.optional(), longMessage: text.optional(),
  targetFrom: text.optional(), targetUntil: text.optional(), action: text.optional(),
  copyVariantKey: text.optional(), recommendedItems: z.array(text).max(40),
});
const widget = z.object({
  schemaVersion: z.number().optional(), generatedAt: text.optional(), receivedAt: text.optional(),
  locationKey: text.optional(), briefingId: text.optional(), sceneId: text.optional(),
  validFrom: text.optional(), validUntil: text.optional(), nextBriefingBoundary: text.optional(),
  dataFreshUntil: text.optional(), briefingTimeline: z.array(timeline).max(48).optional(),
  region: text.optional(), refreshTime: text.optional(), condition: text.optional(),
  currentTemperature: text.optional(), apparentTemperature: text.optional(), minimumTemperature: text.optional(),
  maximumTemperature: text.optional(), shortMessage: text.optional(), brief: text.optional(),
  nextTime: text.optional(), nextCondition: text.optional(), nextTemperature: text.optional(),
  preparations: z.array(preparation).max(40).optional(), preparationCatalog: z.array(preparation).max(40).optional(),
});
const snapshot = z.object({
  schemaVersion: z.literal(1), revision: z.number().int().positive().safe(),
  publishedAt: z.number().int().positive().safe(), cleared: z.boolean().optional(), widget,
  details: z.object({
    hours: z.array(z.object({ at: text, label: text, temperature: text, condition: text, rain: text })).max(48).optional(),
    metrics: z.array(z.object({ name: text, value: text, basis: text, description: text.optional() })).max(20).optional(),
    temperatureComparison: text.optional(), apparentComparison: text.optional(),
    preparationReasons: z.record(text).optional(),
  }).optional(),
}).refine(data => data.cleared || !!data.widget.locationKey && !!data.widget.generatedAt &&
  Number.isFinite(Date.parse(data.widget.generatedAt)), '워치 필수 자료 누락');
type Link = { id: string; writer_hash: string | null; code_expires_at: number; payload: string | null; published_at: number };

router.use('*', async (c, next) => {
  c.header('Cache-Control', 'no-store');
  await next();
});
router.use('*', bodyLimit({ maxSize: 90 * 1024, onError: c => c.json({ error: 'WEAR_DATA_TOO_LARGE' }, 413) }));

async function tokenHash(header: string | undefined) {
  const token = bearerSecret(header);
  return token ? secretHash(token) : null;
}

router.post('/pair', async c => {
  const hash = await tokenHash(c.req.header('Authorization'));
  if (!hash) return c.json({ error: 'WEAR_AUTH_REQUIRED' }, 401);
  const ip = c.req.header('CF-Connecting-IP') ?? 'unknown';
  if (!(await c.env.INSTALLATION_ENROLL_LIMIT.limit({ key: `wear-pair:${ip}` })).success) {
    return c.json({ error: 'WEAR_RATE_LIMITED' }, 429);
  }
  const now = Date.now();
  await c.env.DB.batch([
    c.env.DB.prepare('DELETE FROM wear_links WHERE (writer_hash IS NULL AND code_expires_at < ?) OR updated_at < ?')
      .bind(now, now - LINK_TTL),
    c.env.DB.prepare('UPDATE wear_links SET payload = NULL WHERE published_at < ? AND payload IS NOT NULL').bind(now - DATA_TTL),
  ]);
  const existing = await c.env.DB.prepare('SELECT writer_hash FROM wear_links WHERE reader_hash = ?').bind(hash).first<{ writer_hash: string | null }>();
  if (existing?.writer_hash) return c.json({ error: 'WEAR_ALREADY_LINKED' }, 409);
  const code = Array.from(crypto.getRandomValues(new Uint8Array(8)), n => alphabet[n & 31]).join('');
  await c.env.DB.prepare(`INSERT INTO wear_links (id, reader_hash, code_hash, code_expires_at, updated_at, created_at)
    VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(reader_hash) DO UPDATE SET code_hash=excluded.code_hash,
    code_expires_at=excluded.code_expires_at, updated_at=excluded.updated_at WHERE writer_hash IS NULL`)
    .bind(randomSecret(), hash, await secretHash(code), now + CODE_TTL, now, now).run();
  return c.json({ code, expiresAt: now + CODE_TTL }, 201);
});

router.post('/claim', async c => {
  const hash = await tokenHash(c.req.header('Authorization'));
  if (!hash) return c.json({ error: 'WEAR_AUTH_REQUIRED' }, 401);
  const ip = c.req.header('CF-Connecting-IP') ?? 'unknown';
  if (!(await c.env.INSTALLATION_ENROLL_LIMIT.limit({ key: `wear-claim:${ip}` })).success) {
    return c.json({ error: 'WEAR_RATE_LIMITED' }, 429);
  }
  const body = z.object({ code: z.string().regex(/^[A-HJ-NP-Z2-9]{8}$/) }).safeParse(await c.req.json().catch(() => null));
  if (!body.success) return c.json({ error: 'WEAR_INVALID_CODE' }, 400);
  const now = Date.now();
  const linked = await c.env.DB.prepare(`UPDATE wear_links SET writer_hash = ?, updated_at = ?
    WHERE code_hash = ? AND code_expires_at > ? AND (writer_hash IS NULL OR writer_hash = ?)
    RETURNING id`).bind(hash, now, await secretHash(body.data.code), now, hash).first<{ id: string }>();
  if (!linked) return c.json({ error: 'WEAR_INVALID_OR_EXPIRED_CODE' }, 404);
  return c.json({ linked: true });
});

router.get('/status', async c => {
  const hash = await tokenHash(c.req.header('Authorization'));
  if (!hash) return c.json({ error: 'WEAR_AUTH_REQUIRED' }, 401);
  const row = await c.env.DB.prepare(`SELECT id, writer_hash, code_expires_at, published_at FROM wear_links
    WHERE (reader_hash = ? OR writer_hash = ?) AND updated_at > ?`).bind(hash, hash, Date.now() - LINK_TTL).first<Link>();
  if (!row) return c.json({ error: 'WEAR_LINK_NOT_FOUND' }, 404);
  return c.json({ linked: row.writer_hash !== null, expiresAt: row.code_expires_at, publishedAt: row.published_at });
});

router.put('/snapshot', async c => {
  const hash = await tokenHash(c.req.header('Authorization'));
  if (!hash) return c.json({ error: 'WEAR_AUTH_REQUIRED' }, 401);
  const parsed = snapshot.safeParse(await c.req.json().catch(() => null));
  if (!parsed.success) return c.json({ error: 'WEAR_INVALID_SNAPSHOT' }, 400);
  const now = Date.now();
  if (parsed.data.publishedAt > now + 5 * 60_000) return c.json({ error: 'WEAR_INVALID_TIME' }, 400);
  // 정확한 좌표가 포함될 수 있는 위치 키는 서버 전달 전에 일방향 식별자로 치환한다.
  if (parsed.data.widget.locationKey) parsed.data.widget.locationKey = await secretHash(parsed.data.widget.locationKey);
  const row = await c.env.DB.prepare(`UPDATE wear_links SET payload = ?, published_at = ?, updated_at = ?
    WHERE writer_hash = ? AND updated_at > ? AND published_at <= ? RETURNING id`)
    .bind(JSON.stringify(parsed.data), parsed.data.publishedAt, now, hash, now - LINK_TTL, parsed.data.publishedAt).first<{ id: string }>();
  if (!row) {
    const exists = await c.env.DB.prepare('SELECT 1 FROM wear_links WHERE writer_hash = ? AND updated_at > ?').bind(hash, now - LINK_TTL).first();
    return exists ? c.json({ error: 'WEAR_OLDER_SNAPSHOT' }, 409) : c.json({ error: 'WEAR_LINK_NOT_FOUND' }, 404);
  }
  return c.json({ saved: true });
});

router.get('/snapshot', async c => {
  const hash = await tokenHash(c.req.header('Authorization'));
  if (!hash) return c.json({ error: 'WEAR_AUTH_REQUIRED' }, 401);
  const now = Date.now();
  const row = await c.env.DB.prepare(`UPDATE wear_links SET updated_at = ?,
    payload = CASE WHEN published_at > ? THEN payload ELSE NULL END WHERE reader_hash = ? AND updated_at > ?
    RETURNING id, writer_hash, code_expires_at, payload, published_at`).bind(now, now - DATA_TTL, hash, now - LINK_TTL).first<Link>();
  if (!row) return c.json({ error: 'WEAR_LINK_NOT_FOUND' }, 404);
  return c.json({ linked: row.writer_hash !== null, serverTime: now,
    payload: row.payload && row.published_at > now - DATA_TTL ? JSON.parse(row.payload) : null });
});

router.delete('/link', async c => {
  const hash = await tokenHash(c.req.header('Authorization'));
  if (!hash) return c.json({ error: 'WEAR_AUTH_REQUIRED' }, 401);
  await c.env.DB.prepare('DELETE FROM wear_links WHERE reader_hash = ? OR writer_hash = ?').bind(hash, hash).run();
  return c.json({ disconnected: true });
});
export default router;
