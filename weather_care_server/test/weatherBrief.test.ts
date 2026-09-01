import { describe, expect, it } from 'vitest';
import {
  buildWeatherBrief,
  buildWeatherBriefResult,
} from '../src/presentation/weatherBrief';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../src/types';

describe('weather brief policy', () => {
  it('puts the reason before a conditional umbrella action', () => {
    const result = buildWeatherBriefResult(
      forecast([
        snapshot(12),
        snapshot(18, {
          precipitationType: 'RAIN',
          precipitationProbability: 70,
        }),
      ]),
    );

    expect(result.scene).toBe('WET_TRAVEL');
    expect(result.slots.eventTime).toBe('오후 6시');
    expect(result.text).toBe(
      '비가 올 수 있으니, 오후 6시 외출한다면 우산을 챙기세요',
    );
    expect(result.text).not.toMatch(/출근길|퇴근길|안전해요|좋은 때/);
  });

  it('uses the official shower name only for a shower code', () => {
    const shower = buildWeatherBriefResult(
      forecast([
        snapshot(15, {
          precipitationType: 'SHOWER',
          precipitationProbability: 60,
        }),
      ]),
    );
    const rain = buildWeatherBriefResult(
      forecast([snapshot(15, { precipitationProbability: 60 })]),
    );

    expect(shower.text).toContain('소나기가 내릴 수 있으니');
    expect(rain.text).toContain('비가 올 수 있으니');
    expect(rain.text).not.toContain('소나기');
  });

  it('selects a grounded action for each supported condition', () => {
    const scenarios: Array<[WeatherForecast, string, RegExp]> = [
      [
        forecast([
          snapshot(7, {
            precipitationType: 'SNOW',
            snowExpected: true,
          }),
        ]),
        'CAREFUL_STEPS',
        /도로 상태와 대중교통 운행정보를 확인하세요/,
      ],
      [forecast([snapshot(12)], { pm25: 50 }), 'MASK_READY', /마스크/],
      [
        forecast([snapshot(14, { apparentTemperature: 33 })]),
        'SHADE_BREAK',
        /물을 준비하세요/,
      ],
      [
        forecast([snapshot(14, { uvIndex: 7 })]),
        'SHADE_BREAK',
        /양산이나 모자를 준비하세요/,
      ],
      [
        forecast([snapshot(6, { apparentTemperature: 4 })]),
        'LAYER_READY',
        /겉옷을 준비하세요/,
      ],
      [
        forecast([snapshot(15, { windSpeed: 9 })]),
        'STEADY_PACE',
        /소지품을 단단히 고정하세요/,
      ],
      [
        forecast([snapshot(12)]),
        'DAILY_RHYTHM',
        /시간별 예보를 확인하세요/,
      ],
    ];

    for (const [input, scene, action] of scenarios) {
      const result = buildWeatherBriefResult(input);
      expect(result.scene).toBe(scene);
      expect(result.text).toMatch(action);
    }
  });

  it('keeps the same brief for the same weather input', () => {
    const input = forecast([
      snapshot(18, {
        precipitationType: 'RAIN',
        precipitationProbability: 70,
      }),
    ]);

    expect(buildWeatherBrief(input)).toBe(buildWeatherBrief(input));
  });
});

function forecast(
  hourly: WeatherSnapshot[],
  currentOverrides: Partial<WeatherSnapshot> = {},
): WeatherForecast {
  return {
    current: snapshot(6, currentOverrides),
    hourly,
    daily: [],
    baseDate: '20260821',
    baseTime: '0500',
    dataSource: '기상청 단기예보',
  };
}

function snapshot(
  hour: number,
  overrides: Partial<WeatherSnapshot> = {},
): WeatherSnapshot {
  const observedAt =
    `2026-08-21T${String(hour).padStart(2, '0')}:00:00+09:00`;
  return {
    observedAt,
    forecastAt: observedAt,
    temperature: 22,
    apparentTemperature: 22,
    humidity: 60,
    windSpeed: 2,
    precipitationType: 'NONE',
    precipitationProbability: 0,
    skyCondition: '맑음',
    ...overrides,
  };
}
