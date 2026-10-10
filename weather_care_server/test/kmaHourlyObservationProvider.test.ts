import { describe, expect, it, vi } from 'vitest';
import {
  buildHourlyComparisons,
  KmaHourlyObservationProvider,
  latestCompletedKoreanHour,
  nearestVisibilityObservations,
  parseKmaHourlyObservationRows,
} from '../src/providers/weather/kmaHourlyObservationProvider';

describe('KMA hourly observation provider', () => {
  it('parses documented station rows and ignores help text', () => {
    expect(parseKmaHourlyObservationRows([
      '# TM STN LON LAT HT VAL',
      '202609161400,108,126.9658,37.5714,85.67,24.5',
      '202609161400,109,126.9000,37.5000,85.67,',
      'malformed row',
    ].join('\n'))).toEqual([{
      observedAt: '202609161400',
      stationId: '108',
      longitude: 126.9658,
      latitude: 37.5714,
      value: 24.5,
    }]);
  });

  it('selects one nearby station that has both same-hour observations', async () => {
    const values: Record<string, Record<string, [number, number]>> = {
      TA: { '108': [20, 24], '999': [18, 23] },
      HM: { '108': [60, 55], '999': [70, 50] },
      WS: { '108': [2, 3], '999': [1, 2] },
    };
    const provider = new KmaHourlyObservationProvider({
      serviceKey: 'test-key',
      now: () => new Date('2026-09-16T06:30:00Z'),
      fetcher: async (input) => {
        const metric = new URL(String(input)).searchParams.get('obs')!;
        const rows = [
          `202609151400,108,126.9658,37.5714,85.67,${values[metric]['108'][0]}`,
          `202609161400,108,126.9658,37.5714,85.67,${values[metric]['108'][1]}`,
          `202609151400,999,129.0000,35.0000,10.00,${values[metric]['999'][0]}`,
          `202609161400,999,129.0000,35.0000,10.00,${values[metric]['999'][1]}`,
        ];
        return new Response(rows.join('\n'));
      },
    });

    await expect(provider.getYesterdayComparison(37.56, 126.97)).resolves
      .toMatchObject({
        stationId: '108',
        currentObservedAt: '2026-09-16T14:00:00+09:00',
        comparisonObservedAt: '2026-09-15T14:00:00+09:00',
        current: { temperature: 24 },
        comparison: { temperature: 20 },
      });
  });

  it('waits for a safely completed Korean observation hour', () => {
    expect(latestCompletedKoreanHour(new Date('2026-09-16T06:30:00Z'))
      .toISOString()).toBe('2026-09-16T14:00:00.000Z');
  });

  it('전국 3요소를 한 번씩만 받아 여러 지역의 어제 비교를 생성한다', async () => {
    const fetcher = vi.fn(async (input: RequestInfo | URL) => {
      const metric = new URL(String(input)).searchParams.get('obs')!;
      const values = metric === 'TA' ? [20, 24, 18, 23]
        : metric === 'HM' ? [60, 55, 70, 50] : [2, 3, 1, 2];
      return new Response([
        `202609151400,108,126.9658,37.5714,85.67,${values[0]}`,
        `202609161400,108,126.9658,37.5714,85.67,${values[1]}`,
        `202609151400,999,129.0000,35.0000,10.00,${values[2]}`,
        `202609161400,999,129.0000,35.0000,10.00,${values[3]}`,
      ].join('\n'));
    });
    const provider = new KmaHourlyObservationProvider({
      serviceKey: 'test-key',
      fetcher,
      now: () => new Date('2026-09-16T06:30:00Z'),
    });

    const result = await provider.getYesterdayComparisons([
      { latitude: 37.56, longitude: 126.97 },
      { latitude: 35.1, longitude: 129.0 },
    ]);

    expect(fetcher).toHaveBeenCalledTimes(3);
    expect(result.map((item) => item?.stationId)).toEqual(['108', '999']);
  });

  it('한 시간 전국 관측을 저장 가능한 스냅샷으로 만든다', async () => {
    const timeout = vi.spyOn(AbortSignal, 'timeout');
    const fetcher = vi.fn(async (input: RequestInfo | URL) => {
      const url = new URL(String(input));
      const metric = url.searchParams.get('obs');
      const value = metric === 'TA' ? 24
        : metric === 'HM' ? 55
        : metric === 'VS' ? 2_000
        : 3;
      expect(url.searchParams.get('tm1')).toBe('202609161400');
      expect(url.searchParams.get('tm2')).toBe('202609161400');
      return new Response(`202609161400,108,126.9658,37.5714,85.67,${value}`);
    });
    const provider = new KmaHourlyObservationProvider({
      serviceKey: 'test-key',
      fetcher,
    });

    const current = await provider.getObservationsAt(
      new Date('2026-09-16T14:00:00.000Z'),
    );
    const comparison = {
      observedAt: '2026-09-15T14:00:00+09:00',
      stations: [{ ...current.stations[0], temperature: 20 }],
    };

    expect(fetcher).toHaveBeenCalledTimes(4);
    expect(timeout.mock.calls.map(([milliseconds]) => milliseconds))
      .toEqual([30_000, 7_500, 7_500, 7_500]);
    expect(current.stations[0]).toMatchObject({
      stationId: '108',
      temperature: 24,
      humidity: 55,
      windSpeed: 3,
      visibilityMeters: 20_000,
    });
    expect(nearestVisibilityObservations(current, [{
      latitude: 37.56,
      longitude: 126.97,
    }])[0]).toMatchObject({
      stationId: '108',
      visibilityMeters: 20_000,
      provider: 'KMA_ASOS',
    });
    expect(buildHourlyComparisons(current, comparison, [{
      latitude: 37.56,
      longitude: 126.97,
    }])[0]).toMatchObject({
      stationId: '108',
      current: { temperature: 24 },
      comparison: { temperature: 20 },
    });
    timeout.mockRestore();
  });
});


it('전국 시정 요청에서 VS가 실패하면 나머지 3지표를 선조회하지 않는다', async () => {
  const fetcher = vi.fn<typeof fetch>().mockResolvedValue(new Response('unavailable', { status: 504 }));
  const provider = new KmaHourlyObservationProvider({ serviceKey: 'synthetic', fetcher });
  await expect(provider.getObservationsAt(new Date('2026-10-04T08:00:00Z'), { includeVisibility: true })).rejects.toThrow();
  expect(fetcher).toHaveBeenCalledOnce();
  expect(new URL(String(fetcher.mock.calls[0][0])).searchParams.get('obs')).toBe('VS');
});

it('시정 전용 수집은 기온이 없는 가까운 관측소도 포함하고 추가 기상지표를 요청하지 않는다', async () => {
  const fetcher = vi.fn<typeof fetch>(async () => new Response([
    '202610040800,108,127.0000,37.2500,10,2000',
    '202610040800,109,128.0000,37.2500,10,1000',
    '202610040800,110,127.0010,37.2500,10,-99',
  ].join('\n')));
  const provider = new KmaHourlyObservationProvider({ serviceKey: 'synthetic', fetcher });
  const source = await provider.getObservationsAt(new Date('2026-10-04T08:00:00Z'), { includeVisibility: true });
  expect(fetcher).toHaveBeenCalledOnce();
  expect(source.stations.map(s => s.stationId)).toEqual(['108', '109']);
  expect(source.stations[0].temperature).toBeUndefined();
  expect(nearestVisibilityObservations(source, [{ latitude: 37.25, longitude: 127 }])[0])
    .toMatchObject({ stationId: '108', distanceKm: 0, visibilityMeters: 20000 });
});

it('기상청 504는 HTTP 단계·상태·회차를 남기며 응답 원문과 인증키는 기록하지 않는다', async () => {
  const log = vi.spyOn(console, 'error').mockImplementation(() => {});
  try {
    const provider = new KmaHourlyObservationProvider({ serviceKey: 'DO_NOT_LOG_KEY',
      fetcher: async () => new Response('DO_NOT_LOG_BODY', { status: 504 }) });
    await expect(provider.getObservationsAt(new Date('2026-10-04T08:00:00Z'), { includeVisibility: true })).rejects.toThrow('504');
    expect(JSON.parse(String(log.mock.calls[0][0]))).toMatchObject({ metric: 'VS', stage: 'HTTP_STATUS',
      target: '202610040800', httpStatus: 504, timeoutMs: 30000, failureReason: 'UPSTREAM_SERVER_ERROR' });
    expect(JSON.stringify(log.mock.calls)).not.toContain('DO_NOT_LOG');
  } finally { log.mockRestore(); }
});
