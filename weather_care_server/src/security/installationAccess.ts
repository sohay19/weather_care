import type { Context } from 'hono';
import { timingSafeEqual } from 'node:crypto';
import type { ServerEnv } from '../types';
import { recordInstallationActivity } from '../database/dataRetention';

export function bearerSecret(header: string | undefined): string | null {
  const match = /^Bearer ([0-9a-f]{64})$/.exec(header ?? '');
  return match?.[1] ?? null;
}

export function randomSecret(): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(32)),
    (byte) => byte.toString(16).padStart(2, '0')).join('');
}

export async function secretHash(secret: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(secret));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

function timingSafeDigestEqual(left: string, right: string): boolean {
  const leftBytes = new TextEncoder().encode(left);
  const rightBytes = new TextEncoder().encode(right);
  if (leftBytes.length !== rightBytes.length) return false;
  return timingSafeEqual(leftBytes, rightBytes);
}

export async function installationOwnerHash(
  db: D1Database, installationId: string, header: string | undefined,
): Promise<string | null> {
  const secret = bearerSecret(header);
  if (!secret) return null;
  const hash = await secretHash(secret);
  const row = await db.prepare(
    'SELECT secret_hash FROM installation_credentials WHERE installation_id = ?',
  ).bind(installationId).first<{ secret_hash: string }>();
  // Compare fixed-length digests in constant time; never log either value.
  if (!row || !timingSafeDigestEqual(hash, row.secret_hash)) return null;
  await recordInstallationActivity(db, installationId, hash);
  return hash;
}

export async function ownerForRequest(c: Context<{ Bindings: ServerEnv }>, id: string) {
  c.header('Cache-Control', 'no-store');
  return installationOwnerHash(c.env.DB, id, c.req.header('Authorization'));
}

export async function hasInstallationData(db: D1Database, id: string): Promise<boolean> {
  const row = await db.prepare(`SELECT 1 AS present WHERE
    EXISTS (SELECT 1 FROM installations WHERE installation_id = ?) OR
    EXISTS (SELECT 1 FROM notification_settings WHERE installation_id = ?) OR
    EXISTS (SELECT 1 FROM notification_history WHERE installation_id = ?) OR
    EXISTS (SELECT 1 FROM installation_warning_state WHERE installation_id = ?) OR
    EXISTS (SELECT 1 FROM installation_credentials WHERE installation_id = ?)`)
    .bind(id, id, id, id, id).first();
  return row !== null;
}

export async function deleteInstallationData(db: D1Database, id: string, hash: string): Promise<void> {
  // Authenticate again IN the atomic batch: an earlier route check is not a
  // transaction. Delete the credential last so every statement has the guard.
  const tables = ['notification_history', 'notification_settings',
    'installation_warning_state', 'installation_ownership_challenges', 'legacy_installation_ownership', 'installations'];
  await db.batch([
    ...tables.map((table) => db.prepare(`DELETE FROM ${table}
      WHERE installation_id = ? AND EXISTS (SELECT 1 FROM installation_credentials
        WHERE installation_id = ? AND secret_hash = ?)`)
      .bind(id, id, hash)),
    db.prepare('DELETE FROM installation_credentials WHERE installation_id = ? AND secret_hash = ?')
      .bind(id, hash),
  ]);
}

export async function clearExpiredEnrollmentData(db: D1Database): Promise<void> {
  await db.batch([
    db.prepare('DELETE FROM installation_ownership_challenges WHERE expires_at < ?')
      .bind(new Date().toISOString()),
    db.prepare(`DELETE FROM installation_credentials WHERE created_at < ?
      AND NOT EXISTS (SELECT 1 FROM installations i
        WHERE i.installation_id = installation_credentials.installation_id)
      AND NOT EXISTS (SELECT 1 FROM notification_settings s
        WHERE s.installation_id = installation_credentials.installation_id)`)
      .bind(new Date(Date.now() - 15 * 60_000).toISOString()),
  ]);
}
