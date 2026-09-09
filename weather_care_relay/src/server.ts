import { createHash, timingSafeEqual } from 'node:crypto';
import {
  createServer,
  type IncomingMessage,
  type Server,
  type ServerResponse,
} from 'node:http';
import type { RelayConfig } from './config.js';

const ITS_EVENT_URL = 'https://openapi.its.go.kr:9443/eventInfo';
const MAX_REQUEST_BYTES = 4 * 1024;
const MAX_UPSTREAM_BYTES = 2 * 1024 * 1024;
const MAX_BOUNDING_BOX_SPAN_DEGREES = 0.25;
const KOREA_BOUNDS: BoundingBoxRequest = {
  minLongitude: 124,
  maxLongitude: 132,
  minLatitude: 32,
  maxLatitude: 39.5,
};

interface BoundingBoxRequest {
  minLongitude: number;
  maxLongitude: number;
  minLatitude: number;
  maxLatitude: number;
}

export interface RelayServerOptions {
  config: RelayConfig;
  fetcher?: typeof fetch;
  now?: () => number;
}

export function createRelayServer(options: RelayServerOptions): Server {
  const fetcher = options.fetcher ?? fetch;
  const loadNationwideEvents = nationwideItsLoader(
    options.config,
    fetcher,
    options.now ?? Date.now,
  );
  return createServer((request, response) => {
    void handleRequest(
      request,
      response,
      options.config,
      loadNationwideEvents,
    ).catch(
      (error: unknown) => {
        log('relay_request_failed', {
          error: error instanceof Error ? error.name : 'UnknownError',
        });
        sendJson(response, 500, { error: 'INTERNAL_ERROR' });
      },
    );
  });
}

async function handleRequest(
  request: IncomingMessage,
  response: ServerResponse,
  config: RelayConfig,
  loadNationwideEvents: () => Promise<unknown>,
): Promise<void> {
  if (request.method === 'GET' && request.url === '/health') {
    sendJson(response, 200, { status: 'ok' });
    return;
  }

  if (request.method !== 'POST' || request.url !== '/v1/its/event-info') {
    sendJson(response, 404, { error: 'NOT_FOUND' });
    return;
  }

  if (!authorized(request.headers.authorization, config.relayToken)) {
    sendJson(response, 401, { error: 'UNAUTHORIZED' });
    return;
  }

  if (!request.headers['content-type']?.toLowerCase().startsWith('application/json')) {
    sendJson(response, 415, { error: 'JSON_REQUIRED' });
    return;
  }

  let bounds: BoundingBoxRequest;
  try {
    bounds = parseBounds(await readJsonBody(request));
  } catch (error) {
    const status = error instanceof PayloadTooLargeError ? 413 : 400;
    sendJson(response, status, {
      error: status === 413 ? 'PAYLOAD_TOO_LARGE' : 'INVALID_REQUEST',
    });
    return;
  }

  try {
    const payload = await loadNationwideEvents();
    sendJson(response, 200, filterItsPayload(payload, bounds));
  } catch (error) {
    log('its_upstream_failed', {
      error:
        error instanceof UpstreamResponseError
          ? error.name
          : error instanceof Error && error.name === 'TimeoutError'
            ? 'TimeoutError'
            : 'NetworkError',
    });
    sendJson(response, 502, { error: 'UPSTREAM_UNAVAILABLE' });
  }
}

function nationwideItsLoader(
  config: RelayConfig,
  fetcher: typeof fetch,
  now: () => number,
): () => Promise<unknown> {
  let cached: { payload: unknown; expiresAt: number } | undefined;
  let refresh: Promise<unknown> | undefined;

  return async () => {
    const current = now();
    if (cached && current < cached.expiresAt) return cached.payload;
    if (refresh) return refresh;

    refresh = fetchNationwideItsEvents(config, fetcher).then((payload) => {
      cached = { payload, expiresAt: now() + config.itsCacheTtlMs };
      return payload;
    });
    try {
      return await refresh;
    } finally {
      refresh = undefined;
    }
  };
}

async function fetchNationwideItsEvents(
  config: RelayConfig,
  fetcher: typeof fetch,
): Promise<unknown> {
  const upstreamUrl = new URL(ITS_EVENT_URL);
  upstreamUrl.searchParams.set('apiKey', config.itsApiKey);
  upstreamUrl.searchParams.set('type', 'all');
  upstreamUrl.searchParams.set('eventType', 'all');
  upstreamUrl.searchParams.set('minX', String(KOREA_BOUNDS.minLongitude));
  upstreamUrl.searchParams.set('maxX', String(KOREA_BOUNDS.maxLongitude));
  upstreamUrl.searchParams.set('minY', String(KOREA_BOUNDS.minLatitude));
  upstreamUrl.searchParams.set('maxY', String(KOREA_BOUNDS.maxLatitude));
  upstreamUrl.searchParams.set('getType', 'json');

  const upstream = await fetcher(upstreamUrl, {
    headers: { accept: 'application/json' },
    signal: AbortSignal.timeout(config.upstreamTimeoutMs),
  });
  if (!upstream.ok) {
    log('its_upstream_rejected', { status: upstream.status });
    throw new UpstreamResponseError('upstream request rejected');
  }
  const payload = await readJsonResponse(upstream);
  assertSuccessfulItsPayload(payload);
  return payload;
}

function filterItsPayload(
  payload: unknown,
  bounds: BoundingBoxRequest,
): unknown {
  const root = record(payload);
  const response = record(root.response ?? root);
  const body = record(response.body);
  const itemsContainer = record(body.items);
  const rawItems = itemsContainer.item ?? body.items ?? response.items;
  const items = Array.isArray(rawItems)
    ? rawItems
    : rawItems === undefined || rawItems === null
      ? []
      : [rawItems];
  const filtered = items.filter((value) => {
    const item = record(value);
    const longitude = numeric(item.coordX);
    const latitude = numeric(item.coordY);
    return (
      longitude !== undefined &&
      latitude !== undefined &&
      longitude >= bounds.minLongitude &&
      longitude <= bounds.maxLongitude &&
      latitude >= bounds.minLatitude &&
      latitude <= bounds.maxLatitude
    );
  });
  const filteredResponse = {
    ...response,
    body: {
      ...body,
      totalCount: filtered.length,
      items: { ...itemsContainer, item: filtered },
    },
  };
  return Object.hasOwn(root, 'response')
    ? { ...root, response: filteredResponse }
    : filteredResponse;
}

function assertSuccessfulItsPayload(payload: unknown): void {
  const root = record(payload);
  const response = record(root.response ?? root);
  const header = record(response.header);
  const resultCode = String(header.resultCode ?? response.resultCode ?? '');
  if (resultCode !== '0') {
    throw new UpstreamResponseError('upstream response contains an error');
  }
}

function authorized(header: string | undefined, expectedToken: string): boolean {
  if (!header?.startsWith('Bearer ')) return false;
  const supplied = header.slice('Bearer '.length);
  if (!supplied) return false;
  const suppliedDigest = createHash('sha256').update(supplied).digest();
  const expectedDigest = createHash('sha256').update(expectedToken).digest();
  return timingSafeEqual(suppliedDigest, expectedDigest);
}

async function readJsonBody(request: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const rawChunk of request) {
    const chunk = Buffer.isBuffer(rawChunk) ? rawChunk : Buffer.from(rawChunk);
    size += chunk.length;
    if (size > MAX_REQUEST_BYTES) throw new PayloadTooLargeError();
    chunks.push(chunk);
  }
  if (chunks.length === 0) throw new Error('empty request');
  return JSON.parse(Buffer.concat(chunks).toString('utf8')) as unknown;
}

function parseBounds(value: unknown): BoundingBoxRequest {
  if (!isRecord(value)) throw new Error('invalid body');
  const expectedKeys = [
    'minLongitude',
    'maxLongitude',
    'minLatitude',
    'maxLatitude',
  ];
  if (
    Object.keys(value).length !== expectedKeys.length ||
    expectedKeys.some((key) => !Object.hasOwn(value, key))
  ) {
    throw new Error('invalid fields');
  }

  const result = {
    minLongitude: finiteNumber(value.minLongitude),
    maxLongitude: finiteNumber(value.maxLongitude),
    minLatitude: finiteNumber(value.minLatitude),
    maxLatitude: finiteNumber(value.maxLatitude),
  };
  if (
    result.minLongitude < 124 ||
    result.maxLongitude > 132 ||
    result.minLatitude < 32 ||
    result.maxLatitude > 39.5 ||
    result.minLongitude >= result.maxLongitude ||
    result.minLatitude >= result.maxLatitude ||
    result.maxLongitude - result.minLongitude > MAX_BOUNDING_BOX_SPAN_DEGREES ||
    result.maxLatitude - result.minLatitude > MAX_BOUNDING_BOX_SPAN_DEGREES
  ) {
    throw new Error('bounds outside supported area');
  }
  return result;
}

function finiteNumber(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new Error('coordinate must be finite');
  }
  return value;
}

async function readJsonResponse(response: Response): Promise<unknown> {
  const declaredLength = Number(response.headers.get('content-length'));
  if (Number.isFinite(declaredLength) && declaredLength > MAX_UPSTREAM_BYTES) {
    throw new UpstreamResponseError('upstream response too large');
  }
  if (!response.body) throw new UpstreamResponseError('empty upstream response');

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const result = await reader.read();
    if (result.done) break;
    size += result.value.byteLength;
    if (size > MAX_UPSTREAM_BYTES) {
      await reader.cancel();
      throw new UpstreamResponseError('upstream response too large');
    }
    chunks.push(result.value);
  }

  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder().decode(bytes)) as unknown;
  } catch {
    throw new UpstreamResponseError('upstream response is not JSON');
  }
}

function sendJson(response: ServerResponse, status: number, value: unknown): void {
  if (response.headersSent) return;
  const body = JSON.stringify(value);
  response.writeHead(status, {
    'cache-control': 'no-store',
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(body),
    'x-content-type-options': 'nosniff',
  });
  response.end(body);
}

function log(event: string, fields: Record<string, string | number>): void {
  console.error(JSON.stringify({ event, ...fields }));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function record(value: unknown): Record<string, unknown> {
  return isRecord(value) ? value : {};
}

function numeric(value: unknown): number | undefined {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

class PayloadTooLargeError extends Error {
  constructor() {
    super('request body too large');
    this.name = 'PayloadTooLargeError';
  }
}

class UpstreamResponseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'UpstreamResponseError';
  }
}
