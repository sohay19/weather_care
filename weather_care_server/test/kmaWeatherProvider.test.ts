import { describe, expect, it, vi } from 'vitest';
import {
  buildForecastFromItems,
  KmaForecastItem,
  KmaWeatherProvider,
  latestBaseDateTimes,
  parseAmountRange,
  parsePrecipitationAmount,
} from '../src/providers/weather/kmaWeatherProvider';

const base = { baseDate: '20260820', baseTime: '0800' };

describe('KmaWeatherProvider', () => {
  it('selects the latest published base time in Korea', () => {
    expect(
      latestBaseDateTimes(new Date('2026-08-20T01:00:00Z'), 4),
    ).toEqual([
      { baseDate: '20260820', baseTime: '0800' },
      { baseDate: '20260820', baseTime: '0500' },
      { baseDate: '20260820', baseTime: '0200' },
      { baseDate: '20260819', baseTime: '2300' },
    ]);
  });

  it('parses KMA precipitation amount labels', () => {
    expect(parsePrecipitationAmount('강수없음')).toBe(0);
    expect(parsePrecipitationAmount('1.0mm 미만')).toBe(0);
    expect(parsePrecipitationAmount('30.0~50.0mm')).toBe(30);
    expect(parseAmountRange('1.0mm 미만', 'MM')).toEqual({
      type: 'LESS_THAN',
      min: 0,
      max: 1,
      unit: 'MM',
      rawValue: '1.0mm 미만',
    });
    expect(parseAmountRange('30.0~50.0mm', 'MM')).toEqual({
      type: 'RANGE',
      min: 30,
      max: 50,
      unit: 'MM',
      rawValue: '30.0~50.0mm',
    });
    expect(parseAmountRange('5.0cm 이상', 'CM')).toEqual({
      type: 'AT_LEAST',
      min: 5,
      unit: 'CM',
      rawValue: '5.0cm 이상',
    });
  });

  it('builds current, hourly and daily weather from forecast items', () => {
    const items = [
      ...slot('20260820', '1000', {
        TMP: '28',
        REH: '70',
        WSD: '2.2',
        POP: '20',
        PCP: '강수없음',
        SNO: '적설없음',
        PTY: '0',
        SKY: '3',
      }),
      ...slot('20260820', '1100', {
        TMP: '29',
        REH: '72',
        WSD: '2.8',
        POP: '70',
        PCP: '1.0mm 미만',
        SNO: '적설없음',
        PTY: '1',
        SKY: '4',
      }),
      item('20260820', '0600', 'TMN', '22'),
      item('20260820', '1500', 'TMX', '31'),
      ...slot('20260821', '0900', {
        TMP: '25',
        REH: '80',
        WSD: '3.1',
        POP: '60',
        PCP: '3.0mm',
        SNO: '적설없음',
        PTY: '4',
        SKY: '4',
      }),
    ];

    const forecast = buildForecastFromItems(
      items,
      new Date('2026-08-20T00:30:00Z'),
      base,
    );

    expect(forecast.dataSource).toBe('기상청 단기예보');
    expect(forecast.current.temperature).toBe(28);
    expect(forecast.current.minTemperature).toBe(22);
    expect(forecast.current.maxTemperature).toBe(31);
    expect(forecast.hourly).toHaveLength(3);
    expect(forecast.hourly[1].skyCondition).toBe('비');
    expect(forecast.hourly[1]).toEqual(
      expect.objectContaining({
        forecastAt: '2026-08-20T11:00:00+09:00',
        validFrom: '2026-08-20T11:00:00+09:00',
        validTo: '2026-08-20T11:59:59+09:00',
        precipitationType: 'RAIN',
        provider: 'KMA',
      }),
    );
    expect(forecast.hourly[1].precipitationAmountRange).toEqual(
      expect.objectContaining({ type: 'LESS_THAN', min: 0, max: 1 }),
    );
    expect(forecast.daily).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          date: '20260820',
          minTemperature: 22,
          maxTemperature: 31,
          precipitationProbability: 70,
          skyCondition: '비',
        }),
        expect.objectContaining({
          date: '20260821',
          precipitationProbability: 60,
          skyCondition: '소나기',
        }),
      ]),
    );
  });

  it('retries the previous base time when the latest data is not ready', async () => {
    const successItems = slot('20260820', '1000', {
      TMP: '27',
      REH: '60',
      WSD: '1.5',
      POP: '10',
      PCP: '강수없음',
      SNO: '적설없음',
      PTY: '0',
      SKY: '1',
    });
    const fetcher = vi
      .fn<typeof fetch>()
      .mockResolvedValueOnce(
        Response.json({
          response: {
            header: { resultCode: '03', resultMsg: 'NO_DATA' },
          },
        }),
      )
      .mockResolvedValueOnce(successResponse(successItems));

    const provider = new KmaWeatherProvider({
      serviceKey: 'abc%2B123',
      fetcher,
      now: () => new Date('2026-08-20T01:00:00Z'),
    });
    const forecast = await provider.getForecastByRegion(60, 121);

    expect(fetcher).toHaveBeenCalledTimes(2);
    const firstUrl = new URL(String(fetcher.mock.calls[0][0]));
    const secondUrl = new URL(String(fetcher.mock.calls[1][0]));
    expect(firstUrl.searchParams.get('serviceKey')).toBe('abc+123');
    expect(firstUrl.searchParams.get('base_time')).toBe('0800');
    expect(secondUrl.searchParams.get('base_time')).toBe('0500');
    expect(forecast.current.temperature).toBe(27);
  });
});

function slot(
  date: string,
  time: string,
  values: Record<string, string>,
): KmaForecastItem[] {
  return Object.entries(values).map(([category, value]) =>
    item(date, time, category, value),
  );
}

function item(
  date: string,
  time: string,
  category: string,
  value: string,
): KmaForecastItem {
  return {
    ...base,
    category,
    fcstDate: date,
    fcstTime: time,
    fcstValue: value,
    nx: 60,
    ny: 121,
  };
}

function successResponse(items: KmaForecastItem[]): Response {
  return Response.json({
    response: {
      header: { resultCode: '00', resultMsg: 'NORMAL_SERVICE' },
      body: { items: { item: items } },
    },
  });
}
