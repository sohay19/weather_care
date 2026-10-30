import type { WeatherForecast } from '../providers/weather/weatherProvider';
import { preparationsForWindow } from '../recommendations/preparationPolicy';
import { descriptionFor } from '../recommendations/recommendationTemplates';
import { LifestyleInsightType, type TodayWeatherResponse } from '../types';

/** 실외 건조도와 실내 관리 제안을 분리한다. 실내 상태는 추정하지 않는다. */
export function buildDrynessMessages(
  forecast: WeatherForecast,
  now: Date,
): TodayWeatherResponse['lifestyleMessages'] {
  const preparation = preparationsForWindow(forecast, now, { drynessPreparations: true })
    .find((item) => item.reason === 'humidity');
  if (!preparation) return [];
  const label = preparation.type === 'PORTABLE_HUMIDIFIER' ? '매우 건조'
    : preparation.type === 'HAND_CREAM' ? '건조' : '약한 건조';
  const management = '실내 습도도 확인하고, 낮다면 가습기 사용을 고려하세요. 실내 습도를 30~50%로 관리하고 과도한 가습은 피하세요.';
  return [{
    type: LifestyleInsightType.DRYNESS_GUIDANCE,
    title: `건조도 · ${label}`,
    description: management,
    priority: preparation.type === 'PORTABLE_HUMIDIFIER' ? 70 : 44,
    parts: [
      { role: 'APP_SUGGESTION', text: descriptionFor(preparation.type, []), source: '날씨챙겨' },
      ...preparation.evidence,
      { role: 'APP_SUGGESTION', text: management, source: '날씨챙겨 · 실내 관리 안내' },
    ],
  }];
}
