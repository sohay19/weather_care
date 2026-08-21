import { describe, expect, it } from 'vitest';
import { runLifestyleWeatherEngine } from '../src/lifestyle/lifestyleWeatherEngine';
import { lifestyleMessageFor } from '../src/lifestyle/lifestyleTemplates';
import { runWeatherRuleEngineForHourly } from '../src/rules/weatherRuleEngine';
import { runRecommendationEngine } from '../src/recommendations/recommendationEngine';
import { buildLifestyleMessages } from '../src/presentation/lifestyleMessages';
import {
  AmountRange,
  LifestyleInsight,
  LifestyleInsightType,
  WeatherSnapshot,
} from '../src/types';

describe('Lifestyle v1.1 catalog', () => {
  it('derives a commute weather change and selects the matching message', () => {
    const hourly = [
      snapshot(8),
      snapshot(18, { precipitationProbability: 70, precipitationType: 'RAIN' }),
      snapshot(19, { precipitationProbability: 70, precipitationType: 'RAIN' }),
    ];
    const facts = runWeatherRuleEngineForHourly(hourly);
    const insights = runLifestyleWeatherEngine(facts, hourly);
    const commute = insights.find(
      (item) => item.type === LifestyleInsightType.COMMUTE_WEATHER_CHANGE,
    );

    expect(commute?.context?.messageContext).toBe('RAIN');
    expect(
      lifestyleMessageFor(commute!.type, commute!.score, commute!.context).title,
    ).toContain('퇴근 무렵 비');

    const umbrella = runRecommendationEngine(insights).find(
      (item) => item.type === 'UMBRELLA',
    );
    expect(umbrella).toEqual(
      expect.objectContaining({
        decisionVersion: 'weather-rules-1.1.0',
        catalogVersion: 'ko-KR-2026.08.2',
        reasonCodes: expect.arrayContaining(['RAIN_LIKELY']),
        sourceFields: expect.arrayContaining(['precipitationType']),
      }),
    );
  });

  it('renders time placeholders and never exposes an empty placeholder', () => {
    const rendered = lifestyleMessageFor(
      LifestyleInsightType.RAIN_BREAK_WINDOW,
      0,
      { validFrom: '오후 2시', validTo: '오후 4시' },
    );
    expect(rendered.description).toBe(
      '오후 2시부터 오후 4시까지 이동하기 좋아요.',
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
    expect(insights.map((item) => item.type)).not.toContain(
      LifestyleInsightType.VENTILATION_WINDOW,
    );
  });

  it('keeps server TODO messages at a minimum of three', () => {
    const insights: LifestyleInsight[] = [
      {
        type: LifestyleInsightType.RAIN_GEAR_USEFUL,
        score: 90,
        sourceFacts: [],
      },
    ];

    const messages = buildLifestyleMessages(insights);

    expect(messages).toHaveLength(3);
    expect(messages[0].type).toBe(LifestyleInsightType.RAIN_GEAR_USEFUL);
    expect(messages[0].score).toBe(90);
    expect(messages.slice(1).every((message) => message.score === 0)).toBe(true);
    expect(messages.every((message) => message.title.length > 0)).toBe(true);
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
