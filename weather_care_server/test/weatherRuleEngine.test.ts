import { describe, expect, it } from 'vitest';
import { runWeatherRuleEngineForHourly } from '../src/rules/weatherRuleEngine';
import {
  AmountRange,
  WeatherRuleFactType,
  WeatherSnapshot,
} from '../src/types';

describe('WeatherRuleEngine v1.1', () => {
  it('requires two rain slots without assuming a commute schedule', () => {
    const oneDaytimeSlot = runWeatherRuleEngineForHourly([
      snapshot(10, { precipitationProbability: 40 }),
    ]);
    expect(types(oneDaytimeSlot)).not.toContain(WeatherRuleFactType.RAIN_LIKELY);

    const twoDaytimeSlots = runWeatherRuleEngineForHourly([
      snapshot(10, { precipitationProbability: 40 }),
      snapshot(11, { precipitationProbability: 45 }),
    ]);
    expect(types(twoDaytimeSlots)).toContain(WeatherRuleFactType.RAIN_LIKELY);

    const singleEveningSlot = runWeatherRuleEngineForHourly([
      snapshot(18, { precipitationProbability: 40 }),
    ]);
    expect(types(singleEveningSlot)).not.toContain(
      WeatherRuleFactType.RAIN_LIKELY,
    );
  });

  it('uses the conservative lower bound for heavy rain', () => {
    const notHeavy = runWeatherRuleEngineForHourly([
      snapshot(12, {
        precipitationProbability: 70,
        precipitationAmount: 3,
        precipitationAmountRange: range('RANGE', 3, 5, 'MM'),
      }),
    ]);
    expect(types(notHeavy)).not.toContain(WeatherRuleFactType.HEAVY_RAIN);

    const heavy = runWeatherRuleEngineForHourly([
      snapshot(12, {
        precipitationProbability: 70,
        precipitationAmount: 5,
        precipitationAmountRange: range('VALUE', 5, 5, 'MM'),
      }),
    ]);
    expect(types(heavy)).toContain(WeatherRuleFactType.HEAVY_RAIN);
  });

  it('keeps rain active through a single release slot', () => {
    const facts = runWeatherRuleEngineForHourly([
      snapshot(10, { precipitationProbability: 40 }),
      snapshot(11, { precipitationProbability: 45 }),
      snapshot(12, { precipitationProbability: 20 }),
      snapshot(13, { precipitationProbability: 50 }),
    ]);
    const rain = facts.find(
      (fact) => fact.type === WeatherRuleFactType.RAIN_LIKELY,
    );

    expect(rain?.validFrom).toBe('2026-08-20T10:00:00+09:00');
    expect(rain?.validUntil).toBe('2026-08-20T13:59:59+09:00');
  });

  it('derives snow from PTY without snowProbability', () => {
    const facts = runWeatherRuleEngineForHourly([
      snapshot(10, { precipitationType: 'SNOW', snowExpected: true }),
      snapshot(11, { precipitationType: 'SNOW', snowExpected: true }),
    ]);

    expect(types(facts)).toContain(WeatherRuleFactType.SNOW_LIKELY);
  });

  it('does not infer road ice from air temperature and precipitation alone', () => {
    const facts = runWeatherRuleEngineForHourly([
      snapshot(6, {
        temperature: -2,
        apparentTemperature: -5,
        precipitationProbability: 80,
        precipitationType: 'RAIN_SNOW',
      }),
      snapshot(7, {
        temperature: -2,
        apparentTemperature: -5,
        precipitationProbability: 80,
        precipitationType: 'RAIN_SNOW',
      }),
    ]);

    expect(facts.map((fact) => String(fact.type))).not.toContain(
      'ICY_ROAD_RISK',
    );
  });

  it('calculates the daily range from hourly temperatures', () => {
    const facts = runWeatherRuleEngineForHourly([
      snapshot(6, { temperature: 8, apparentTemperature: 8 }),
      snapshot(12, { temperature: 16, apparentTemperature: 16 }),
    ]);

    const rangeFact = facts.find(
      (fact) => fact.type === WeatherRuleFactType.LARGE_DIURNAL_RANGE,
    );
    expect(rangeFact?.evidence.dailyTemperatureRange).toBe(8);
  });

  it('does not infer bedroom or sleep conditions from outdoor night weather', () => {
    const facts = runWeatherRuleEngineForHourly(
      [0, 1, 2].map((hour) =>
        snapshot(hour, { temperature: 25, humidity: 80 }),
      ),
    );

    expect(facts.map((fact) => String(fact.type))).not.toContain(
      'SLEEP_DISCOMFORT_EXPECTED',
    );
  });

  it('aligns particulate thresholds with the app and brief', () => {
    const below = runWeatherRuleEngineForHourly([
      snapshot(10, { pm10: 80, pm25: 35 }),
    ]);
    expect(types(below)).not.toContain(WeatherRuleFactType.PM10_HIGH);
    expect(types(below)).not.toContain(WeatherRuleFactType.PM25_HIGH);

    const threshold = runWeatherRuleEngineForHourly([
      snapshot(10, { pm10: 81, pm25: 36 }),
    ]);
    expect(types(threshold)).toContain(WeatherRuleFactType.PM10_HIGH);
    expect(types(threshold)).toContain(WeatherRuleFactType.PM25_HIGH);
  });
});

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
    precipitationAmountRange: range('NONE', 0, 0, 'MM'),
    snowfallAmount: 0,
    snowfallAmountRange: range('NONE', 0, 0, 'CM'),
    provider: 'KMA',
    ...overrides,
  };
}

function range(
  type: AmountRange['type'],
  min: number,
  max: number,
  unit: AmountRange['unit'],
): AmountRange {
  return { type, min, max, unit, rawValue: String(min) };
}

function types(facts: { type: WeatherRuleFactType }[]): WeatherRuleFactType[] {
  return facts.map((fact) => fact.type);
}
