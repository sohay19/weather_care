import { describe, expect, it, vi } from 'vitest';
import {
  KmaGridObservationProvider,
  latestGridObservationTime,
  parseKmaGridObservation,
  parseKmaGridObservationPayload,
} from '../src/providers/weather/kmaGridObservationProvider';
import {
  KmaAwsMinuteObservationProvider,
  parseKmaAwsMinuteRows,
} from '../src/providers/weather/kmaAwsMinuteObservationProvider';

const width = 149;
const height = 253;
const target = { nx: 57, ny: 125 };

describe('KMA APIHub 10분 격자 실황', () => {
  it('전국 격자 배열에서 정확한 nx/ny의 값을 읽는다', () => {
    const parsed = parseKmaGridObservation(gridPayload(target, 23.4));

    expect(parsed.width).toBe(width);
    expect(parsed.height).toBe(height);
    expect(parsed.values[(target.ny - 1) * width + target.nx - 1]).toBe(23.4);
  });

  it('차원 헤더 없이 줄바꿈된 운영 격자 원본도 읽는다', () => {
    const values = Array<number>(width * height).fill(-99);
    values[(target.ny - 1) * width + target.nx - 1] = 24.6;
    const payload = Array.from(
      { length: Math.ceil(values.length / 20) },
      (_, index) => values.slice(index * 20, (index + 1) * 20).join(', '),
    ).join('\n');

    const parsed = parseKmaGridObservation(payload);

    expect(parsed).toMatchObject({ width, height });
    expect(parsed.values).toHaveLength(width * height);
    expect(parsed.values[(target.ny - 1) * width + target.nx - 1]).toBe(24.6);
  });

  it('격자 API의 little-endian float 바이너리도 읽는다', () => {
    const buffer = new ArrayBuffer(4 + width * height * 4);
    const view = new DataView(buffer);
    view.setUint16(0, width, true);
    view.setUint16(2, height, true);
    view.setFloat32(
      4 + ((target.ny - 1) * width + target.nx - 1) * 4,
      19.75,
      true,
    );

    const parsed = parseKmaGridObservationPayload(buffer);

    expect(parsed.values[(target.ny - 1) * width + target.nx - 1])
      .toBeCloseTo(19.75);
  });

  it('동일 발표시각의 T1H/REH/WSD가 모두 있을 때만 exact-grid 세트를 만든다', async () => {
    const values = new Map([
      ['T1H', 23.4], ['REH', 61], ['WSD', 2.6],
      ['VEC', 225], ['PTY', 0], ['RN1', 0],
    ]);
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const variable = new URL(String(input)).searchParams.get('vars')!;
      return new Response(gridPayload(target, values.get(variable) ?? -999));
    });
    const provider = new KmaGridObservationProvider({
      serviceKey: 'test-key',
      fetcher,
    });

    const observations = await provider.getAt(
      [target],
      new Date('2026-09-22T11:20:00Z'),
    );

    expect(fetcher).toHaveBeenCalledTimes(6);
    expect(observations.get('57:125')).toMatchObject({
      observedAt: '2026-09-22T11:20:00+09:00',
      temperature: 23.4,
      humidity: 61,
      windSpeed: 2.6,
      windDirection: 225,
      provider: 'KMA_APIHUB_GRID_OBSERVATION',
      sourceLocation: {
        type: 'GRID', nx: 57, ny: 125, locationMatch: 'EXACT_GRID',
      },
    });
  });

  it('핵심 필드 하나가 결측이면 다른 source 값과 섞지 않는다', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const variable = new URL(String(input)).searchParams.get('vars')!;
      const value = variable === 'REH' ? -999 : 1;
      return new Response(gridPayload(target, value));
    });
    const provider = new KmaGridObservationProvider({
      serviceKey: 'test-key',
      fetcher,
    });

    const observations = await provider.getAt(
      [target],
      new Date('2026-09-22T11:20:00Z'),
    );

    expect(observations.has('57:125')).toBe(false);
  });

  it('10분 발표 지연을 고려해 직전 10분 시각을 선택한다', () => {
    expect(latestGridObservationTime(
      new Date('2026-09-22T02:37:40Z'),
    ).toISOString()).toBe('2026-09-22T11:20:00.000Z');
  });
});

describe('KMA AWS 매분 fallback', () => {
  it('한 행에서 기온·습도·바람을 함께 읽고 최근접 관측소를 고른다', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = new URL(String(input));
      if (url.pathname.includes('nph-aws2_min')) {
        return new Response([
          '# TM,STN,WD1,WS1,TA,RE,RN-60m,HM',
          '202609221115,400,180,2.4,22.8,0,0,58',
          '202609221116,401,90,1.2,24.1,1,0.4,66',
        ].join('\n'));
      }
      return Response.json({
        response: {
          header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' },
          body: {
            items: {
              item: [
                { stn_id: '400', stn_ko: '먼관측소', lat: 35, lon: 128 },
                { stn_id: '401', stn_ko: '항동인근', lat: 37.48, lon: 126.82 },
              ],
            },
          },
        },
      });
    });
    const provider = new KmaAwsMinuteObservationProvider({
      serviceKey: 'test-key',
      fetcher,
      now: () => new Date('2026-09-22T11:18:00+09:00'),
    });

    const [observation] = await provider.getCurrentByLocations([
      { latitude: 37.48, longitude: 126.82 },
    ]);

    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(observation).toMatchObject({
      observedAt: '2026-09-22T11:16:00+09:00',
      temperature: 24.1,
      humidity: 66,
      windSpeed: 1.2,
      windDirection: 90,
      rainDetected: true,
      precipitationAmount: 0.4,
      provider: 'KMA_AWS_OBSERVATION',
      sourceLocation: {
        type: 'STATION',
        stationId: '401',
        stationName: '항동인근',
        distanceKm: 0,
        locationMatch: 'NEAREST_STATION',
      },
      qualityFlags: ['LOCATION_FALLBACK'],
    });
  });

  it('같은 AWS 행에 핵심 필드가 모두 없으면 계산 입력으로 쓰지 않는다', () => {
    expect(parseKmaAwsMinuteRows([
      '# TM,STN,WD1,WS1,TA,RE,RN-60m,HM',
      '202609221115,400,180,2.4,22.8,0,0,-999',
    ].join('\n'))).toEqual([]);
  });

  it('미발간 월을 건너뛰고 중첩된 최신 지점목록을 읽는다', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = new URL(String(input));
      if (url.pathname.includes('nph-aws2_min')) {
        return new Response([
          '# TM,STN,WD1,WS1,TA,RE,RN-60m,HM',
          '202609221115,401,90,1.2,24.1,0,0,66',
        ].join('\n'));
      }
      if (url.searchParams.get('month') === '09') {
        return Response.json({
          response: {
            header: { resultCode: '99', resultMsg: '발간되지 않은 기간입니다.' },
          },
        });
      }
      return Response.json({
        response: {
          header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' },
          body: {
            items: {
              item: [{
                stn_aws: {
                  info: [{
                    stn_id: 401,
                    stn_ko: '항동인근',
                    lat: '37.48',
                    lon: '126.82',
                  }],
                },
              }],
            },
          },
        },
      });
    });
    const provider = new KmaAwsMinuteObservationProvider({
      serviceKey: 'test-key',
      fetcher,
      now: () => new Date('2026-09-22T11:18:00+09:00'),
    });

    const [observation] = await provider.getCurrentByLocations([
      { latitude: 37.48, longitude: 126.82 },
    ]);

    expect(fetcher).toHaveBeenCalledTimes(3);
    expect(observation?.sourceLocation).toMatchObject({
      stationId: '401',
      stationName: '항동인근',
      locationMatch: 'NEAREST_STATION',
    });
  });
});

function gridPayload(point: { nx: number; ny: number }, value: number): string {
  const values = Array<number>(width * height).fill(-999);
  values[(point.ny - 1) * width + point.nx - 1] = value;
  const rows = Array.from({ length: height }, (_, row) =>
    values.slice(row * width, (row + 1) * width).join(','));
  return [`${width},${height}`, ...rows].join('\n');
}
