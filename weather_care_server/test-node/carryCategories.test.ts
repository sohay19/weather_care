import { describe, expect, it } from 'vitest';
import { preparationsForWindow } from '../src/recommendations/preparationPolicy';
import { enabledRecommendationTypes } from '../src/recommendations/recommendationEngine';
import { buildWeatherBriefResult } from '../src/presentation/weatherBrief';
import { withWidgetSettings } from '../src/api/weather';
import { defaultNotificationSettings } from '../src/database/notificationSettingsRepository';
import type { NotificationSettings, WeatherSnapshot } from '../src/types';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';

const now = new Date('2026-10-30T09:00:00+09:00');
function forecast(values: Partial<WeatherSnapshot>): WeatherForecast {
  const current: WeatherSnapshot = { observedAt: now.toISOString(), forecastAt: now.toISOString(), dataRole: 'FORECAST', ...values };
  return { current, hourly: [current], daily: [], baseDate: '20261030', baseTime: '0800', dataSource: '합성 자료' };
}
function candidates(values: Partial<WeatherSnapshot>, settings: Partial<NotificationSettings>) {
  return preparationsForWindow(forecast(values), now, { preparationSettings: settings,
    allowedRecommendedItems: enabledRecommendationTypes(settings, true), drynessPreparations: true });
}
describe('챙겨요 항목별 준비물 제어', () => {
  it.each([
    ['umbrellaEnabled', { precipitationType: 'RAIN', precipitationProbability: 80, precipitationAmount: 20 }],
    ['snowPreparationEnabled', { precipitationType: 'SNOW', snowfallAmount: 6 }],
    ['outerwearEnabled', { temperature: -5 }],
    ['waterEnabled', { temperature: 34 }],
    ['uvPreparationEnabled', { uvIndex: 9 }],
    ['drynessEnabled', { humidity: 20 }],
  ] as const)('%s는 항목의 모든 준비물을 함께 제어한다', (field, values) => {
    expect(candidates(values, { [field]: true }).length).toBeGreaterThan(0);
    expect(candidates(values, { [field]: false })).toEqual([]);
  });

  it.each([[false, true, 'pollen'], [true, false, 'air'], [true, true, 'air+pollen']] as const)(
    '대기질 %s·꽃가루 %s는 마스크의 원인을 %s로 구분한다', (maskEnabled, pollenEnabled, reason) => {
      const input = { pm10: 150, pollenForecast: { date: '2026-10-30', risks: [{ species: '참나무', level: '높음', issuedAt: now.toISOString() }] } };
      const items = candidates(input, { maskEnabled, pollenEnabled });
      expect(items).toHaveLength(1);
      expect(items[0].reason).toBe(reason);
      expect(candidates(input, { maskEnabled: false, pollenEnabled: false })).toEqual([]);
    });

  it('자외선 ON은 예전 양산·선크림 OFF와 무관하게 관련 준비물을 허용한다', () => {
    const settings = { uvPreparationEnabled: true, parasolEnabled: false, sunscreenEnabled: false };
    expect(candidates({ uvIndex: 9 }, settings).map((item) => item.type)).toEqual(expect.arrayContaining(['SUNSCREEN', 'SUNGLASSES', 'PARASOL']));
  });

  it('비 OFF·눈 ON에서도 눈 대비 우산을 허용하고 대설특보 선택은 분리한다', () => {
    const settings = { umbrellaEnabled: false, snowPreparationEnabled: true, heavySnowEnabled: false };
    const items = candidates({ precipitationType: 'SNOW', snowfallAmount: 6 }, settings);
    expect(items.map((item) => item.type)).toContain('UMBRELLA');
    expect(items.map((item) => item.type)).toContain('SNOW_CHAINS');
    expect(items.every((item) => item.reason === 'snow')).toBe(true);
    expect(enabledRecommendationTypes(settings)).not.toContain('HEAVY_SNOW_CAUTION');
  });

  it('구 앱의 우산 ON·대설 OFF는 눈 대비 우산을 유지하고 새 눈 OFF는 적용한다', () => {
    const legacy = { umbrellaEnabled: true, heavySnowEnabled: false };
    const values = { precipitationType: 'SNOW' as const, snowfallAmount: 2 };
    expect(candidates(values, legacy).map((item) => item.type)).toEqual(['UMBRELLA']);
    expect(candidates(values, { ...legacy, snowPreparationEnabled: false })).toEqual([]);
  });

  it.each([[40, 'LIP_BALM'], [30, 'HAND_CREAM'], [20, 'PORTABLE_HUMIDIFIER']] as const)(
    '더위/물 OFF·건조도 ON·습도 %s에서 기본 문구 대신 건조 브리핑을 선택한다', (humidity, type) => {
      const settings = { waterEnabled: false, drynessEnabled: true };
      const brief = buildWeatherBriefResult(forecast({ humidity }), {
        now, tieredPreparations: true, drynessPreparations: true, preparationSettings: settings,
        allowedRecommendedItems: enabledRecommendationTypes(settings, true),
      });
      expect(brief.scene).toBe('HUMIDITY_LOW');
      expect(brief.intent.topic).toBe('건조도');
      expect(brief.intent.recommendedItems).toEqual([type]);
      expect(brief.text).not.toContain('특별한 예보');
      expect(brief.text).toContain('습도');
    });

  it('확장 위젯 선택값과 기존 형식 모두 기존 설정을 보존한다', () => {
    const settings = defaultNotificationSettings('test');
    expect(withWidgetSettings(settings, 'u0p0s0o0m0w0c0d1n1v1f1')).toMatchObject({
      snowPreparationEnabled: true, uvPreparationEnabled: true, pollenEnabled: true, umbrellaEnabled: false,
    });
    expect(withWidgetSettings({ ...settings, pollenEnabled: false }, 'u1p1s1o1m1w1c1').pollenEnabled).toBe(false);
  });
});
