// Opt-in smoke check: creates a new synthetic installation and deletes ONLY it.
// Never accepts an existing installation ID, FCM token, location or secret.
import { randomBytes } from 'node:crypto';
import assert from 'node:assert/strict';

const target = process.argv[2];
if (!target) throw new Error('Supply the server base URL explicitly');
const base = new URL(target);
if (base.protocol !== 'https:' && base.hostname !== 'localhost' && base.hostname !== '127.0.0.1') {
  throw new Error('HTTPS is required outside localhost');
}
const secret = randomBytes(32).toString('hex');
const headers = { Authorization: `Bearer ${secret}`, 'Content-Type': 'application/json' };
let fixtureId;
let deleted = false;
async function request(method, path, body, auth = headers) {
  return fetch(new URL(path, base), { method, headers: auth,
    body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(20_000) });
}
try {
  const enroll = await request('POST', '/api/v1/installations/enroll', {});
  assert.equal(enroll.status, 201, 'synthetic enrollment');
  fixtureId = (await enroll.json()).installationId;
  assert.match(fixtureId, /^wc_[A-Za-z0-9_-]{20,80}$/);
  const profile = `/api/v1/installations/${fixtureId}`;
  const preferences = `/api/v1/notification-settings/${fixtureId}`;
  assert.equal((await request('PUT', preferences, { notificationEnabled: false })).status, 200, 'notifications off');
  assert.equal((await request('PUT', `${profile}?nx=60&ny=121`, {
    fcmToken: null, locationMode: 'MANUAL', platform: 'deletion-smoke-test',
    appVersion: 'synthetic-deletion-check', latitude: null, longitude: null,
  })).status, 200, 'synthetic registration');
  const before = await request('GET', `/api/v1/notification-settings?installationId=${fixtureId}`);
  assert.equal(before.status, 200, 'authenticated settings read');
  assert.equal((await before.json()).notificationEnabled, false);
  assert.equal((await request('GET', `${profile}/status`)).status, 200, 'authenticated registration status');
  assert.equal((await request('DELETE', profile, undefined,
    { ...headers, Authorization: `Bearer ${randomBytes(32).toString('hex')}` })).status, 401, 'wrong owner rejected');
  assert.equal((await request('DELETE', profile)).status, 204, 'delete succeeds');
  deleted = true;
  assert.equal((await request('DELETE', profile)).status, 204, 'idempotent retry');
  assert.equal((await request('PUT', profile, { locationMode: 'MANUAL' })).status, 401, 'registration replay rejected');
  assert.equal((await request('PUT', preferences, { notificationEnabled: true })).status, 401, 'settings replay rejected');
  assert.equal((await request('GET', `/api/v1/notification-settings?installationId=${fixtureId}`)).status, 401, 'old credential revoked');
  const missing = await request('GET', `${profile}/status`);
  assert.equal(missing.status, 410, 'missing registration confirmed');
  assert.equal((await missing.json()).error, 'INSTALLATION_GONE');
  console.log('PASS: new synthetic fixture only; authenticated deletion/retry/replay checks; no FCM or coordinates; fixture removed.');
} finally {
  if (fixtureId && !deleted) {
    const result = await request('DELETE', `/api/v1/installations/${fixtureId}`);
    if (result.status !== 204) {
      // Only a new synthetic ID is printed for operator cleanup; never a secret.
      console.error(`Synthetic fixture cleanup requires attention: ${fixtureId}`);
      process.exitCode = 1;
    }
  }
}
