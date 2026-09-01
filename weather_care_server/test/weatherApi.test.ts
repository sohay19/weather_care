import { describe, expect, it } from 'vitest';
import { buildTimeline, recommendationsForDay } from '../src/api/weather';
import type { DailyWeatherForecast } from '../src/providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../src/types';

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
