import { describe, expect, it, vi } from 'vitest';
import {
  KmaGridObservationProvider,
  latestGridObservationTime,
  parseKmaGridObservation,
  parseKmaGridObservationPayload,
} from '../src/providers/weather/kmaGridObservationProvider';

const width = 149;
const height = 253;
const target = { nx: 57, ny: 125 };

describe('KMA APIHub 10분 격자 실황', () => {
  it('미제공 기온 파일은 나머지 변수 요청을 막는다', async () => {
    const fetcher = vi.fn<typeof fetch>(async () =>
      new Response('# dfs_file_read error (-1)\n'));
    const log = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await expect(new KmaGridObservationProvider({
        serviceKey: 'test-key', fetcher,
      }).getAt([target], new Date('2026-09-22T11:20:00Z')))
        .rejects.toThrow('file is not available');
      expect(fetcher).toHaveBeenCalledTimes(1);
      expect(new URL(String(fetcher.mock.calls[0][0])).searchParams.get('vars'))
        .toBe('T1H');
      expect(log.mock.calls.join('')).toContain('NO_USABLE_DATA');
    } finally {
      log.mockRestore();
    }
  });

  it('모든 격자가 결측인 기온 파일도 나머지 요청을 막는다', async () => {
    const fetcher = vi.fn<typeof fetch>(async () =>
      new Response(gridPayload(target, -99)));
    const log = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await expect(new KmaGridObservationProvider({
        serviceKey: 'test-key', fetcher,
      }).getAt([target], new Date('2026-09-22T11:20:00Z')))
        .rejects.toThrow('no usable temperature');
      expect(fetcher).toHaveBeenCalledTimes(1);
    } finally {
      log.mockRestore();
    }
  });

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

  it('빠른 재시도에서는 기온·습도·풍속만 조회한다', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const variable = new URL(String(input)).searchParams.get('vars')!;
      const values: Record<string, number> = { T1H: 23.4, REH: 61, WSD: 2.6 };
      return new Response(gridPayload(target, values[variable]));
    });
    const provider = new KmaGridObservationProvider({
      serviceKey: 'test-key', fetcher,
    });

    const observations = await provider.getAt(
      [target], new Date('2026-09-22T11:20:00Z'), { requiredOnly: true },
    );

    expect(fetcher).toHaveBeenCalledTimes(3);
    expect(fetcher.mock.calls.map(([input]) =>
      new URL(String(input)).searchParams.get('vars')))
      .toEqual(['T1H', 'REH', 'WSD']);
    expect(observations.get('57:125')).toMatchObject({
      temperature: 23.4,
      humidity: 61,
      windSpeed: 2.6,
      qualityFlags: ['PRECIPITATION_TYPE_UNAVAILABLE'],
    });
  });

  it('선택 요소 조회가 실패해도 기온·습도·풍속 관측을 유지한다', async () => {
    const values = new Map([
      ['T1H', 23.4], ['REH', 61], ['WSD', 2.6],
      ['PTY', 0], ['RN1', 0],
    ]);
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const variable = new URL(String(input)).searchParams.get('vars')!;
      if (variable === 'VEC') throw new TypeError('network unavailable');
      return new Response(gridPayload(target, values.get(variable) ?? -999));
    });
    const warning = vi.spyOn(console, 'warn').mockImplementation(() => {});

    const observations = await new KmaGridObservationProvider({
      serviceKey: 'test-key', fetcher,
    }).getAt([target], new Date('2026-09-22T11:20:00Z'));

    expect(observations.get('57:125')).toMatchObject({
      temperature: 23.4,
      humidity: 61,
      windSpeed: 2.6,
      windDirection: undefined,
    });
    expect(warning).toHaveBeenCalledWith(expect.stringContaining(
      'grid_observation_optional_variable_failed',
    ));
    warning.mockRestore();
  });

  it('필수 변수의 헤더 대기 시간 초과 위치와 발표시각을 남긴다', async () => {
    const error = Object.assign(new Error('request timed out'), { name: 'TimeoutError' });
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const variable = new URL(String(input)).searchParams.get('vars');
      if (variable === 'T1H') throw error;
      return new Response(gridPayload(target, 1));
    });
    const log = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await expect(new KmaGridObservationProvider({
        serviceKey: 'test-key', fetcher,
      }).getAt([target], new Date('2026-09-22T11:20:00Z'), {
        requiredOnly: true,
      })).rejects.toThrow('request timed out');

      const events = log.mock.calls.map(([line]) => JSON.parse(String(line)));
      expect(events).toContainEqual(expect.objectContaining({
        event: 'weather_provider_request_failed',
        endpoint: 'GRID_OBSERVATION',
        phase: 'WAIT_HEADERS',
        variable: 'T1H',
        targetTime: '202609221120',
        failureReason: 'TIMEOUT',
      }));
      expect(log.mock.calls.join('')).not.toContain('test-key');
    } finally {
      log.mockRestore();
    }
  });

  it('격자 응답 본문을 읽다 시간 초과되면 단계를 구분한다', async () => {
    const error = Object.assign(new Error('body timed out'), { name: 'TimeoutError' });
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const variable = new URL(String(input)).searchParams.get('vars');
      const response = new Response(gridPayload(target, 1));
      if (variable === 'REH') vi.spyOn(response, 'arrayBuffer').mockRejectedValue(error);
      return response;
    });
    const log = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await expect(new KmaGridObservationProvider({
        serviceKey: 'test-key', fetcher,
      }).getAt([target], new Date('2026-09-22T11:20:00Z'), {
        requiredOnly: true,
      })).rejects.toThrow('body timed out');

      const events = log.mock.calls.map(([line]) => JSON.parse(String(line)));
      expect(events).toContainEqual(expect.objectContaining({
        event: 'weather_provider_request_failed',
        endpoint: 'GRID_OBSERVATION',
        phase: 'READ_BODY',
        variable: 'REH',
        httpStatus: 200,
        failureReason: 'TIMEOUT',
      }));
    } finally {
      log.mockRestore();
    }
  });

  it('같은 시각의 핵심 캐시를 재사용하고 빠진 선택3변수만 받는다', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const variable = new URL(String(input)).searchParams.get('vars');
      return new Response(gridPayload(target, variable === 'VEC' ? 180 : 0));
    });
    const fields = Object.fromEntries(Object.entries({ T1H: 23.4, REH: 61, WSD: 2.6 })
      .map(([key, value]) => [key, parseKmaGridObservation(gridPayload(target, value))]));
    const snapshot = await new KmaGridObservationProvider({ serviceKey: 'test', fetcher }).getSnapshot(
      new Date('2026-09-22T11:20:00Z'), { seed: { observedAt: '2026-09-22T02:20:00Z', fields } },
    );
    expect(fetcher).toHaveBeenCalledTimes(3);
    expect(fetcher.mock.calls.map(([input]) => new URL(String(input)).searchParams.get('vars')).sort())
      .toEqual(['PTY', 'RN1', 'VEC']);
    expect(snapshot.fields.T1H).toEqual(fields.T1H);
  });

  it('10분 발표 지연을 고려해 직전 10분 시각을 선택한다', () => {
    expect(latestGridObservationTime(
      new Date('2026-09-22T02:37:40Z'),
    ).toISOString()).toBe('2026-09-22T11:20:00.000Z');
  });
});


function gridPayload(point: { nx: number; ny: number }, value: number): string {
  const values = Array<number>(width * height).fill(-99);
  values[(point.ny - 1) * width + point.nx - 1] = value;
  return [`${width},${height}`, ...Array.from({ length: height }, (_, row) =>
    values.slice(row * width, (row + 1) * width).join(','))].join('\n');
}
