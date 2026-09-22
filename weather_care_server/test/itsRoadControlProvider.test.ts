import { describe, expect, it, vi } from 'vitest';
import {
  ItsRoadControlProvider,
  itsRoadControlProviderFromEnvironment,
  nearestRoadControl,
  parseItsRoadControls,
} from '../src/providers/traffic/itsRoadControlProvider';
import { providerErrorDiagnostic } from '../src/observability/providerErrorDiagnostics';

describe('ITS road control provider', () => {
  it('requests one nationwide snapshot and filters every location locally', async () => {
    const fetcher = vi.fn(async () => Response.json(successPayload([
      event({ linkId: 'seoul', coordX: '126.8890', coordY: '37.4900' }),
      event({ linkId: 'suwon', coordX: '127.0290', coordY: '37.2640' }),
    ])));
    const provider = new ItsRoadControlProvider({
      apiKey: 'its-key',
      fetcher,
      now: () => new Date('2026-09-01T05:00:00Z'),
    });

    const snapshot = await provider.getActiveControlSnapshot();
    expect(nearestRoadControl(snapshot, {
      latitude: 37.4898,
      longitude: 126.8889,
    })?.linkId).toBe('seoul');
    expect(nearestRoadControl(snapshot, {
      latitude: 37.2636,
      longitude: 127.0286,
    })?.linkId).toBe('suwon');
    expect(fetcher).toHaveBeenCalledTimes(1);
    const url = new URL(fetcher.mock.calls[0][0].toString());
    expect(`${url.origin}${url.pathname}`).toBe(
      'https://openapi.its.go.kr:9443/eventInfo',
    );
    expect(url.searchParams.get('type')).toBe('all');
    expect(url.searchParams.get('eventType')).toBe('all');
    expect(url.searchParams.get('getType')).toBe('json');
    expect(url.searchParams.get('apiKey')).toBe('its-key');
    expect(url.searchParams.get('minX')).toBe('124.000000');
    expect(url.searchParams.get('maxX')).toBe('132.000000');
    expect(url.searchParams.get('minY')).toBe('32.000000');
    expect(url.searchParams.get('maxY')).toBe('39.500000');
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

  it('uses only the direct ITS key from the runtime environment', () => {
    expect(
      itsRoadControlProviderFromEnvironment({ ITS_API_KEY: 'direct-key' }),
    ).toBeInstanceOf(ItsRoadControlProvider);
    expect(itsRoadControlProviderFromEnvironment({})).toBeUndefined();
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
