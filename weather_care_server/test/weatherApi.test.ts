import { describe, expect, it, vi } from 'vitest';
import router, {
  buildOptionalProviderTimeoutStatusMessages,
  buildTimeline,
  recommendationsForDay,
  settleWithin,
} from '../src/api/weather';
import { KmaWeatherProvider } from '../src/providers/weather/kmaWeatherProvider';
import type { DailyWeatherForecast } from '../src/providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../src/types';

describe('weekly calendar date contract', () => {
  it.each([
    ['20260910', '2026-09-10', '목'],
    ['20261231', '2026-12-31', '목'],
    ['20270101', '2027-01-01', '금'],
  ])('adds the exact forecast date without replacing the legacy weekday (%s)', async (date, forecastDate, weekday) => {
    const provider = vi.spyOn(KmaWeatherProvider.prototype, 'getForecastByRegion')
      .mockResolvedValue({
        current: snapshot(14),
        hourly: [],
        daily: [{ ...day(28), date }],
        baseDate: '20260910',
        baseTime: '1100',
        dataSource: '기상청',
      });
    try {
      const response = await router.request('/weekly?nx=60&ny=121', {}, {
        KMA_SERVICE_KEY: 'test-key',
      });
      expect(response.status).toBe(200);
      expect(await response.json()).toMatchObject({
        regionId: '60_121',
        days: [{ date: weekday, forecastDate, min: '22', max: '28' }],
      });
      expect(provider).toHaveBeenCalledWith(60, 121);
    } finally {
      provider.mockRestore();
    }
  });
});

describe('weekly recommendation inputs', () => {
  it('uses hourly apparent temperature instead of treating the daily maximum as apparent', () => {
    const hotAirOnly = recommendationsForDay(day(35), [
      snapshot(14, { temperature: 35, apparentTemperature: 30 }),
    ]);
    expect(hotAirOnly.map((item) => item.type)).not.toContain('WATER');

    const highApparent = recommendationsForDay(day(30), [
      snapshot(14, { temperature: 30, apparentTemperature: 35 }),
    ]);
    expect(highApparent.map((item) => item.type)).toContain('WATER');
  });

  it('marks disabled preparation recommendations as not recommended', () => {
    const recommendations = recommendationsForDay(day(24), [
      snapshot(14, {
        precipitationType: 'RAIN',
        precipitationProbability: 90,
        precipitationAmount: 5,
      }),
      snapshot(15, {
        precipitationType: 'RAIN',
        precipitationProbability: 90,
        precipitationAmount: 5,
      }),
    ], {
      umbrellaEnabled: false,
    });

    expect(recommendations.find((item) => item.type === 'UMBRELLA')).toMatchObject({
      recommended: false,
    });
  });
});

describe('today timeline', () => {
  it('shows five points at three-hour intervals across twelve hours', () => {
    const timeline = buildTimeline(
      Array.from({ length: 13 }, (_, index) => snapshot(6 + index)),
    );

    expect(timeline.map((item) => item.timeLabel)).toEqual([
      '06',
      '09',
      '12',
      '15',
      '18',
    ]);
    expect(
      timeline.every(
        (item) => item.stateLabel === '시간별 예보를 확인하세요',
      ),
    ).toBe(true);
  });
});

describe('today optional provider deadline', () => {
  it('returns a provider result that arrives within the deadline', async () => {
    await expect(settleWithin(Promise.resolve('ready'), 'fallback', 3_500))
      .resolves.toEqual({ value: 'ready', timedOut: false });
  });

  it('returns the fallback when the provider exceeds the deadline', async () => {
    vi.useFakeTimers();
    try {
      const result = settleWithin(
        new Promise<string>(() => undefined),
        'fallback',
        3_500,
      );

      await vi.advanceTimersByTimeAsync(3_500);

      await expect(result).resolves.toEqual({
        value: 'fallback',
        timedOut: true,
      });
    } finally {
      vi.useRealTimers();
    }
  });

  it('explains only the optional data that missed the deadline', () => {
    expect(
      buildOptionalProviderTimeoutStatusMessages({
        precipitation: true,
        warning: false,
        roadIce: false,
        roadControl: true,
      }),
    ).toEqual([
      {
        role: 'DATA_STATUS',
        text: '자료를 받아오지 못해 현재 강수 상태를 확인하기 어려워요',
        source: '기상청 관측분석자료·기상청 레이더',
      },
      {
        role: 'DATA_STATUS',
        text: '자료를 받아오지 못해 현재 도로 통제 상태를 확인하기 어려워요',
        source: '국가교통정보센터 돌발상황정보',
      },
    ]);
  });
});

function day(maxTemperature: number): DailyWeatherForecast {
  return {
    date: '20260820',
    minTemperature: 22,
    maxTemperature,
    skyCondition: '맑음',
    precipitationProbability: 0,
    precipitationAmount: 0,
    snowProbability: 0,
    snowfallAmount: 0,
  };
}

function snapshot(
  hour: number,
  overrides: Partial<WeatherSnapshot> = {},
): WeatherSnapshot {
  const time = `2026-08-20T${String(hour).padStart(2, '0')}:00:00+09:00`;
  return {
    observedAt: time,
    forecastAt: time,
    validFrom: time,
    validTo: `2026-08-20T${String(hour).padStart(2, '0')}:59:59+09:00`,
    temperature: 24,
    apparentTemperature: 24,
    humidity: 60,
    windSpeed: 2,
    precipitationType: 'NONE',
    precipitationProbability: 0,
    precipitationAmount: 0,
    snowfallAmount: 0,
    ...overrides,
  };
}
