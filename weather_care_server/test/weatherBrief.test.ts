import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  buildWeatherBrief,
  buildWeatherBriefResult,
} from '../src/presentation/weatherBrief';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../src/types';

describe('weather brief policy', () => {
  beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(new Date('2026-08-21T06:00:00+09:00')); });
  afterEach(() => vi.useRealTimers());
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
        forecast([snapshot(12, { visibilityMeters: 700 })]),
        'LOW_VISIBILITY',
        /운전한다면 감속하고 주변을 살펴주세요/,
      ],
      [
        forecast([snapshot(12, { humidity: 85 })]),
        'HUMID_AIR',
        /눅눅하게 느껴지고 빨래가 더디게 마를 수 있어요/,
      ],
      [
        forecast([snapshot(12, { humidity: 30 })]),
        'DRY_AIR',
        /건조해 코나 목이 마르게 느껴질 수 있어요/,
      ],
      [
        forecast([snapshot(12)], { visibilityMeters: 20_000 }),
        'CLEAR_VIEW',
        /멀리 있는 건물까지 또렷하게 보일 만큼 시야가 좋아요/,
      ],
      [
        forecast([snapshot(12)]),
        'DAILY_RHYTHM',
        /특별한 예보가 없으나, 외출 전에 시간별 예보를 확인해보세요/,
      ],
    ];

    for (const [input, scene, action] of scenarios) {
      const result = buildWeatherBriefResult(input);
      expect(result.scene).toBe(scene);
      expect(result.text).toMatch(action);
    }
  });

  it('describes visibility and humidity without exposing measurements', () => {
    const lowVisibility = buildWeatherBriefResult(
      forecast([snapshot(12, { visibilityMeters: 180 })]),
    );
    const humid = buildWeatherBriefResult(
      forecast([snapshot(12, { humidity: 88 })]),
    );

    expect(lowVisibility.text).not.toMatch(/180|m\b|km/);
    expect(humid.text).not.toMatch(/88|%/);
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

  it.each(['14:00:00', '14:10:00', '14:30:00', '14:59:58'])(
    'labels the still-valid UV hour as now at %s, preserving raw forecast time', (clock) => {
      const sample = snapshot(14, { uvIndex: 7, validTo: '2026-08-21T14:59:59+09:00' });
      const input = forecast([sample]);
      const original = JSON.stringify(input);
      const result = buildWeatherBriefResult(input, { now: new Date(`2026-08-21T${clock}+09:00`) });
      expect(result.text).toBe('자외선이 강할 수 있으니, 지금 외출한다면 양산이나 모자를 준비하세요');
      expect(result.expiresAt).toBe('2026-08-21T05:59:59.000Z');
      expect(JSON.stringify(input)).toBe(original);
    },
  );

  it.each(['14:59:59', '15:00:00', '17:00:00'])(
    'does not use expired UV even when it is the current snapshot at %s', (clock) => {
      const old = snapshot(14, { uvIndex: 9, validTo: '2026-08-21T14:59:59+09:00' });
      const result = buildWeatherBriefResult({ ...forecast([old]), current: old },
        { now: new Date(`2026-08-21T${clock}+09:00`) });
      expect(result.scene).toBe('DAILY_RHYTHM');
      expect(result.slots).toEqual({});
      expect(result.expiresAt).toBeUndefined();
      expect(result.text).not.toContain('자외선');
    },
  );

  it('selects the earliest remaining UV hour and expires the future wording at its start', () => {
    const result = buildWeatherBriefResult(forecast([
      snapshot(17, { uvIndex: 9 }), snapshot(16, { uvIndex: 6 }), snapshot(14, { uvIndex: 10 }),
    ]), { now: new Date('2026-08-21T15:10:00+09:00') });
    expect(result.slots.eventTime).toBe('오후 4시');
    expect(result.expiresAt).toBe('2026-08-21T07:00:00.000Z');
  });

  it('does not select next-day weather, including across a year boundary', () => {
    const sample = { ...snapshot(10, { uvIndex: 7 }), forecastAt: '2027-01-01T01:00:00Z' };
    const result = buildWeatherBriefResult(forecast([sample]),
      { now: new Date('2026-12-31T23:30:00+09:00') });
    expect(result.scene).toBe('DAILY_RHYTHM');
    expect(result.slots).toEqual({});
    expect(result.expiresAt).toBeUndefined();
    expect(result.text).not.toMatch(/내일|모레/);
  });

  it('does not select the day-after-tomorrow weather', () => {
    const sample = { ...snapshot(10, { uvIndex: 7 }), forecastAt: '2026-08-23T10:00:00+09:00' };
    const result = buildWeatherBriefResult(forecast([sample]),
      { now: new Date('2026-08-21T20:00:00+09:00') });
    expect(result.scene).toBe('DAILY_RHYTHM');
    expect(result.text).not.toMatch(/내일|모레/);
  });

  it('does not let old snow/rain mask a remaining UV action', () => {
    const result = buildWeatherBriefResult(forecast([
      snapshot(13, { precipitationType: 'SNOW', snowExpected: true }),
      snapshot(14, { precipitationType: 'RAIN' }), snapshot(16, { uvIndex: 7 }),
    ]), { now: new Date('2026-08-21T15:00:00+09:00') });
    expect(result.scene).toBe('SHADE_BREAK');
    expect(result.slots.eventTime).toBe('오후 4시');
  });

  it('uses the active preceding rain interval and never reuses it after its end', () => {
    const rain = snapshot(15, { precipitationType: 'RAIN', precipitationPeriod: {
      start: '2026-08-21T14:00:00+09:00', end: '2026-08-21T15:00:00+09:00',
    } });
    const input = forecast([rain]);
    const ongoing = buildWeatherBriefResult(input, { now: new Date('2026-08-21T14:30:00+09:00') });
    expect(ongoing.scene).toBe('WET_TRAVEL');
    expect(ongoing.slots.eventTime).toBe('지금');
    expect(ongoing.expiresAt).toBe('2026-08-21T06:00:00.000Z');
    expect(buildWeatherBriefResult(input, { now: new Date('2026-08-21T15:00:00+09:00') }).scene)
      .toBe('DAILY_RHYTHM');
  });

  it.each([
    { forecastAt: 'invalid' }, { validTo: 'invalid' },
    { validTo: '2026-08-21T13:00:00+09:00' },
  ])('ignores invalid point validity without throwing: %j', (overrides) => {
    expect(buildWeatherBriefResult(forecast([snapshot(14, { uvIndex: 7, ...overrides })]),
      { now: new Date('2026-08-21T14:10:00+09:00') }).scene).toBe('DAILY_RHYTHM');
  });

  it('does not infer missing UV or select more than 24 hours ahead', () => {
    const later = { ...snapshot(16, { uvIndex: 7 }), forecastAt: '2026-08-22T16:00:00+09:00' };
    expect(buildWeatherBriefResult(forecast([snapshot(16), later]),
      { now: new Date('2026-08-21T16:00:00+09:00') }).scene).toBe('DAILY_RHYTHM');
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
