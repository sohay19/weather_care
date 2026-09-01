import { lifestyleMessageFor } from '../lifestyle/lifestyleTemplates';
import { LifestyleInsight, TodayWeatherResponse } from '../types';

export function buildLifestyleMessages(
  insights: LifestyleInsight[],
): TodayWeatherResponse['lifestyleMessages'] {
  return insights.map((item) => ({
    type: item.type,
    score: item.score,
    ...lifestyleMessageFor(item.type, item.score, item.context),
  }));
}
