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
});
