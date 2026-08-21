import { describe, expect, it } from 'vitest';
import {
  buildWeatherBrief,
  buildWeatherBriefResult,
  DIRECT_WEATHER_EXPRESSION_PATTERN,
} from '../src/presentation/weatherBrief';
import {
  WEATHER_BRIEF_SLOT_OPTIONS,
  WEATHER_BRIEF_TEMPLATES,
} from '../src/presentation/weatherBriefCatalog';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../src/types';

describe('weather brief catalog', () => {
  it('contains exactly 20 complete templates', () => {
    expect(WEATHER_BRIEF_TEMPLATES).toHaveLength(20);
    expect(
      new Set(WEATHER_BRIEF_TEMPLATES.map((template) => template.id)).size,
    ).toBe(20);
    expect(
      new Set(WEATHER_BRIEF_TEMPLATES.map((template) => template.scene)),
    ).toEqual(
      new Set([
        'WET_TRAVEL',
        'CAREFUL_STEPS',
        'MASK_READY',
        'SHADE_BREAK',
        'LAYER_READY',
        'STEADY_PACE',
        'DAILY_RHYTHM',
      ]),
    );

    for (const template of WEATHER_BRIEF_TEMPLATES) {
      const placeholders = Array.from(
        template.text.matchAll(/\{([a-zA-Z]+)\}/g),
        (match) => match[1],
      );
      expect(placeholders.sort()).toEqual([...template.slots].sort());
      expect(template.slots).toHaveLength(3);
    }
  });

  it('provides exactly 10 unique replacements for every slot', () => {
    for (const options of Object.values(WEATHER_BRIEF_SLOT_OPTIONS)) {
      expect(options).toHaveLength(10);
      expect(new Set(options).size).toBe(10);
      expect(options.every((option) => option.trim().length > 0)).toBe(true);
    }
  });

  it('keeps direct weather facts out of every template and slot', () => {
    for (const template of WEATHER_BRIEF_TEMPLATES) {
      expect(template.text).not.toMatch(DIRECT_WEATHER_EXPRESSION_PATTERN);
    }
    for (const options of Object.values(WEATHER_BRIEF_SLOT_OPTIONS)) {
      for (const option of options) {
        expect(option).not.toMatch(DIRECT_WEATHER_EXPRESSION_PATTERN);
      }
    }
  });

  it('keeps even the longest slot combination within 47 characters', () => {
    for (const template of WEATHER_BRIEF_TEMPLATES) {
      let rendered = template.text;
      for (const slot of template.slots) {
        const longest = [...WEATHER_BRIEF_SLOT_OPTIONS[slot]].sort(
          (left, right) => right.length - left.length,
        )[0];
        rendered = rendered.replaceAll(`{${slot}}`, longest);
      }
      expect(rendered.length, template.id).toBeLessThanOrEqual(47);
    }
  });

  it('describes upcoming rain indirectly with an umbrella scene', () => {
    const result = buildWeatherBriefResult(
      forecast([
        snapshot(12),
        snapshot(18, {
          precipitationType: 'RAIN',
          precipitationProbability: 70,
        }),
      ]),
      { regionKey: '60:121' },
    );

    expect(result.scene).toBe('WET_TRAVEL');
    expect(result.slots.eventTime).toBe('퇴근길');
    expect(result.text).toContain('우산');
    expect(result.text).not.toMatch(DIRECT_WEATHER_EXPRESSION_PATTERN);
    expect(result.text).not.toMatch(/\{[^}]+\}/);
  });

  it('selects the matching indirect scene for each important condition', () => {
    const scenarios: [WeatherForecast, string][] = [
      [
        forecast([
          snapshot(7, {
            precipitationType: 'SNOW',
            snowExpected: true,
          }),
        ]),
        'CAREFUL_STEPS',
      ],
      [forecast([snapshot(12)], { pm25: 50 }), 'MASK_READY'],
      [
        forecast([snapshot(14, { apparentTemperature: 31 })]),
        'SHADE_BREAK',
      ],
      [
        forecast([snapshot(6, { apparentTemperature: 4 })]),
        'LAYER_READY',
      ],
      [forecast([snapshot(15, { windSpeed: 8 })]), 'STEADY_PACE'],
      [forecast([snapshot(12)]), 'DAILY_RHYTHM'],
    ];

    for (const [input, scene] of scenarios) {
      const result = buildWeatherBriefResult(input, {
        regionKey: '60:121',
      });
      expect(result.scene).toBe(scene);
      expect(result.text).not.toMatch(DIRECT_WEATHER_EXPRESSION_PATTERN);
      expect(result.text).not.toMatch(/\{[^}]+\}/);
    }
  });

  it('keeps the same brief for the same date, region and scene', () => {
    const input = forecast([
      snapshot(18, {
        precipitationType: 'RAIN',
        precipitationProbability: 70,
      }),
    ]);
    const context = { regionKey: '60:121' };

    expect(buildWeatherBrief(input, context)).toBe(
      buildWeatherBrief(input, context),
    );
  });

  it('does not repeat the same sentence during a seven-day rotation', () => {
    const input = forecast([
      snapshot(18, {
        precipitationType: 'RAIN',
        precipitationProbability: 70,
      }),
    ]);
    const briefs = Array.from({ length: 7 }, (_, index) =>
      buildWeatherBrief(input, {
        regionKey: '60:121',
        dateKey: `202608${String(21 + index).padStart(2, '0')}`,
      }),
    );

    expect(new Set(briefs).size).toBe(7);
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
