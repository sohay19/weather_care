import type { AddressInfo } from 'node:net';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { createRelayServer } from '../src/server.js';

const TOKEN = 'test-relay-token-with-at-least-32-characters';
const servers: ReturnType<typeof createRelayServer>[] = [];

afterEach(async () => {
  await Promise.all(
    servers.splice(0).map(
      (server) =>
        new Promise<void>((resolve, reject) => {
          server.close((error) => (error ? reject(error) : resolve()));
        }),
    ),
  );
});

describe('ITS relay', () => {
  it('exposes a minimal unauthenticated health endpoint', async () => {
    const baseUrl = await start();

    const response = await fetch(`${baseUrl}/health`);

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ status: 'ok' });
    expect(response.headers.get('cache-control')).toBe('no-store');
  });

  it('rejects relay requests without the bearer token', async () => {
    const fetcher = vi.fn();
    const baseUrl = await start(fetcher);

    const response = await fetch(`${baseUrl}/v1/its/event-info`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(validBounds()),
    });

    expect(response.status).toBe(401);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('forwards only validated bounds and keeps the ITS key upstream', async () => {
    const payload = { response: { header: { resultCode: '0' } } };
    const fetcher = vi.fn(async () => Response.json(payload));
    const baseUrl = await start(fetcher);

    const response = await relayRequest(baseUrl, validBounds());

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(payload);
    const [rawUrl, init] = fetcher.mock.calls[0];
    const url = new URL(rawUrl.toString());
    expect(`${url.origin}${url.pathname}`).toBe(
      'https://openapi.its.go.kr:9443/eventInfo',
    );
    expect(url.searchParams.get('apiKey')).toBe('test-its-key');
    expect(url.searchParams.get('type')).toBe('all');
    expect(url.searchParams.get('eventType')).toBe('all');
    expect(url.searchParams.get('getType')).toBe('json');
    expect(init?.headers).toEqual({ accept: 'application/json' });
  });

  it('rejects coordinates outside Korea and oversized bounding boxes', async () => {
    const fetcher = vi.fn();
    const baseUrl = await start(fetcher);

    const outside = await relayRequest(baseUrl, {
      ...validBounds(),
      minLongitude: 120,
    });
    const tooWide = await relayRequest(baseUrl, {
      ...validBounds(),
      minLongitude: 126,
      maxLongitude: 127,
    });

    expect(outside.status).toBe(400);
    expect(tooWide.status).toBe(400);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('replaces upstream errors and non-JSON bodies with a safe response', async () => {
    const networkBaseUrl = await start(async () => {
      throw new Error('network error with secret-test-its-key');
    });
    const invalidJsonBaseUrl = await start(
      async () => new Response('<xml>failure</xml>'),
    );

    const network = await relayRequest(networkBaseUrl, validBounds());
    const invalidJson = await relayRequest(invalidJsonBaseUrl, validBounds());

    expect(network.status).toBe(502);
    expect(await network.json()).toEqual({ error: 'UPSTREAM_UNAVAILABLE' });
    expect(invalidJson.status).toBe(502);
    expect(await invalidJson.json()).toEqual({
      error: 'UPSTREAM_UNAVAILABLE',
    });
  });
});

async function start(fetcher: typeof fetch = fetch): Promise<string> {
  const server = createRelayServer({
    config: {
      host: '127.0.0.1',
      port: 0,
      itsApiKey: 'test-its-key',
      relayToken: TOKEN,
      upstreamTimeoutMs: 1_000,
    },
    fetcher,
  });
  servers.push(server);
  await new Promise<void>((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = server.address() as AddressInfo;
  return `http://127.0.0.1:${address.port}`;
}

function relayRequest(baseUrl: string, body: unknown): Promise<Response> {
  return fetch(`${baseUrl}/v1/its/event-info`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${TOKEN}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(body),
  });
}

function validBounds() {
  return {
    minLongitude: 126.9948,
    maxLongitude: 127.0624,
    minLatitude: 37.2367,
    maxLatitude: 37.2905,
  };
}
