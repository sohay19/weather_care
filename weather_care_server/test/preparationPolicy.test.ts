import { describe, expect, it } from 'vitest';
import { preparationsForSnapshots, preparationsForWindow } from '../src/recommendations/preparationPolicy';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../src/types';

const snapshot = (changes: Partial<WeatherSnapshot>): WeatherSnapshot => ({
  observedAt: '2026-10-13T12:00:00+09:00',
  ...changes,
});

describe('오늘 남은 하루 준비물', () => {
  const now = new Date('2026-10-13T07:00:00+09:00');
  const at = (hour: number, changes: Partial<WeatherSnapshot> = {}) => snapshot({
    observedAt: `2026-10-13T${String(hour).padStart(2, '0')}:00:00+09:00`,
    dataRole: 'FORECAST', ...changes,
  });
  const forecast = (hourly: WeatherSnapshot[]): WeatherForecast => ({
    current: at(7), hourly, daily: [], baseDate: '20261013', baseTime: '0500', dataSource: '검증 자료',
  });
  const rain = { precipitationType: 'RAIN', precipitationAmount: 15 } as const;
  const selected = (hourly: WeatherSnapshot[]) => preparationsForWindow(forecast(hourly), now)
    .slice(0, 3).map((item) => item.type);

  it('항목이 하나면 그 항목의 물품 3개, 둘이면 2개와 1개, 셋이면 하나씩 배분한다', () => {
    expect(selected([at(18, rain)])).toEqual(['UMBRELLA', 'RAIN_BOOTS', 'RAINCOAT']);
    expect(selected([at(18, { ...rain, temperature: 0 })]))
      .toEqual(['UMBRELLA', 'HAND_WARMER', 'RAIN_BOOTS']);
    expect(selected([at(18, { ...rain, temperature: 0, pm25: 40 })]))
      .toEqual(['UMBRELLA', 'HAND_WARMER', 'MASK']);
  });

  it('아침에 저녁 비를 포함하고 실제 강수 구간 시작부터 종료까지 전달한다', () => {
    const input = forecast([at(19, { ...rain, precipitationPeriod: {
      start: '2026-10-13T18:00:00+09:00', end: '2026-10-13T19:00:00+09:00',
    } })]);
    expect(preparationsForWindow(input, now)[0]).toMatchObject({
      type: 'UMBRELLA', validFrom: '2026-10-13T09:00:00.000Z', validUntil: '2026-10-13T10:00:00.000Z',
    });
    expect(preparationsForWindow(input, new Date('2026-10-13T18:59:59+09:00')).length).toBeGreaterThan(0);
    expect(preparationsForWindow(input, new Date('2026-10-13T19:00:00+09:00'))).toEqual([]);
  });

  it('세 항목을 넘으면 강수와 강한 위험을 먼저 표시하고 약한 위험은 뒤에 둔다', () => {
    expect(selected([at(18, rain), at(12, { temperature: 33, pm25: 40 }), at(22, { temperature: 16 })]))
      .toEqual(['UMBRELLA', 'PORTABLE_FAN', 'MASK']);
  });

  it('눈에도 우산을 우선하고 눈길 대비 물품을 남는 칸에 배치한다', () => {
    expect(selected([at(18, { precipitationType: 'SNOW', snowfallAmount: 5 })]))
      .toEqual(['UMBRELLA', 'SNOW_CHAINS', 'WINTER_BOOTS']);
  });

  it('오늘 마지막 강수 구간은 포함하고 내일만 필요한 물품과 종료된 관측은 제외한다', () => {
    const midnight = '2026-10-14T00:00:00+09:00';
    const input = forecast([
      snapshot({ observedAt: midnight, forecastAt: midnight, ...rain,
        precipitationPeriod: { start: '2026-10-13T23:00:00+09:00', end: midnight },
        temperature: 0 }),
      snapshot({ observedAt: '2026-10-14T01:00:00+09:00', pm25: 40 }),
    ]);
    expect(selected(input.hourly)).toEqual(['UMBRELLA', 'RAIN_BOOTS', 'RAINCOAT']);
    expect(preparationsForWindow(input, now)[0].validUntil).toBe('2026-10-13T15:00:00.000Z');
    input.current = at(7, { dataRole: 'OBSERVATION', temperature: 0 });
    expect(preparationsForWindow(input, new Date('2026-10-13T08:00:00+09:00'))
      .map((item) => item.type)).not.toContain('HAND_WARMER');
  });

  it('일몰 뒤 UV를 제거하고 남은 낮은 단계로 다시 추천한다', () => {
    const input = forecast([at(15, { temperature: 0 }), at(18, { temperature: 15, uvIndex: 8 })]);
    expect(preparationsForWindow(input, new Date('2026-10-13T17:00:00+09:00')).map((item) => item.type))
      .toContain('LIGHT_OUTERWEAR');
    expect(preparationsForWindow(input, new Date('2026-10-13T18:30:00+09:00'), {
      sunsetAt: '2026-10-13T18:30:00+09:00',
    }).map((item) => item.type)).toEqual(['LIGHT_OUTERWEAR']);
  });

  it('꺼 둔 항목을 제외한 뒤 남은 칸을 배분한다', () => {
    expect(preparationsForWindow(forecast([at(18, { ...rain, temperature: 0 })]), now, {
      allowedRecommendedItems: ['OUTERWEAR', 'HAND_WARMER', 'SCARF'],
    }).map((item) => item.type)).toEqual(['HAND_WARMER', 'OUTERWEAR', 'SCARF']);
  });
});
const types = (changes: Partial<WeatherSnapshot>) =>
  preparationsForSnapshots([snapshot(changes)]).map((item) => item.type);

describe('강도별 준비물', () => {
  it('비와 자외선 단계가 올라가면 준비물이 누적된다', () => {
    expect(types({ precipitationType: 'RAIN', precipitationAmount: 1 }))
      .toEqual(['UMBRELLA']);
    expect(types({ precipitationType: 'RAIN', precipitationAmount: 5 }))
      .toEqual(['UMBRELLA', 'RAINCOAT']);
    expect(types({ precipitationType: 'RAIN', precipitationAmount: 15 }))
      .toEqual(['UMBRELLA', 'RAINCOAT', 'RAIN_BOOTS']);
    expect(types({ uvIndex: 3 })).toEqual(['SUNSCREEN']);
    expect(types({ uvIndex: 6 })).toEqual(['SUNSCREEN', 'SUNGLASSES', 'SUN_HAT']);
    expect(types({ uvIndex: 8 })).toEqual(['SUNSCREEN', 'SUNGLASSES', 'PARASOL']);
    expect(types({ uvIndex: 8, windSpeed: 10 }))
      .toEqual(['SUNSCREEN', 'SUNGLASSES', 'SUN_HAT']);
  });

  it('더위와 추위는 단계별 추가와 겉옷 교체를 적용한다', () => {
    expect(types({ temperature: 26 })).toEqual(['WATER']);
    expect(types({ temperature: 30 })).toEqual(['WATER', 'COOLING_ITEM']);
    expect(types({ temperature: 33 }))
      .toEqual(['WATER', 'COOLING_ITEM', 'PORTABLE_FAN']);
    expect(types({ temperature: 17 })).toEqual(['LIGHT_OUTERWEAR']);
    expect(types({ temperature: 10 })).toEqual(['OUTERWEAR']);
    expect(types({ temperature: 0 }))
      .toEqual(['OUTERWEAR', 'SCARF', 'HAND_WARMER']);
  });

  it('추가 준비물은 그 강도가 시작되는 시각을 보존한다', () => {
    const items = preparationsForSnapshots([
      snapshot({ precipitationType: 'RAIN', precipitationAmount: 1 }),
      snapshot({
        observedAt: '2026-10-13T14:00:00+09:00',
        precipitationType: 'RAIN', precipitationAmount: 15,
      }),
    ]);
    expect(items.find((item) => item.type === 'UMBRELLA')?.validFrom)
      .toBe('2026-10-13T03:00:00.000Z');
    expect(items.find((item) => item.type === 'RAIN_BOOTS')?.validFrom)
      .toBe('2026-10-13T05:00:00.000Z');
  });

  it('눈 단계와 비 중복 시 신발을 통합하고, 오존만 높으면 마스크를 권하지 않는다', () => {
    expect(types({ precipitationType: 'SNOW' }))
      .toEqual(['SLIP_RESISTANT_SHOES']);
    expect(types({ precipitationType: 'SNOW', snowfallAmount: 1 }))
      .toEqual(['WINTER_BOOTS']);
    expect(types({ precipitationType: 'SNOW', snowfallAmount: 5 }))
      .toEqual(['WINTER_BOOTS', 'SNOW_CHAINS']);
    const mixed = types({
      precipitationType: 'RAIN_SNOW', precipitationAmount: 15,
      snowfallAmount: 5, pm25: 40, uvIndex: 8,
    });
    expect(mixed.slice(0, 4)).toEqual([
      'WINTER_BOOTS', 'UMBRELLA', 'SUNSCREEN', 'MASK',
    ]);
    expect(mixed).not.toContain('RAIN_BOOTS');
    expect(mixed).not.toContain('PARASOL');
    expect(types({ ozone: 0.12, airQualityGrade: 'Bad' })).toEqual([]);
    expect(types({ pm25: 40 })).toEqual(['MASK']);
    expect(types({ pm25ForecastGrade: '나쁨' })).toEqual(['MASK']);
  });
});
