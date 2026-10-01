import { describe, expect, it, vi } from 'vitest';
import {
  buildForecastFromItems,
  calculateKmaApparentTemperature,
  dailyCoverageBaseDateTimes,
  KmaForecastItem,
  KmaWeatherProvider,
  latestBaseDateTimes,
  parseAmountRange,
  parsePrecipitationAmount,
} from '../src/providers/weather/kmaWeatherProvider';

const base = { baseDate: '20260820', baseTime: '0800' };

describe('KmaWeatherProvider', () => {
  it.each([
    { TMP: '28' },
    { TMP: '28', PTY: '0' },
    { TMP: '28', SKY: '1' },
    { TMP: '28', PTY: '9', SKY: '1' },
    { TMP: '28', PTY: '0', SKY: '9' },
    { TMP: '28', PTY: '', SKY: '1' },
  ])('does not fill missing or invalid weather codes with clear skies (%j)', (values) => {
    const forecast = buildForecastFromItems(slot('20260820', '1000', values), new Date('2026-08-20T01:00:00Z'), base);
    expect(forecast.current.skyCondition).toBeUndefined();
    expect(forecast.daily[0].skyCondition).toBe('정보 없음');
    expect(forecast.daily[0].weatherDataComplete).toBe(false);
  });

  it('keeps weather when TMP is missing and does not turn blank temperatures into zero', () => {
    const forecast = buildForecastFromItems([
      ...slot('20260820', '1000', { TMP: '', PTY: '1', POP: '90' }),
      ...slot('20260820', '1100', { REH: '60' }),
      item('20260820', '0600', 'TMN', ' '),
    ], new Date('2026-08-20T01:00:00Z'), base);
    expect(forecast.hourly).toHaveLength(2);
    expect(forecast.current.temperature).toBeUndefined();
    expect(forecast.current.apparentTemperature).toBeUndefined();
    expect(forecast.current.kmaApparentTemperature).toBeUndefined();
    expect(forecast.current.skyCondition).toBe('비');
    expect(forecast.daily[0].minTemperature).toBeUndefined();
    expect(forecast.daily[0].maxTemperature).toBeUndefined();
    expect(forecast.daily[0].weatherDataComplete).toBe(false);
  });

  it('separates official daily temperatures from the extrema of received hourly slots', () => {
    const forecast = buildForecastFromItems([
      ...slot('20260820', '1000', { TMP: '-3', PTY: '0', SKY: '1' }),
      ...slot('20260820', '1100', { TMP: '0', PTY: '0', SKY: '1' }),
      item('20260820', '1500', 'TMX', '5'),
    ], new Date('2026-08-20T01:00:00Z'), base);
    expect(forecast.daily[0]).toMatchObject({
      minTemperature: -3, minTemperatureSource: 'HOURLY',
      maxTemperature: 5, maxTemperatureSource: 'DAILY', weatherDataComplete: true,
    });
  });

  it('marks a missing hour between received slots as incomplete weather', () => {
    const forecast = buildForecastFromItems([
      ...slot('20260820', '1000', { TMP: '28', PTY: '0', SKY: '1' }),
      ...slot('20260820', '1200', { TMP: '29', PTY: '0', SKY: '1' }),
    ], new Date('2026-08-20T01:00:00Z'), base);
    expect(forecast.daily[0].weatherDataComplete).toBe(false);
  });

  it('accepts complete 3-hour extended slots and detects a missing slot', () => {
    const current = slot('20260820', '1000', { TMP: '28', PTY: '0', SKY: '1' });
    const extended = (times: string[]) => times.flatMap((time) =>
      slot('20260823', time, { TMP: '25', PTY: '0', SKY: '4' }),
    );
    const complete = buildForecastFromItems(
      [...current, ...extended(['0000', '0300', '0600'])],
      new Date('2026-08-20T01:00:00Z'),
      base,
    );
    const incomplete = buildForecastFromItems(
      [...current, ...extended(['0000', '0600'])],
      new Date('2026-08-20T01:00:00Z'),
      base,
    );

    expect(complete.daily.find((day) => day.date === '20260823')).toMatchObject({
      precipitationDetail: { kind: 'EXTENDED' },
      weatherDataComplete: true,
    });
    expect(incomplete.daily.find((day) => day.date === '20260823')?.weatherDataComplete).toBe(false);
  });

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

  it('selects the first daily issue or the previous-night issue for coverage', () => {
    expect(
      dailyCoverageBaseDateTimes(new Date('2026-09-15T00:24:00Z')),
    ).toEqual([
      { baseDate: '20260915', baseTime: '0200' },
      { baseDate: '20260914', baseTime: '2300' },
      { baseDate: '20260914', baseTime: '2000' },
    ]);
    expect(
      dailyCoverageBaseDateTimes(new Date('2026-09-14T16:00:00Z')),
    ).toEqual([
      { baseDate: '20260914', baseTime: '2300' },
      { baseDate: '20260914', baseTime: '2000' },
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

  it('uses the official KMA seasonal apparent-temperature formulas', () => {
    expect(
      calculateKmaApparentTemperature(
        28,
        70,
        2.2,
        '2026-08-20T10:00:00+09:00',
      ),
    ).toBe(29.3);
    expect(
      calculateKmaApparentTemperature(
        0,
        60,
        1.3,
        '2026-02-20T10:00:00+09:00',
      ),
    ).toBe(-1.4);
    expect(
      calculateKmaApparentTemperature(
        18,
        60,
        1.3,
        '2026-10-20T10:00:00+09:00',
      ),
    ).toBe(18);
  });

  it('calculates a separate apparent-temperature estimate outside KMA conditions', () => {
    const octoberBase = { baseDate: '20261001', baseTime: '0800' };
    const forecast = buildForecastFromItems(
      slot('20261001', '1000', {
        TMP: '19', REH: '25', WSD: '3.5', PTY: '0', SKY: '1',
      }),
      new Date('2026-10-01T00:49:00Z'),
      octoberBase,
    );

    expect(forecast.current.temperature).toBe(19);
    expect(forecast.current.apparentTemperature).toBe(14.4);
    expect(forecast.current.kmaApparentTemperature).toBeUndefined();
    expect(forecast.current.apparentTemperatureSource)
      .toBe('APP_STEADMAN_FROM_FORECAST');
    expect(forecast.current.apparentTemperatureFormulaVersion)
      .toBe('STEADMAN_AT_NO_RADIATION_1994.1');
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
    expect(forecast.current.apparentTemperature).toBe(29.3);
    expect(forecast.current.kmaApparentTemperature).toBe(29.3);
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

  it('retains the fifth calendar day from an evening extended forecast', () => {
    const eveningBase = { baseDate: '20260820', baseTime: '1700' };
    const items = [20, 21, 22, 23, 24, 25].flatMap((day) =>
      slot(
        `202608${day}`,
        '1800',
        { TMP: String(day), PTY: '0', SKY: '1' },
        eveningBase,
      ),
    );

    const forecast = buildForecastFromItems(
      items,
      new Date('2026-08-20T09:00:00Z'),
      eveningBase,
    );

    expect(forecast.daily.map((day) => day.date)).toEqual([
      '20260820',
      '20260821',
      '20260822',
      '20260823',
      '20260824',
    ]);
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
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const requestBase = new URL(String(input)).searchParams.get('base_time');
      if (requestBase === '0800') {
        return Response.json({
          response: {
            header: { resultCode: '03', resultMsg: 'NO_DATA' },
          },
        });
      }
      if (requestBase === '0500') {
        return successResponse(
          successItems.map((item) => ({ ...item, baseTime: '0500' })),
        );
      }
      if (requestBase === '0200') {
        return successResponse(
          slot(
            '20260820',
            '0300',
            { TMP: '21', PTY: '0', SKY: '1' },
            { baseDate: '20260820', baseTime: '0200' },
          ),
        );
      }
      throw new Error(`Unexpected base time: ${requestBase}`);
    });

    const provider = new KmaWeatherProvider({
      serviceKey: 'abc%2B123',
      fetcher,
      now: () => new Date('2026-08-20T01:00:00Z'),
    });
    const forecast = await provider.getForecastByRegion(60, 121);

    expect(fetcher).toHaveBeenCalledTimes(3);
    const requestUrls = fetcher.mock.calls.map(([input]) =>
      new URL(String(input)),
    );
    const firstUrl = requestUrls[0];
    expect(firstUrl.searchParams.get('serviceKey')).toBe('abc+123');
    expect(firstUrl.searchParams.get('base_time')).toBe('0800');
    expect(requestUrls.map((url) => url.searchParams.get('base_time'))).toEqual(
      expect.arrayContaining(['0200', '0500', '0800']),
    );
    expect(forecast.current.temperature).toBe(27);
    expect(forecast.timelineHourly?.[0].temperature).toBe(21);
  });

  it('loads the latest issue only for the fast Main response', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const requestBase = new URL(String(input)).searchParams.get('base_time');
      if (requestBase !== '0800') {
        throw new Error(`Unexpected base time: ${requestBase}`);
      }
      return successResponse(
        slot(
          '20260915',
          '1000',
          { TMP: '25', REH: '60', WSD: '2', PTY: '0', SKY: '1' },
          { baseDate: '20260915', baseTime: '0800' },
        ),
      );
    });
    const provider = new KmaWeatherProvider({
      serviceKey: 'test-key',
      fetcher,
      now: () => new Date('2026-09-15T00:24:00Z'),
    });

    const forecast = await provider.getLatestForecastByRegion(60, 121);

    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(forecast.current.temperature).toBe(25);
  });

  it('retains early hours from the first issue and lets the latest issue win', async () => {
    const fetcher = vi.fn<typeof fetch>(async (input) => {
      const requestBase = new URL(String(input)).searchParams.get('base_time');
      if (requestBase === '0800') {
        return successResponse([
          ...slot(
            '20260915',
            '0900',
            { TMP: '25', PTY: '0', SKY: '1' },
            { baseDate: '20260915', baseTime: '0800' },
          ),
          ...slot(
            '20260916',
            '0000',
            { TMP: '20', PTY: '0', SKY: '3' },
            { baseDate: '20260915', baseTime: '0800' },
          ),
        ]);
      }
      if (requestBase === '0200') {
        return successResponse([
          ...slot(
            '20260915',
            '0300',
            { TMP: '18', PTY: '0', SKY: '1' },
            { baseDate: '20260915', baseTime: '0200' },
          ),
          ...slot(
            '20260915',
            '0600',
            { TMP: '20', PTY: '0', SKY: '3' },
            { baseDate: '20260915', baseTime: '0200' },
          ),
          ...slot(
            '20260915',
            '0900',
            { TMP: '23', PTY: '0', SKY: '4' },
            { baseDate: '20260915', baseTime: '0200' },
          ),
        ]);
      }
      throw new Error(`Unexpected base time: ${requestBase}`);
    });
    const provider = new KmaWeatherProvider({
      serviceKey: 'test-key',
      fetcher,
      now: () => new Date('2026-09-15T00:24:00Z'),
    });

    const forecast = await provider.getForecastByRegion(60, 121);

    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(forecast.hourly.map((item) => item.observedAt)).toEqual([
      '2026-09-15T09:00:00+09:00',
      '2026-09-16T00:00:00+09:00',
    ]);
    expect(forecast.current.temperature).toBe(25);
    expect(forecast.timelineHourly?.map((item) => [
      item.observedAt,
      item.temperature,
      item.issuedAt,
    ])).toEqual([
      ['2026-09-15T03:00:00+09:00', 18, '2026-09-15T02:00:00+09:00'],
      ['2026-09-15T06:00:00+09:00', 20, '2026-09-15T02:00:00+09:00'],
      ['2026-09-15T09:00:00+09:00', 25, '2026-09-15T08:00:00+09:00'],
      ['2026-09-16T00:00:00+09:00', 20, '2026-09-15T08:00:00+09:00'],
    ]);
  });
});

function slot(
  date: string,
  time: string,
  values: Record<string, string>,
  sourceBase: { baseDate: string; baseTime: string } = base,
): KmaForecastItem[] {
  return Object.entries(values).map(([category, value]) =>
    item(date, time, category, value, sourceBase),
  );
}

function item(
  date: string,
  time: string,
  category: string,
  value: string,
  sourceBase: { baseDate: string; baseTime: string } = base,
): KmaForecastItem {
  return {
    ...sourceBase,
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
