import { describe, expect, it, vi } from 'vitest';
import {
  legacyOriginEnabled,
  legacyOriginRequest,
  proxyToLegacyOrigin,
} from '../src/migration/legacyOriginProxy';

describe('구버전 앱 미니 PC 전달', () => {
  it('설정된 경우에만 전달 모드를 켠다', () => {
    expect(legacyOriginEnabled({})).toBe(false);
    expect(legacyOriginEnabled({ LEGACY_ORIGIN_URL: '  ' })).toBe(false);
    expect(legacyOriginEnabled({ LEGACY_ORIGIN_URL: 'https://api.example.com' })).toBe(true);
  });

  it('경로·쿼리·메서드·본문을 HTTPS 원본으로 그대로 전달한다', async () => {
    const request = new Request('https://weather-care-server.example/api/v1/installations/id?x=1', {
      method: 'PUT',
      headers: { Authorization: 'Bearer token', 'Content-Type': 'application/json' },
      body: '{"ok":true}',
    });
    const proxied = legacyOriginRequest(request, 'https://api.example.com/origin/');

    expect(proxied.url).toBe('https://api.example.com/origin/api/v1/installations/id?x=1');
    expect(proxied.method).toBe('PUT');
    expect(proxied.headers.get('Authorization')).toBe('Bearer token');
    expect(await proxied.text()).toBe('{"ok":true}');
  });

  it('HTTP 원본을 거부하고 fetch 응답을 그대로 반환한다', async () => {
    expect(() => legacyOriginRequest(new Request('https://worker.example/health'), 'http://mini-pc:8787'))
      .toThrow('LEGACY_ORIGIN_HTTPS_REQUIRED');
    expect(() => legacyOriginRequest(
      new Request('https://worker.example/health'),
      'https://worker.example',
    )).toThrow('LEGACY_ORIGIN_LOOP');

    const fetcher = vi.fn(async () => new Response('ok', { status: 201 }));
    const response = await proxyToLegacyOrigin(
      new Request('https://worker.example/health'),
      'https://api.example.com',
      fetcher as typeof fetch,
    );
    expect(response.status).toBe(201);
    expect(fetcher).toHaveBeenCalledOnce();
  });
});
