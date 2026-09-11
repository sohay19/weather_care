import { env } from 'cloudflare:test';
import { secretHash } from '../src/security/installationAccess';

// Public synthetic credentials, used ONLY with isolated test D1 bindings.
export const testSecret = 'a'.repeat(64);
export const testAuthHeaders = { Authorization: `Bearer ${testSecret}`, 'Content-Type': 'application/json' };
export async function authorizeFixture(id = 'device-1') {
  await env.DB.prepare(`CREATE TABLE IF NOT EXISTS installation_activity (
    installation_id TEXT PRIMARY KEY, last_active_at TEXT NOT NULL)`).run();
  await env.DB.prepare(`CREATE TABLE IF NOT EXISTS installation_credentials (
    installation_id TEXT PRIMARY KEY, secret_hash TEXT NOT NULL, created_at TEXT NOT NULL)`).run();
  await env.DB.prepare('INSERT OR REPLACE INTO installation_credentials VALUES (?, ?, ?)')
    .bind(id, await secretHash(testSecret), new Date().toISOString()).run();
}
