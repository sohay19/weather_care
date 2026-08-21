import { describe, expect, it, vi } from 'vitest';
import {
  KmaUvProvider,
  latestUvPublicationTimes,
} from '../src/providers/uv/kmaUvProvider';

describe('KmaUvProvider', () => {
  it('selects delayed three-hour publication candidates in Korea', () => {
    expect(
      latestUvPublicationTimes(new Date('2026-08-21T02:10:00Z'), 4),
    ).toEqual(['2026082109', '2026082106', '2026082103', '2026082100']);
  });

  it('parses V5 UV values into three-hour forecast points', async () => {
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(
      uvResponse({
        areaNo: '4111000000',
        date: '2026082109',
        h0: '3',
        h3: '6',
        h6: '8',
        h9: '-',
      }),
    );
    const provider = new KmaUvProvider({
      serviceKey: 'abc%2B123',
      fetcher,
      now: () => new Date('2026-08-21T02:10:00Z'),
    });

    const forecast = await provider.getForecast('4111000000');

    expect(forecast.provider).toBe('KMA_LIVING_INDEX_V5');
    expect(forecast.issuedAt).toBe('2026-08-21T09:00:00+09:00');
    expect(forecast.points).toEqual([
      { forecastAt: '2026-08-21T09:00:00+09:00', uvIndex: 3 },
      { forecastAt: '2026-08-21T12:00:00+09:00', uvIndex: 6 },
      { forecastAt: '2026-08-21T15:00:00+09:00', uvIndex: 8 },
    ]);
    const url = new URL(String(fetcher.mock.calls[0][0]));
    expect(url.pathname).toContain('/LivingWthrIdxServiceV5/getUVIdxV5');
    expect(url.searchParams.get('ServiceKey')).toBe('abc+123');
    expect(url.searchParams.get('time')).toBe('2026082109');
  });

  it('retries the previous publication when V5 reports no data', async () => {
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        Response.json({
          response: {
            header: { resultCode: '03', resultMsg: 'NO_DATA' },
          },
        }),
      )
      .mockResolvedValueOnce(
        uvResponse({
          areaNo: '4111000000',
          date: '2026082106',
          h0: '2',
        }),
      );
    const provider = new KmaUvProvider({
      serviceKey: 'key',
      fetcher,
      now: () => new Date('2026-08-21T02:10:00Z'),
    });

    const forecast = await provider.getForecast('4111000000');

    expect(fetcher).toHaveBeenCalledTimes(2);
    const secondUrl = new URL(String(fetcher.mock.calls[1][0]));
    expect(secondUrl.searchParams.get('time')).toBe('2026082106');
    expect(forecast.points[0].uvIndex).toBe(2);
  });
});

function uvResponse(item: Record<string, string>): Response {
  return Response.json({
    response: {
      header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' },
      body: { items: { item } },
    },
  });
}
