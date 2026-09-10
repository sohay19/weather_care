import { describe, expect, it, vi } from 'vitest';
import { AirKoreaAirQualityProvider } from '../src/providers/air/airKoreaAirQualityProvider';

describe('AirKoreaAirQualityProvider', () => {
  it('parses the latest usable PM and ozone observation', async () => {
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(
      Response.json({
        response: {
          header: { resultCode: '00', resultMsg: 'NORMAL_CODE' },
          body: {
            items: [
              {
                stationName: '인계동',
                dataTime: '2026-08-21 11:00',
                pm10Value: '42',
                pm25Value: '18',
                pm10Grade1h: '2',
                pm25Grade1h: '1',
                o3Value: '0.032',
                o3Grade: '1',
              },
            ],
          },
        },
      }),
    );
    const provider = new AirKoreaAirQualityProvider({
      serviceKey: 'abc%2B123',
      fetcher,
      now: () => new Date('2026-08-21T02:30:00Z'),
    });

    const result = await provider.getByRegion(60, 121, '인계동');

    expect(result).toEqual({
      observedAt: '2026-08-21T11:00:00+09:00',
      stationName: '인계동',
      pm10: 42,
      pm25: 18,
      airQualityGrade: 'Moderate',
      ozone: 0.032,
      ozoneGrade: 'Good',
      provider: 'AIRKOREA',
    });
    const url = new URL(String(fetcher.mock.calls[0][0]));
    expect(url.searchParams.get('serviceKey')).toBe('abc+123');
    expect(url.searchParams.get('stationName')).toBe('인계동');
    expect(url.searchParams.get('returnType')).toBe('json');
  });

  it('skips rows where every environmental measurement is missing', async () => {
    const fetcher = vi.fn<typeof fetch>().mockResolvedValue(
      Response.json({
        response: {
          header: { resultCode: '00', resultMsg: 'NORMAL_CODE' },
          body: {
            items: [
              {
                stationName: '인계동',
                dataTime: '2026-08-21 12:00',
                pm10Value: '-',
                pm25Value: '-',
                o3Value: '-',
              },
              {
                stationName: '인계동',
                dataTime: '2026-08-21 11:00',
                pm10Value: '55',
                pm25Value: '31',
              },
            ],
          },
        },
      }),
    );
    const provider = new AirKoreaAirQualityProvider({
      serviceKey: 'key',
      fetcher,
      now: () => new Date('2026-08-21T02:30:00Z'),
    });

    const result = await provider.getByRegion(60, 121, '인계동');

    expect(result.observedAt).toBe('2026-08-21T11:00:00+09:00');
    expect(result.pm10).toBe(55);
    expect(result.pm25).toBe(31);
  });

  it('selects a nearby official station from GPS coordinates', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const url = new URL(String(input));
      if (url.pathname.endsWith('/getMsrstnList')) {
        return Response.json({
          response: {
            header: { resultCode: '00', resultMsg: 'NORMAL_CODE' },
            body: {
              totalCount: 2, pageNo: 1, numOfRows: 1000,
              items: [
                {
                  stationName: '종로구',
                  dmX: '37.5720',
                  dmY: '127.0050',
                },
                {
                  stationName: '광복동',
                  dmX: '35.1030',
                  dmY: '129.0320',
                },
              ],
            },
          },
        });
      }
      return Response.json({
        response: {
          header: { resultCode: '00', resultMsg: 'NORMAL_CODE' },
          body: {
            items: [
              {
                stationName: url.searchParams.get('stationName'),
                dataTime: '2026-08-21 11:00',
                pm10Value: '31',
                pm25Value: '12',
                o3Value: '0.028',
              },
            ],
          },
        },
      });
    });
    const provider = new AirKoreaAirQualityProvider({
      serviceKey: 'key',
      fetcher,
      now: () => new Date('2026-08-21T02:30:00Z'),
    });

    const result = await provider.getByLocation(35.1796, 129.0756);

    expect(result.stationName).toBe('광복동');
    expect(fetcher).toHaveBeenCalledTimes(2);
    const measurementUrl = new URL(String(fetcher.mock.calls[1][0]));
    expect(measurementUrl.searchParams.get('stationName')).toBe('광복동');
  });
});
