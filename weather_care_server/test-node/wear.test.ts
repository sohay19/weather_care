import { readFileSync } from 'node:fs';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { app } from '../src/index';
import { SqliteD1Database } from '../src/node/sqliteD1';
import { nodeServerEnv } from '../src/node/runtime';

let database: SqliteD1Database;
let env: ReturnType<typeof nodeServerEnv>;
const reader = 'a'.repeat(64), writer = 'b'.repeat(64), other = 'c'.repeat(64);
async function request(method: string, path: string, token?: string, body?: unknown) {
  return app.fetch(new Request(`https://example.com/api/v1/wear/${path}`, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  }), env);
}
const payload = (at = Date.now()) => ({ schemaVersion: 1, revision: 1, publishedAt: at,
  widget: { region: '서울', currentTemperature: '12°', generatedAt: new Date(at).toISOString(), locationKey: '37.123456,127.123456', latitude: 37.123456 },
  details: { metrics: [{ name: '습도', value: '50%', basis: '관측' }] }, secret: '보내면 안 되는 값' });
async function pair() {
  const response = await request('POST', 'pair', reader);
  expect(response.status).toBe(201);
  const data = await response.json() as { code: string; expiresAt: number };
  expect(data.code).toMatch(/^[A-HJ-NP-Z2-9]{8}$/);
  expect(data.expiresAt).toBeGreaterThan(Date.now());
  return data.code;
}
beforeEach(() => {
  database = new SqliteD1Database(':memory:');
  database.sqlite.exec(readFileSync('node-migrations/users/0009_wear_links.sql', 'utf8'));
  env = nodeServerEnv(database, {});
});
afterEach(() => { database.close(); vi.restoreAllMocks(); });

describe('워치 서버 연결', () => {
  it('코드 연결은 멱등이며 다른 폰이 이미 사용한 코드를 가져가지 못한다', async () => {
    const code = await pair();
    expect((await request('POST', 'claim', writer, { code })).status).toBe(200);
    expect((await request('POST', 'claim', writer, { code })).status).toBe(200);
    expect((await request('POST', 'claim', other, { code })).status).toBe(404);
    expect(await (await request('GET', 'status', reader)).json()).toMatchObject({ linked: true });
    expect((await request('POST', 'pair', reader)).status).toBe(409);
    const row = database.sqlite.prepare('SELECT * FROM wear_links').get() as Record<string, unknown>;
    expect(row.reader_hash).not.toBe(reader);
    expect(row.writer_hash).not.toBe(writer);
    expect(row.code_hash).not.toBe(code);
  });
  it('읽기/쓰기 권한을 분리하고 안전한 날씨 필드만 전달한다', async () => {
    const code = await pair();
    await request('POST', 'claim', writer, { code });
    expect((await request('PUT', 'snapshot', reader, payload())).status).toBe(404);
    expect((await request('PUT', 'snapshot', writer, payload())).status).toBe(200);
    expect((await request('GET', 'snapshot', writer)).status).toBe(404);
    expect((await request('GET', 'snapshot', other)).status).toBe(404);
    const response = await request('GET', 'snapshot', reader);
    expect(response.headers.get('Cache-Control')).toBe('no-store');
    const data = await response.json() as any;
    expect(data.linked).toBe(true);
    expect(data.payload.widget.region).toBe('서울');
    expect(data.payload.widget.locationKey).toMatch(/^[a-f0-9]{64}$/);
    expect(JSON.stringify(data)).not.toContain('37.123456');
    expect(data.payload.secret).toBeUndefined();
    expect(data.payload.widget.latitude).toBeUndefined();
  });
  it('늦은 자료를 거부하고 해제하면 양쪽의 접근을 즉시 막는다', async () => {
    await request('POST', 'claim', writer, { code: await pair() });
    const now = Date.now();
    await request('PUT', 'snapshot', writer, payload(now));
    expect((await request('PUT', 'snapshot', writer, payload(now - 1))).status).toBe(409);
    expect((await request('PUT', 'snapshot', writer, { schemaVersion: 1, revision: 2, publishedAt: now + 1, cleared: true, widget: {} })).status).toBe(200);
    expect((await (await request('GET', 'snapshot', reader)).json() as any).payload.cleared).toBe(true);
    expect((await request('DELETE', 'link', writer)).status).toBe(200);
    expect((await request('GET', 'snapshot', reader)).status).toBe(404);
    expect((await request('PUT', 'snapshot', writer, payload())).status).toBe(404);
  });
  it('만료 코드와 하루가 지난 저장 자료는 사용하지 않는다', async () => {
    const code = await pair();
    const stamp = Date.now();
    vi.spyOn(Date, 'now').mockReturnValue(stamp + 6 * 60_000);
    expect((await request('POST', 'claim', writer, { code })).status).toBe(404);
    vi.restoreAllMocks();
    await request('POST', 'claim', writer, { code: await pair() });
    await request('PUT', 'snapshot', writer, payload());
    vi.spyOn(Date, 'now').mockReturnValue(stamp + 25 * 3600_000);
    expect((await (await request('GET', 'snapshot', reader)).json() as any).payload).toBeNull();
  });
  it('인증·코드 형식·크기·미래 시각과 발급 횟수를 제한한다', async () => {
    expect((await request('POST', 'pair')).status).toBe(401);
    expect((await request('POST', 'claim', writer, { code: '123' })).status).toBe(400);
    expect((await request('PUT', 'snapshot', writer, payload(Date.now() + 600_000))).status).toBe(400);
    expect((await request('PUT', 'snapshot', writer, { ...payload(), revision: 0 })).status).toBe(400);
    expect((await request('PUT', 'snapshot', writer, { ...payload(), widget: {} })).status).toBe(400);
    expect((await request('PUT', 'snapshot', writer, { data: 'x'.repeat(100 * 1024) })).status).toBe(413);
    for (let i = 0; i < 20; i++) expect((await request('POST', 'pair', reader)).status).toBe(201);
    expect((await request('POST', 'pair', reader)).status).toBe(429);
  });
});
