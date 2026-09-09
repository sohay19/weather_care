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

  it('fetches nationwide once and returns only events inside the requested bounds', async () => {
    const payload = successPayload([
      { linkId: 'inside', coordX: '127.02', coordY: '37.26' },
      { linkId: 'outside', coordX: '129.07', coordY: '35.18' },
    ]);
    const fetcher = vi.fn(async () => Response.json(payload));
    const baseUrl = await start(fetcher);

    const response = await relayRequest(baseUrl, validBounds());
    const second = await relayRequest(baseUrl, {
      minLongitude: 129.04,
      maxLongitude: 129.1,
      minLatitude: 35.15,
      maxLatitude: 35.21,
    });

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(successPayload([
      { linkId: 'inside', coordX: '127.02', coordY: '37.26' },
    ]));
    expect(await second.json()).toEqual(successPayload([
      { linkId: 'outside', coordX: '129.07', coordY: '35.18' },
    ]));
    expect(fetcher).toHaveBeenCalledTimes(1);
    const [rawUrl, init] = fetcher.mock.calls[0];
    const url = new URL(rawUrl.toString());
    expect(`${url.origin}${url.pathname}`).toBe(
      'https://openapi.its.go.kr:9443/eventInfo',
    );
    expect(url.searchParams.get('apiKey')).toBe('test-its-key');
    expect(url.searchParams.get('type')).toBe('all');
    expect(url.searchParams.get('eventType')).toBe('all');
    expect(url.searchParams.get('getType')).toBe('json');
    expect(url.searchParams.get('minX')).toBe('124');
    expect(url.searchParams.get('maxX')).toBe('132');
    expect(url.searchParams.get('minY')).toBe('32');
    expect(url.searchParams.get('maxY')).toBe('39.5');
    expect(init?.headers).toEqual({ accept: 'application/json' });
  });

  it('coalesces concurrent cache misses into one nationwide request', async () => {
    let release: ((response: Response) => void) | undefined;
    const upstream = new Promise<Response>((resolve) => {
      release = resolve;
    });
    const fetcher = vi.fn(() => upstream);
    const baseUrl = await start(fetcher);

    const first = relayRequest(baseUrl, validBounds());
    const second = relayRequest(baseUrl, validBounds());
    await vi.waitFor(() => expect(fetcher).toHaveBeenCalledTimes(1));
    release!(Response.json(successPayload([])));

    expect((await first).status).toBe(200);
    expect((await second).status).toBe(200);
    expect(fetcher).toHaveBeenCalledTimes(1);
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

  it('does not cache an official error payload', async () => {
    const fetcher = vi
      .fn()
      .mockResolvedValueOnce(
        Response.json({ response: { header: { resultCode: '9' } } }),
      )
      .mockResolvedValueOnce(Response.json(successPayload([])));
    const baseUrl = await start(fetcher);

    expect((await relayRequest(baseUrl, validBounds())).status).toBe(502);
    expect((await relayRequest(baseUrl, validBounds())).status).toBe(200);
    expect(fetcher).toHaveBeenCalledTimes(2);
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
      itsCacheTtlMs: 3_600_000,
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

function successPayload(items: Record<string, string>[]) {
  return {
    response: {
      header: { resultCode: '0' },
      body: { totalCount: items.length, items: { item: items } },
    },
  };
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
