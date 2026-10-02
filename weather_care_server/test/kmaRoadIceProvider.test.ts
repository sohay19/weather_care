import { strToU8, zipSync } from 'fflate';
import { describe, expect, it, vi } from 'vitest';
import {
  KmaRoadIceProvider,
  ROAD_ICE_ROAD_NUMBERS,
  parseRoadIceArchive,
  nearestRoadIceRisk,
} from '../src/providers/road/kmaRoadIceProvider';

describe('KMA road ice provider', () => {
  it('treats level 0 as no information and selects an official nearby risk', async () => {
    const archive = roadIceArchive();
    const fetcher = vi.fn(async () =>
      new Response(archive, {
        headers: { 'Content-Type': 'application/zip' },
      }),
    );
    const provider = new KmaRoadIceProvider({
      serviceKey: 'test-key',
      fetcher,
      now: () => new Date('2026-01-15T01:00:00Z'),
    });

    const risk = await provider.getNearestRiskByLocation(
      37.2636,
      127.0286,
      ['050'],
    );

    expect(risk).toMatchObject({
      producedAt: '2026-01-15T01:00:00Z',
      roadNumber: '050',
      roadName: '영동선',
      linkId: 'risk-link',
      level: 2,
      levelLabel: '주의',
      sourceType: 'OBSERVATION',
    });
    const requestUrl = new URL(fetcher.mock.calls[0][0].toString());
    expect(requestUrl.searchParams.get('roadNum')).toBe('050');
    expect(requestUrl.searchParams.has('tm')).toBe(false);
  });

  it('does not request the seasonal road-ice product outside Nov 15 to Mar 15', async () => {
    const fetcher = vi.fn();
    const provider = new KmaRoadIceProvider({
      serviceKey: 'test-key',
      fetcher,
      now: () => new Date('2026-09-01T00:00:00Z'),
    });

    expect(
      await provider.getNearestRiskByLocation(37.2636, 127.0286, ['050']),
    ).toBeUndefined();
    expect(fetcher).not.toHaveBeenCalled();
  });

  it('checks every officially supported road when no regional list is supplied', async () => {
    const fetcher = vi.fn(async (input: RequestInfo | URL) => {
      const roadNumber = new URL(input.toString()).searchParams.get('roadNum');
      return new Response(
        roadIceArchive(roadNumber === '050' ? 2 : 0, roadNumber ?? '000'),
        { headers: { 'Content-Type': 'application/zip' } },
      );
    });
    const provider = new KmaRoadIceProvider({
      serviceKey: 'test-key',
      fetcher,
      now: () => new Date('2026-01-15T01:00:00Z'),
    });

    const risk = await provider.getNearestRiskByLocation(37.2636, 127.0286);

    expect(fetcher).toHaveBeenCalledTimes(ROAD_ICE_ROAD_NUMBERS.length);
    expect(risk).toMatchObject({ roadNumber: '050', level: 2 });
  });

  it('rejects non-ZIP responses instead of treating them as no risk', () => {
    const bytes = new TextEncoder().encode('temporary provider response');
    expect(() =>
      parseRoadIceArchive(toArrayBuffer(bytes), '050'),
    ).toThrow('not a ZIP archive');
  });

  it('도로 파일을 한 번만 받아 여러 좌표를 함께 판정한다', async () => {
    const fetcher = vi.fn(async () => new Response(roadIceArchive(), {
      headers: { 'Content-Type': 'application/zip' },
    }));
    const provider = new KmaRoadIceProvider({
      serviceKey: 'test-key',
      fetcher,
      now: () => new Date('2026-01-15T01:00:00Z'),
    });

    const risks = await provider.getNearestRisksByLocations([
      { latitude: 37.2636, longitude: 127.0286 },
      { latitude: 37.2640, longitude: 127.0290 },
    ], ['050']);

    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(risks).toHaveLength(2);
    expect(risks[0]).toMatchObject({ roadNumber: '050', level: 2 });
  });

  it('설치 등록과 관계없이 전국 위험 구간을 저장해 임의 좌표에서 판정한다', async () => {
    const fetcher = vi.fn(async () => new Response(roadIceArchive(), {
      headers: { 'Content-Type': 'application/zip' },
    }));
    const provider = new KmaRoadIceProvider({
      serviceKey: 'test-key', fetcher,
      now: () => new Date('2026-01-15T01:00:00Z'),
    });

    const segments = await provider.getRiskSegments(['050']);

    expect(segments).toHaveLength(2);
    expect(nearestRoadIceRisk(segments, 37.2636, 127.0286))
      .toMatchObject({ linkId: 'risk-link', level: 2 });
    expect(nearestRoadIceRisk(segments, 36, 126)).toBeUndefined();
    expect(fetcher).toHaveBeenCalledTimes(1);
  });
});

function roadIceArchive(level = 2, roadNumber = '050'): ArrayBuffer {
  const csv = [
    'LINK_ID,S_NUM,F_LON,F_LAT,T_LON,T_LAT,B_ICE,FLAG,X_GRID,Y_GRID',
    'no-info,1,127.0280,37.2630,127.0290,37.2640,0,0,1,1',
    `risk-link,1,127.0300,37.2630,127.0310,37.2640,${level},1,2,2`,
    'far-danger,1,127.1000,37.3000,127.1010,37.3010,3,0,3,3',
  ].join('\n');
  const zipped = zipSync({
    [`R${roadNumber}_1KM_FRG_202601150100.csv`]: strToU8(csv),
  });
  return toArrayBuffer(zipped);
}

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  ) as ArrayBuffer;
}
