import { describe, expect, it } from 'vitest';
import { runLifestyleWeatherEngine } from '../src/lifestyle/lifestyleWeatherEngine';
import { lifestyleMessageFor } from '../src/lifestyle/lifestyleTemplates';
import { runWeatherRuleEngineForHourly } from '../src/rules/weatherRuleEngine';
import { runRecommendationEngine } from '../src/recommendations/recommendationEngine';
import { buildLifestyleMessages } from '../src/presentation/lifestyleMessages';
import { sensationMessageCatalog } from '../src/presentation/sensationMessages';
import {
  AmountRange,
  LifestyleInsight,
  LifestyleInsightType,
  WeatherRuleFactType,
  WeatherSnapshot,
} from '../src/types';

describe('Lifestyle v1.1 catalog', () => {
  it('derives a rain recommendation without assuming a commute schedule', () => {
    const hourly = [
      snapshot(8),
      snapshot(18, { precipitationProbability: 70, precipitationType: 'RAIN' }),
      snapshot(19, { precipitationProbability: 70, precipitationType: 'RAIN' }),
    ];
    const facts = runWeatherRuleEngineForHourly(hourly);
    const insights = runLifestyleWeatherEngine(facts, hourly);
    expect(insights.map((item) => String(item.type))).not.toContain(
      'COMMUTE_WEATHER_CHANGE',
    );

    const umbrella = runRecommendationEngine(insights).find(
      (item) => item.type === 'UMBRELLA',
    );
    expect(umbrella).toEqual(
      expect.objectContaining({
        decisionVersion: 'weather-rules-1.2.0',
        catalogVersion: 'ko-KR-2026.09.3',
        reasonCodes: expect.arrayContaining(['RAIN_LIKELY']),
        sourceFields: expect.arrayContaining(['precipitationType']),
      }),
    );
  });

  it('renders time placeholders and never exposes an empty placeholder', () => {
    const rendered = lifestyleMessageFor(
      LifestyleInsightType.RAIN_BREAK_WINDOW,
      0,
      { timeLabel: '오후 2시~4시' },
    );
    expect(rendered.description).toBe(
      '오후 2시~4시에는 비가 잠시 그칠 수 있어요.',
    );

    const fallback = lifestyleMessageFor(
      LifestyleInsightType.PET_WALK_WINDOW,
      0,
    );
    expect(`${fallback.title} ${fallback.description}`).not.toMatch(
      /{{|null/,
    );
  });

  it('suppresses positive outing windows when KMA-only inputs are incomplete', () => {
    const hourly = [snapshot(10), snapshot(11), snapshot(12)];
    const facts = runWeatherRuleEngineForHourly(hourly);
    const insights = runLifestyleWeatherEngine(facts, hourly);

    expect(insights.map((item) => item.type)).not.toContain(
      LifestyleInsightType.BEST_OUTING_WINDOW,
    );
  });

  it('does not pad lifestyle messages with weather-independent tasks', () => {
    const insights: LifestyleInsight[] = [
      {
        type: LifestyleInsightType.RAIN_GEAR_USEFUL,
        score: 90,
        sourceFacts: [],
      },
    ];

    const messages = buildLifestyleMessages(insights);

    expect(messages).toHaveLength(1);
    expect(messages[0].type).toBe(LifestyleInsightType.RAIN_GEAR_USEFUL);
    expect(messages[0].priority).toBe(90);
  });

  it('orders action, impact, and official fact by message role', () => {
    const hourly = [
      snapshot(14, {
        precipitationProbability: 70,
        precipitationType: 'RAIN',
      }),
      snapshot(15, {
        precipitationProbability: 70,
        precipitationType: 'RAIN',
      }),
    ];
    const facts = runWeatherRuleEngineForHourly(hourly);
    const insights = runLifestyleWeatherEngine(facts, hourly);
    const rain = buildLifestyleMessages(
      insights,
      facts,
      hourly,
      '수원',
    ).find((item) => item.type === LifestyleInsightType.RAIN_GEAR_USEFUL);

    expect(rain?.parts.map((part) => part.role)).toEqual([
      'APP_SUGGESTION',
      'INTERNAL_POSSIBILITY',
      'OFFICIAL_FACT',
    ]);
    expect(rain?.parts[2].text).toContain('기상청은 수원의');
    expect(rain?.parts[2].text).toContain('강수확률을 70%로 예보했어요');
  });

  it('omits the redundant current-location label from official facts', () => {
    const hourly = [
      snapshot(14, {
        precipitationProbability: 70,
        precipitationType: 'RAIN',
      }),
    ];
    const facts = runWeatherRuleEngineForHourly(hourly);
    const messages = buildLifestyleMessages(
      runLifestyleWeatherEngine(facts, hourly),
      facts,
      hourly,
      '현재 위치',
    );
    const factTexts = messages.flatMap((message) =>
      message.parts
        .filter((part) => part.role === 'OFFICIAL_FACT')
        .map((part) => part.text),
    );

    expect(
      factTexts.some((text) =>
        text.includes('강수확률을 70%로 예보했어요'),
      ),
    ).toBe(true);
    expect(factTexts.every((text) => !text.includes('현재 위치'))).toBe(true);
  });

  it('does not emit indoor, vehicle, or sleep judgments from weather data', () => {
    const hourly = [0, 1, 2].map((hour) =>
      snapshot(hour, { temperature: 25, humidity: 80 }),
    );
    const facts = runWeatherRuleEngineForHourly(hourly);
    const insights = runLifestyleWeatherEngine(facts, hourly).map((item) =>
      String(item.type),
    );

    expect(insights).not.toContain('INDOOR_DRYING_PREFERRED');
    expect(insights).not.toContain('DEHUMIDIFIER_USEFUL');
    expect(insights).not.toContain('HUMIDIFIER_USEFUL');
    expect(insights).not.toContain('SLEEP_DISCOMFORT_EXPECTED');
    expect(insights).not.toContain('VEHICLE_FROST_RISK');
    expect(insights).toContain('NIGHT_WEATHER_CHECK');
  });

  it('creates a heavy-snow recommendation only for a heavy-snow fact', () => {
    const snowLikely = runRecommendationEngine([
      {
        type: LifestyleInsightType.SNOW_TRAVEL_CAUTION,
        score: 70,
        sourceFacts: [WeatherRuleFactType.SNOW_LIKELY],
      },
    ]);
    expect(snowLikely).toEqual([]);

    const heavySnow = runRecommendationEngine([
      {
        type: LifestyleInsightType.SNOW_TRAVEL_CAUTION,
        score: 95,
        sourceFacts: [WeatherRuleFactType.HEAVY_SNOW],
      },
    ]);
    expect(heavySnow.map((item) => item.type)).toContain(
      'HEAVY_SNOW_CAUTION',
    );
  });

  it('날씨 강도에 따라 준비물을 세트가 아닌 1·2·3개로 늘린다', () => {
    const insights = ({
      rain,
      uv,
      heat,
      cold,
      snow,
      heavyRain = false,
      heavySnow = false,
    }: {
      rain: number;
      uv: number;
      heat: number;
      cold: number;
      snow: number;
      heavyRain?: boolean;
      heavySnow?: boolean;
    }): LifestyleInsight[] => [
      {
        type: LifestyleInsightType.RAIN_GEAR_USEFUL,
        score: rain,
        sourceFacts: [
          heavyRain
            ? WeatherRuleFactType.HEAVY_RAIN
            : WeatherRuleFactType.RAIN_LIKELY,
        ],
      },
      {
        type: LifestyleInsightType.STRONG_SUN_EXPOSURE,
        score: uv,
        sourceFacts: [WeatherRuleFactType.UV_HIGH],
      },
      {
        type: LifestyleInsightType.SUNSCREEN_USEFUL,
        score: uv,
        sourceFacts: [WeatherRuleFactType.UV_HIGH],
      },
      {
        type: LifestyleInsightType.HYDRATION_IMPORTANT,
        score: heat,
        sourceFacts: [WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH],
      },
      {
        type: LifestyleInsightType.OUTERWEAR_USEFUL,
        score: cold,
        sourceFacts: [WeatherRuleFactType.TEMPERATURE_LOW],
      },
      {
        type: LifestyleInsightType.SNOW_TRAVEL_CAUTION,
        score: snow,
        sourceFacts: [
          heavySnow
            ? WeatherRuleFactType.HEAVY_SNOW
            : WeatherRuleFactType.SNOW_LIKELY,
        ],
      },
    ];
    const mild = runRecommendationEngine(insights({
      rain: 55,
      uv: 60,
      heat: 33,
      cold: 88,
      snow: 55,
    }), undefined, { expandedPreparations: true });
    expect(mild.map((item) => item.type)).toEqual([
      'OUTERWEAR',
      'SUNSCREEN',
      'UMBRELLA',
      'WINTER_BOOTS',
      'WATER',
    ]);

    const mediumInsights = insights({
      rain: 75,
      uv: 80,
      heat: 35,
      cold: 90,
      snow: 70,
    });
    const medium = runRecommendationEngine(mediumInsights, undefined, {
      expandedPreparations: true,
    });
    expect(new Set(medium.map((item) => item.type))).toEqual(new Set([
      'UMBRELLA', 'RAINCOAT',
      'SUNSCREEN', 'PARASOL',
      'WATER', 'PORTABLE_FAN',
      'OUTERWEAR', 'SCARF',
      'WINTER_BOOTS', 'POWER_BANK',
    ]));

    const severeInsights = insights({
      rain: 95,
      uv: 100,
      heat: 40,
      cold: 95,
      snow: 95,
      heavyRain: true,
      heavySnow: true,
    });
    const expectedExpanded = new Set([
      'UMBRELLA', 'RAINCOAT', 'RAIN_BOOTS',
      'PARASOL', 'SUNSCREEN', 'SUNGLASSES',
      'WATER', 'PORTABLE_FAN', 'COOLING_ITEM',
      'OUTERWEAR', 'SCARF', 'HAND_WARMER',
      'SNOW_CHAINS', 'POWER_BANK', 'WINTER_BOOTS',
    ]);

    expect(new Set(runRecommendationEngine(mediumInsights).map((item) => item.type)))
      .toEqual(new Set(['UMBRELLA', 'PARASOL', 'SUNSCREEN', 'WATER', 'OUTERWEAR']));

    const expanded = runRecommendationEngine(severeInsights, undefined, {
      expandedPreparations: true,
    });
    expect(new Set(expanded.map((item) => item.type))).toEqual(expectedExpanded);
    const priorities = Object.fromEntries(
      expanded.map((item) => [item.type, item.priority]),
    );
    expect(priorities.UMBRELLA).toBeGreaterThan(priorities.RAINCOAT);
    expect(priorities.RAINCOAT).toBeGreaterThan(priorities.RAIN_BOOTS);
    expect(priorities.SUNSCREEN).toBeGreaterThan(priorities.PARASOL);
    expect(priorities.SNOW_CHAINS).toBeGreaterThan(priorities.WINTER_BOOTS);

    const disabled = runRecommendationEngine(severeInsights, {
      umbrellaEnabled: false,
      parasolEnabled: false,
      sunscreenEnabled: false,
      waterEnabled: false,
      outerwearEnabled: false,
      heavySnowEnabled: false,
    }, { expandedPreparations: true });
    expect(disabled).toHaveLength(15);
    expect(disabled.every((item) => !item.recommended)).toBe(true);
  });

  it('creates a mask recommendation from a bad air-quality grade alone', () => {
    const hourly = [
      snapshot(10, {
        pm10: 10,
        pm25: 10,
        airQualityGrade: 'Bad',
      }),
    ];
    const facts = runWeatherRuleEngineForHourly(hourly);
    const insights = runLifestyleWeatherEngine(facts, hourly);
    const mask = runRecommendationEngine(insights).find(
      (item) => item.type === 'MASK',
    );

    expect(mask?.sourceFields).toContain('airQualityGrade');
  });

  it('keeps three approved expressions for each supported feeling or impact tier', () => {
    const rain = threeDescriptions(
      LifestyleInsightType.RAIN_GEAR_USEFUL,
      snapshot(15, {
        precipitationType: 'RAIN',
        precipitationAmount: 3,
        precipitationAmountRange: range('VALUE', 3, 3, 'MM'),
      }),
    );
    const snow = threeDescriptions(
      LifestyleInsightType.SNOW_TRAVEL_CAUTION,
      snapshot(17, {
        precipitationType: 'SNOW',
        snowExpected: true,
        snowfallAmount: 1.5,
        snowfallAmountRange: range('VALUE', 1.5, 1.5, 'CM'),
      }),
    );
    const uv = threeDescriptions(
      LifestyleInsightType.SUNSCREEN_USEFUL,
      snapshot(13, { uvIndex: 7 }),
    );
    const air = threeDescriptions(
      LifestyleInsightType.MASK_USEFUL,
      snapshot(12, { pm25: 50, airQualityStationName: '수원 측정소' }),
    );
    const humidHeat = threeDescriptions(
      LifestyleInsightType.VERY_HOT_AND_HUMID,
      snapshot(14, { apparentTemperature: 34, humidity: 85 }),
    );
    const ozone = threeDescriptions(
      LifestyleInsightType.OZONE_CAUTION,
      snapshot(14, {
        ozone: 0.102,
        ozoneGrade: 'Bad',
        airQualityStationName: '인계동',
        airQualityObservedAt: '2026-08-20T14:00:00+09:00',
      }),
    );

    for (const variants of [rain, snow, uv, air, humidHeat, ozone]) {
      expect(new Set(variants).size).toBe(3);
    }
  });

  it('stores exactly three approved expressions for every sensation tier', () => {
    for (const messages of Object.values(sensationMessageCatalog)) {
      expect(messages).toHaveLength(3);
      expect(new Set(messages).size).toBe(3);
    }
  });

  it('shows high ozone as action, perception caveat, and official measurement', () => {
    const hourly = [
      snapshot(14, {
        ozone: 0.102,
        ozoneGrade: 'Bad',
        airQualityStationName: '인계동',
        airQualityObservedAt: '2026-08-20T14:00:00+09:00',
      }),
    ];
    const facts = runWeatherRuleEngineForHourly(hourly);
    const insights = runLifestyleWeatherEngine(facts, hourly);
    const ozone = buildLifestyleMessages(
      insights,
      facts,
      hourly,
      '수원',
    ).find((item) => item.type === LifestyleInsightType.OZONE_CAUTION);

    expect(facts.map((item) => item.type)).toContain(
      WeatherRuleFactType.OZONE_HIGH,
    );
    expect(ozone?.parts.map((part) => part.role)).toEqual([
      'APP_SUGGESTION',
      'INTERNAL_POSSIBILITY',
      'OFFICIAL_FACT',
    ]);
    expect(ozone?.parts[0].text).toContain('야외활동');
    expect(sensationMessageCatalog.OZONE_DIRECT_PERCEPTION).toContain(
      ozone?.parts[1].text,
    );
    expect(ozone?.parts[2].text).toBe(
      '에어코리아는 오후 2시 인계동의 오존 농도를 0.102ppm, 나쁨 단계로 제공했어요',
    );
  });

  it('does not assign Korean heat or cold sensation tiers from KMA apparent temperature alone', () => {
    const hourly = [
      snapshot(7, {
        temperature: -3,
        apparentTemperature: -8,
        apparentTemperatureSource: 'APP_KMA_METHOD_FROM_FORECAST',
      }),
      snapshot(14, {
        temperature: 34,
        apparentTemperature: 36,
        apparentTemperatureSource: 'APP_KMA_METHOD_FROM_FORECAST',
      }),
    ];
    const facts = runWeatherRuleEngineForHourly(hourly);
    const messages = buildLifestyleMessages(
      runLifestyleWeatherEngine(facts, hourly),
      facts,
      hourly,
      '수원',
    );
    const descriptions = messages.flatMap((message) =>
      message.parts.map((part) => part.text),
    );

    expect(descriptions).not.toContain('쌀쌀하게 느껴질 수 있어요.');
    expect(descriptions).not.toContain('많이 덥게 느껴질 수 있어요.');
  });
});

function threeDescriptions(
  type: LifestyleInsightType,
  hourly: WeatherSnapshot,
): string[] {
  return [0, 1, 2].map((score) => {
    const messages = buildLifestyleMessages(
      [{ type, score, sourceFacts: [] }],
      [],
      [hourly],
      '수원',
    );
    return messages[0].description ?? '';
  });
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
