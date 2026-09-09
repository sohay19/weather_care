import { describe, expect, it, vi } from 'vitest';
import {
  ItsRoadControlProvider,
  itsRoadControlProviderFromEnvironment,
  parseItsRoadControls,
} from '../src/providers/traffic/itsRoadControlProvider';
import { providerErrorDiagnostic } from '../src/observability/providerErrorDiagnostics';

describe('ITS road control provider', () => {
  it('requests the official event endpoint around the current GPS location', async () => {
    const fetcher = vi.fn(async () => Response.json(successPayload([])));
    const provider = new ItsRoadControlProvider({
      apiKey: 'its-key',
      fetcher,
      now: () => new Date('2026-09-01T05:00:00Z'),
    });

    expect(
      await provider.getNearestActiveControl(37.2636, 127.0286),
    ).toBeUndefined();
    const url = new URL(fetcher.mock.calls[0][0].toString());
    expect(`${url.origin}${url.pathname}`).toBe(
      'https://openapi.its.go.kr:9443/eventInfo',
    );
    expect(url.searchParams.get('type')).toBe('all');
    expect(url.searchParams.get('eventType')).toBe('all');
    expect(url.searchParams.get('getType')).toBe('json');
    expect(url.searchParams.get('apiKey')).toBe('its-key');
  });

  it('uses only active events with explicit control evidence and prioritizes a full closure', () => {
    const controls = parseItsRoadControls(
      successPayload([
        event({
          linkId: 'partial-near',
          coordX: '127.0288',
          coordY: '37.2638',
          lanesBlocked: '2차로 차단',
        }),
        event({
          linkId: 'full-farther',
          coordX: '127.0350',
          coordY: '37.2660',
          roadName: '수원지하차도',
          roadDrcType: '서울방향',
          lanesBlockType: '전면 통제',
          lanesBlocked: '',
        }),
        event({
          linkId: 'future',
          startDate: '20260901150000',
          lanesBlocked: '1차로 차단',
        }),
        event({
          linkId: 'ended',
          endDate: '20260901130000',
          lanesBlocked: '1차로 차단',
        }),
        event({
          linkId: 'accident-without-control',
          lanesBlockType: '',
          lanesBlocked: '',
          message: '추돌사고가 발생해 주의운전 바랍니다',
        }),
      ]),
      {
        latitude: 37.2636,
        longitude: 127.0286,
        now: new Date('2026-09-01T05:00:00Z'),
      },
    );

    expect(controls.map((item) => item.linkId)).toEqual([
      'full-farther',
      'partial-near',
    ]);
    expect(controls[0]).toMatchObject({
      controlKind: 'FULL',
      roadName: '수원지하차도',
      direction: '서울방향',
      provider: '국가교통정보센터 돌발상황정보',
    });
  });

  it('uses the authenticated home relay without exposing the ITS key', async () => {
    const fetcher = vi.fn(async () => Response.json(successPayload([])));
    const provider = new ItsRoadControlProvider({
      apiKey: 'its-key',
      relayUrl: 'https://relay.example.ts.net',
      relayToken: 'relay-secret',
      fetcher,
    });

    await provider.getNearestActiveControl(37.2636, 127.0286);

    const [rawUrl, init] = fetcher.mock.calls[0];
    const url = new URL(rawUrl.toString());
    expect(url.toString()).toBe(
      'https://relay.example.ts.net/v1/its/event-info',
    );
    expect(init?.method).toBe('POST');
    expect(init?.headers).toEqual({
      authorization: 'Bearer relay-secret',
      'content-type': 'application/json',
    });
    expect(JSON.parse(String(init?.body))).toMatchObject({
      minLongitude: expect.any(Number),
      maxLongitude: expect.any(Number),
      minLatitude: expect.any(Number),
      maxLatitude: expect.any(Number),
    });
    expect(`${url}${String(init?.body)}`).not.toContain('its-key');
  });

  it('calls the runtime fetch with the global receiver', async () => {
    const originalFetch = globalThis.fetch;
    let receiver: unknown;
    globalThis.fetch = vi.fn(function (this: unknown) {
      receiver = this;
      return Promise.resolve(Response.json(successPayload([])));
    }) as typeof fetch;

    try {
      const provider = new ItsRoadControlProvider({ apiKey: 'its-key' });
      await provider.getNearestActiveControl(37.2636, 127.0286);
      expect(receiver).toBe(globalThis);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it('prefers a complete relay configuration and keeps direct mode as fallback', () => {
    expect(
      itsRoadControlProviderFromEnvironment({
        ITS_API_KEY: 'direct-key',
        ITS_RELAY_URL: 'https://relay.example.ts.net',
        ITS_RELAY_TOKEN: 'relay-token',
      }),
    ).toBeInstanceOf(ItsRoadControlProvider);
    expect(
      itsRoadControlProviderFromEnvironment({ ITS_API_KEY: 'direct-key' }),
    ).toBeInstanceOf(ItsRoadControlProvider);
    expect(itsRoadControlProviderFromEnvironment({})).toBeUndefined();
  });

  it('rejects an insecure or incomplete relay configuration', () => {
    expect(
      () =>
        new ItsRoadControlProvider({
          relayUrl: 'http://relay.example.ts.net',
          relayToken: 'relay-token',
        }),
    ).toThrow('HTTPS');
    expect(
      () =>
        new ItsRoadControlProvider({
          relayUrl: 'https://relay.example.ts.net',
        }),
    ).toThrow('completely');
  });

  it('rejects a malformed or failed response instead of treating it as no control', async () => {
    const provider = new ItsRoadControlProvider({
      apiKey: 'its-key',
      fetcher: async () => new Response('<response>sample</response>'),
    });

    await expect(
      provider.getNearestActiveControl(37.2636, 127.0286),
    ).rejects.toThrow('not JSON');
    expect(() =>
      parseItsRoadControls(
        { response: { header: { resultCode: '1', resultMsg: 'FAIL' } } },
        {
          latitude: 37.2636,
          longitude: 127.0286,
          now: new Date('2026-09-01T05:00:00Z'),
        },
      ),
    ).toThrow('FAIL');
  });

  it('replaces a fetch failure with a fixed secret-safe diagnostic', async () => {
    const provider = new ItsRoadControlProvider({
      apiKey: 'its-key',
      fetcher: async () => {
        throw new TypeError('network failed with secret-value');
      },
    });

    const error = await provider
      .getNearestActiveControl(37.2636, 127.0286)
      .catch((caught: unknown) => caught);
    const diagnostic = providerErrorDiagnostic(error);

    expect(diagnostic).toEqual({
      error: 'ItsRoadControlProviderError',
      failureReason: 'NETWORK_ERROR',
      operation: 'ROAD_CONTROL',
      detail: 'ROAD_CONTROL_FETCH_FAILED',
    });
    expect(JSON.stringify(diagnostic)).not.toContain('secret-value');
  });
});

function successPayload(items: Record<string, string>[]) {
  return {
    response: {
      header: { resultCode: '0', resultMsg: 'SUCCESS' },
      body: { totalCount: String(items.length), items: { item: items } },
    },
  };
}

function event(overrides: Partial<Record<string, string>> = {}) {
  return {
    type: '시군도',
    eventType: '재난',
    eventDetailType: '침수',
    startDate: '20260901130000',
    coordX: '127.0290',
    coordY: '37.2640',
    linkId: 'control-link',
    roadName: '수원지하차도',
    roadNo: '',
    roadDrcType: '',
    lanesBlockType: '',
    lanesBlocked: '1차로 차단',
    message: '침수로 차로를 통제합니다',
    endDate: '',
    ...overrides,
  };
}
