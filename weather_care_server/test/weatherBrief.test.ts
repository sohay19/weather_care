import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  buildWeatherBrief,
  buildWeatherBriefResult,
} from '../src/presentation/weatherBrief';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../src/types';

describe('Canonical Briefing Intent v2', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-08-21T06:00:00+09:00'));
  });
  afterEach(() => vi.useRealTimers());

  it('비 scene의 short/medium/long과 알림이 같은 대상·행동을 유지한다', () => {
    const result = buildWeatherBriefResult(
      forecast([
        snapshot(16, {
          precipitationType: 'RAIN',
          precipitationProbability: 70,
          precipitationPeriod: {
            start: '2026-08-21T15:00:00+09:00',
            end: '2026-08-21T16:00:00+09:00',
          },
        }),
        snapshot(17, {
          precipitationType: 'RAIN',
          precipitationProbability: 70,
          precipitationPeriod: {
            start: '2026-08-21T16:00:00+09:00',
            end: '2026-08-21T17:00:00+09:00',
          },
        }),
      ]),
      { regionKey: '57/125' },
    );

    expect(result.intent).toMatchObject({
      locationKey: '57/125',
      sceneId: 'RAIN',
      action: 'TAKE_UMBRELLA',
      recommendedItems: ['UMBRELLA'],
      targetFrom: '2026-08-21T06:00:00.000Z',
      targetUntil: '2026-08-21T08:00:00.000Z',
    });
    for (const text of [
      result.intent.copy.short,
      result.intent.copy.medium,
      result.intent.copy.long,
      result.intent.copy.notificationBody,
    ]) {
      expect(text).toContain('비');
      expect(text).toContain('우산');
    }
    expect(result.text).toBe(result.intent.copy.medium);
    expect(result.timeline[0].sceneId).toBe('RAIN');
  });

  it('소나기 코드에서만 공식 용어 소나기를 쓴다', () => {
    const shower = buildWeatherBriefResult(forecast([
      snapshot(15, {
        precipitationType: 'SHOWER',
        precipitationProbability: 60,
      }),
    ]));
    const rain = buildWeatherBriefResult(forecast([
      snapshot(15, { precipitationProbability: 60 }),
    ]));

    expect(shower.intent.copy.medium).toContain('소나기');
    expect(rain.intent.copy.medium).toContain('비');
    expect(rain.intent.copy.medium).not.toContain('소나기');
  });

  it('일몰 전에는 UV, 일몰 후에는 다음 유효 scene을 선택한다', () => {
    const input = forecast([
      snapshot(18, {
        uvIndex: 7,
        validTo: '2026-08-21T19:00:00+09:00',
      }),
    ]);
    const sun = {
      sunriseAt: '2026-08-21T05:50:00+09:00',
      sunsetAt: '2026-08-21T18:47:00+09:00',
    };

    const before = buildWeatherBriefResult(input, {
      ...sun,
      now: new Date('2026-08-21T18:40:00+09:00'),
    });
    const after = buildWeatherBriefResult(input, {
      ...sun,
      now: new Date('2026-08-21T18:48:00+09:00'),
    });

    expect(before.scene).toBe('UV');
    expect(before.intent.validUntil).toBe('2026-08-21T09:47:00.000Z');
    expect(after.scene).toBe('THERMAL_COMFORTABLE');
    expect(after.text).not.toMatch(/자외선|선크림|양산|햇볕/);
  });

  it('위젯 timeline은 앱을 열지 않아도 일몰 경계에서 UV를 교체할 수 있다', () => {
    const result = buildWeatherBriefResult(
      forecast([
        snapshot(18, {
          uvIndex: 7,
          validTo: '2026-08-21T20:00:00+09:00',
        }),
      ]),
      {
        now: new Date('2026-08-21T18:40:00+09:00'),
        sunsetAt: '2026-08-21T18:47:00+09:00',
      },
    );

    expect(result.timeline[0]).toMatchObject({
      sceneId: 'UV',
      validUntil: '2026-08-21T09:47:00.000Z',
    });
    expect(result.timeline[1]).toMatchObject({
      sceneId: 'THERMAL_COMFORTABLE',
      validFrom: '2026-08-21T09:47:00.000Z',
    });
  });

  it('종료된 비 scene을 다시 사용하지 않는다', () => {
    const input = forecast([
      snapshot(15, {
        precipitationType: 'RAIN',
        precipitationPeriod: {
          start: '2026-08-21T14:00:00+09:00',
          end: '2026-08-21T15:00:00+09:00',
        },
      }),
      snapshot(16, {
        precipitationType: 'RAIN',
        precipitationPeriod: {
          start: '2026-08-21T15:00:00+09:00',
          end: '2026-08-21T16:00:00+09:00',
        },
      }),
      snapshot(17, {
        precipitationType: 'RAIN',
        precipitationPeriod: {
          start: '2026-08-21T16:00:00+09:00',
          end: '2026-08-21T17:00:00+09:00',
        },
      }),
    ]);

    const active = buildWeatherBriefResult(input, {
      now: new Date('2026-08-21T16:00:00+09:00'),
    });
    const ended = buildWeatherBriefResult(input, {
      now: new Date('2026-08-21T17:20:00+09:00'),
    });

    expect(active.scene).toBe('RAIN');
    expect(active.text).toContain('우산');
    expect(ended.scene).not.toBe('RAIN');
    expect(ended.text).not.toContain('우산');
  });

  it('관측값은 예보로 표현하지 않고 30분만 유효하다', () => {
    const observed = snapshot(14, {
      dataRole: 'OBSERVATION',
      forecastAt: undefined,
      observedAt: '2026-08-21T14:00:00+09:00',
      validTo: '2026-08-21T14:59:59+09:00',
      precipitationType: 'RAIN',
    });
    const input = { ...forecast([]), current: observed };
    const current = buildWeatherBriefResult(input, {
      now: new Date('2026-08-21T14:10:00+09:00'),
    });
    const stale = buildWeatherBriefResult(input, {
      now: new Date('2026-08-21T14:31:00+09:00'),
    });

    expect(current.intent).toMatchObject({
      scope: 'CURRENT',
      dataRole: 'OBSERVATION',
      observedAt: '2026-08-21T14:00:00+09:00',
      forecastAt: undefined,
      targetUntil: '2026-08-21T05:30:00.000Z',
    });
    expect(current.text).toContain('지금 비가 내리고 있어요');
    expect(stale.scene).not.toBe('RAIN');
    expect(stale.text).not.toContain('후텁지근');
  });

  it('오늘 범위 밖의 내일·모레 자료를 대표 브리핑으로 쓰지 않는다', () => {
    const sample = {
      ...snapshot(10, { uvIndex: 7 }),
      forecastAt: '2026-08-23T10:00:00+09:00',
      observedAt: '2026-08-23T10:00:00+09:00',
    };
    const result = buildWeatherBriefResult(forecast([sample]), {
      now: new Date('2026-08-21T20:00:00+09:00'),
    });

    expect(result.scene).toBe('DEFAULT');
    expect(result.text).not.toMatch(/내일|모레/);
  });

  it('입력을 변경하지 않고 같은 입력에 같은 intent를 만든다', () => {
    const input = forecast([
      snapshot(15, {
        precipitationType: 'RAIN',
        precipitationProbability: 70,
      }),
    ]);
    const original = JSON.stringify(input);

    expect(buildWeatherBrief(input)).toBe(buildWeatherBrief(input));
    expect(JSON.stringify(input)).toBe(original);
  });

  it('완성 문장에 금지된 시각·인과 표현이 없다', () => {
    const result = buildWeatherBriefResult(forecast([
      snapshot(15, { apparentTemperature: 33, uvIndex: 7 }),
    ]));
    const copies = Object.values(result.intent.copy).join(' ');

    expect(copies).not.toMatch(/오후\s+(1[3-9]|2[0-3])시|현재 지금|0\.1℃ 높지만|자외선 때문에 기온/);
  });

  it('확장 카탈로그에서는 현재 scene 준비물을 같은 기준으로 제공한다', () => {
    const result = buildWeatherBriefResult(forecast([
      snapshot(15, {
        precipitationType: 'RAIN',
        precipitationProbability: 70,
      }),
    ]), {
      expandedPreparations: true,
      allowedRecommendedItems: ['UMBRELLA', 'RAINCOAT', 'RAIN_BOOTS'],
    });

    expect(result.intent.recommendedItems).toEqual([
      'UMBRELLA',
      'RAINCOAT',
      'RAIN_BOOTS',
    ]);
    expect(result.timeline[0].recommendedItems).toEqual(
      result.intent.recommendedItems,
    );
  });

  it('꺼 둔 준비물을 요구하는 scene과 문구를 선택하지 않는다', () => {
    const result = buildWeatherBriefResult(forecast([
      snapshot(15, {
        precipitationType: 'RAIN',
        precipitationProbability: 70,
      }),
    ]), {
      allowedRecommendedItems: ['WATER'],
    });

    expect(result.scene).not.toBe('RAIN');
    expect(result.intent.recommendedItems).not.toContain('UMBRELLA');
    expect(result.text).not.toContain('우산');
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
