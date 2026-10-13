import { describe, expect, it } from 'vitest';
import { preparationsForSnapshots } from '../src/recommendations/preparationPolicy';
import type { WeatherSnapshot } from '../src/types';

const snapshot = (changes: Partial<WeatherSnapshot>): WeatherSnapshot => ({
  observedAt: '2026-10-13T12:00:00+09:00',
  ...changes,
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
