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


describe('전국 자외선 원본', () => {
  it('빈 areaNo로 전체 페이지를 수집하며 빈 수치를 0으로 만들지 않는다', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = new URL(String(input));
      expect(url.searchParams.has('areaNo')).toBe(true);
      expect(url.searchParams.get('areaNo')).toBe('');
      expect(url.searchParams.get('numOfRows')).toBe('1000');
      const page = Number(url.searchParams.get('pageNo'));
      const items = Array.from({ length: page === 1 ? 1000 : 1 }, (_, i) => ({
        areaNo: String(1100000000 + (page - 1) * 1000 + i), date: '2026082109', h0: '', h3: ' ', h6: '-', h9: '0',
      }));
      return Response.json({ response: { header: { resultCode: '00', resultMsg: 'OK' },
        body: { totalCount: 1001, items: { item: items } } } });
    });
    const source = await new KmaUvProvider({ serviceKey: 'synthetic', fetcher,
      now: () => new Date('2026-08-21T11:10:00+09:00') }).getNationwide();
    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(Object.keys(source)).toHaveLength(1001);
    expect(source['1100000000'].points).toEqual([{ forecastAt: '2026-08-21T18:00:00+09:00', uvIndex: 0 }]);
  });

  it.each(['duplicate', 'wrong-time', 'incomplete'])('잘못된 %s 원본을 게시하지 않는다', async (failure) => {
    const item = { areaNo: '1100000000', date: failure === 'wrong-time' ? '2026082106' : '2026082109', h0: '2' };
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(Response.json({ response: {
      header: { resultCode: '00', resultMsg: 'OK' }, body: { totalCount: 2,
        items: { item: failure === 'duplicate' ? [item, item] : [item] } },
    } }));
    await expect(new KmaUvProvider({ serviceKey: 'synthetic', fetcher,
      now: () => new Date('2026-08-21T11:10:00+09:00') }).getNationwide()).rejects.toThrow();
  });
});
