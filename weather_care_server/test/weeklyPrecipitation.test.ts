import { describe, expect, it, vi } from 'vitest';
import router from '../src/api/weather';
import { buildForecastFromItems, KmaWeatherProvider, type KmaForecastItem } from '../src/providers/weather/kmaWeatherProvider';
import { env } from 'cloudflare:test';
import { seedCollectedWeekly } from './collectedWeatherFixture';

const base = { baseDate: '20261231', baseTime: '0800' };
const now = new Date('2026-12-31T01:00:00Z');
function slot(date: string, time: string, values: Record<string, string>): KmaForecastItem[] {
  return Object.entries(values).map(([category, fcstValue]) => ({
    ...base, category, fcstValue, fcstDate: date, fcstTime: time, nx: 60, ny: 121,
  }));
}
const current = () => slot('20261231', '1000', { TMP: '1', POP: '10', PCP: '강수없음' });

describe('weekly precipitation intervals', () => {
  it('assigns midnight PCP and POP to the previous Korean date across a year boundary', () => {
    const forecast = buildForecastFromItems([
      ...current(),
      ...slot('20270101', '0000', { POP: '90', PCP: '1.0mm 미만' }),
      ...slot('20270101', '0100', { POP: '40', PCP: '3.0mm' }),
    ], now, base);
    expect(forecast.daily[0].precipitationDetail?.hours).toHaveLength(2);
    expect(forecast.daily[0].precipitationDetail?.hours[1]).toEqual({
      forecastAt: '2027-01-01T00:00:00+09:00', probability: 90, amountText: '1.0mm 미만',
    });
    expect(forecast.daily[1].precipitationDetail?.hours).toEqual([{
      forecastAt: '2027-01-01T01:00:00+09:00', probability: 40, amountText: '3.0mm',
    }]);
  });

  it('retains missing PCP without zero-fill and rejects impossible probabilities', () => {
    const forecast = buildForecastFromItems([
      ...slot('20261231', '1000', { TMP: '1', POP: '-1' }),
      ...slot('20261231', '1100', { POP: '101', PCP: '자료없음' }),
      ...slot('20261231', '1200', { POP: 'NaN', PCP: ' ' }),
      ...slot('20261231', '1300', { POP: '0', PCP: '강수없음' }),
    ], now, base);
    const hours = forecast.daily[0].precipitationDetail?.hours;
    expect(hours?.map((hour) => hour.probability)).toEqual([undefined, undefined, undefined, 0]);
    expect(hours?.map((hour) => hour.amountText)).toEqual(['', '자료없음', ' ', '강수없음']);
  });

  it.each(['0800', '1700'])('does not treat extended categorical PCP as mm (%s publication)', (baseTime) => {
    const extendedDate = baseTime === '0800' ? '20270103' : '20270104';
    const forecast = buildForecastFromItems([
      ...current(),
      ...slot(extendedDate, '0000', { POP: '100', PCP: '강수없음' }),
      ...slot(extendedDate, '0300', { POP: '60', PCP: '2' }),
      ...slot(extendedDate, '0600', { POP: '30', PCP: '1' }),
    ], now, { ...base, baseTime });
    expect(forecast.daily.find((day) => day.date === extendedDate)?.precipitationDetail).toEqual({
      kind: 'EXTENDED', hours: [], extendedMaxProbability: 60,
    });
  });

  it('builds daily details from the full series, beyond the today 48-slot limit', () => {
    const items = Array.from({ length: 70 }, (_, index) => {
      const kst = new Date(Date.UTC(2026, 11, 31, 10 + index));
      const date = kst.toISOString().slice(0, 10).replaceAll('-', '');
      return slot(date, `${String(kst.getUTCHours()).padStart(2, '0')}00`, { TMP: '1', POP: '60', PCP: '1.0mm' });
    }).flat();
    const forecast = buildForecastFromItems(items, now, base);
    expect(forecast.hourly).toHaveLength(48);
    expect(forecast.daily.find((day) => day.date === '20270102')?.precipitationDetail?.hours).toHaveLength(24);
  });

  it('adds raw range-aware data to the public weekly response without exposing legacy sums', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(now);
    const forecast = buildForecastFromItems(current(), now, base);
    await seedCollectedWeekly(60, 121, {
      forecast,
      midTermDays: [],
      observedDays: [],
      airQuality: [],
    });
    try {
      const response = await router.request('/weekly?nx=60&ny=121', {}, { DB: env.DB });
      expect(response.status).toBe(200);
      const payload = await response.json<{ days: Record<string, unknown>[] }>();
      expect(payload.days[0]).toMatchObject({ forecastDate: '2026-12-31', precipitationDetail: forecast.daily[0].precipitationDetail });
      expect(payload.days[0]).not.toHaveProperty('precipitationAmount');
    } finally {
      vi.useRealTimers();
    }
  });
});
