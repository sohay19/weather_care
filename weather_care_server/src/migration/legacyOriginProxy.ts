import type { ServerEnv } from '../types';

export function legacyOriginEnabled(env: Pick<ServerEnv, 'LEGACY_ORIGIN_URL'>): boolean {
  return Boolean(env.LEGACY_ORIGIN_URL?.trim());
}

export function legacyOriginRequest(request: Request, configuredOrigin: string): Request {
  const origin = new URL(configuredOrigin);
  if (origin.protocol !== 'https:') throw new Error('LEGACY_ORIGIN_HTTPS_REQUIRED');

  const incoming = new URL(request.url);
  if (origin.origin === incoming.origin) throw new Error('LEGACY_ORIGIN_LOOP');
  const target = new URL(origin);
  target.pathname = `${origin.pathname.replace(/\/$/, '')}${incoming.pathname}`;
  target.search = incoming.search;
  target.hash = '';

  return new Request(target, request);
}

export async function proxyToLegacyOrigin(
  request: Request,
  configuredOrigin: string,
  fetcher: typeof fetch = fetch,
): Promise<Response> {
  return fetcher(legacyOriginRequest(request, configuredOrigin));
}
