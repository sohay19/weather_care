import { spawn, type ChildProcess } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';

const processes: ChildProcess[] = [];
const directories: string[] = [];
afterEach(async () => {
  for (const child of processes.splice(0)) {
    if (child.exitCode !== null) continue;
    await new Promise<void>((resolve) => { child.once('exit', () => resolve()); child.kill(); });
  }
  for (const path of directories.splice(0)) rmSync(path, { recursive: true, force: true });
});

async function start(key?: string) {
  const socket = createServer();
  await new Promise<void>((resolve) => socket.listen(0, '127.0.0.1', resolve));
  const port = (socket.address() as { port: number }).port;
  await new Promise<void>((resolve) => socket.close(() => resolve()));
  const directory = mkdtempSync(join(tmpdir(), 'weather-care-server-compat-'));
  directories.push(directory);
  const environment = { ...process.env,
    NODE_HOST: '127.0.0.1', NODE_PORT: String(port), NODE_DATABASE_PATH: join(directory, 'test.sqlite'),
    KMA_SERVICE_KEY: 'synthetic', KMA_APIHUB_KEY: 'synthetic', ITS_API_KEY: 'synthetic',
    FCM_CLIENT_EMAIL: 'synthetic', FCM_PRIVATE_KEY: 'synthetic',
    GA_ADMIN_CLIENT_EMAIL: 'synthetic', GA_ADMIN_PRIVATE_KEY: 'synthetic', TEST_ACCESS_KEY: key,
  };
  if (key === undefined) delete environment.TEST_ACCESS_KEY;
  const child = spawn(process.execPath, ['--import', 'tsx', 'src/node/server.ts'], {
    env: environment, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
  });
  processes.push(child);
  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('테스트 서버 기동 시간 초과')), 15_000);
    let output = '';
    child.stdout!.on('data', (chunk) => {
      output += String(chunk);
      if (output.includes('node_server_started')) { clearTimeout(timer); resolve(); }
    });
    child.once('error', (error) => { clearTimeout(timer); reject(error); });
    child.once('exit', () => { clearTimeout(timer); reject(new Error('테스트 서버 기동 실패')); });
  });
  return `http://127.0.0.1:${port}`;
}

describe('Node HTTP 접속의 운영·시험 키 분리', () => {
  it.each([undefined, '', '   '])('접근 키가 비어 있으면 기존 앱의 헤더 없는 요청을 허용한다: %s', async (key) => {
    const base = await start(key);
    const response = await fetch(`${base}/health`);
    expect(response.status).toBe(200);
    expect(await response.text()).toBe('ok');
  });

  it('실제 시험 키가 설정되면 누락·잘못된 키는 거부하고 올바른 키만 허용한다', async () => {
    const key = 'a'.repeat(64);
    const base = await start(key);
    for (const headers of [{}, { 'X-Weather-Care-Test-Key': 'b'.repeat(64) }]) {
      const response = await fetch(`${base}/health`, { headers });
      expect(response.status).toBe(403);
      expect(await response.json()).toEqual({ error: 'TEST_ACCESS_REQUIRED' });
    }
    expect((await fetch(`${base}/health`, { headers: { 'X-Weather-Care-Test-Key': key } })).status).toBe(200);
  });
});
