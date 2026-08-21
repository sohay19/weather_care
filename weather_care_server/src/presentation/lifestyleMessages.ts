import { lifestyleMessageFor } from '../lifestyle/lifestyleTemplates';
import {
  LifestyleInsight,
  LifestyleInsightType,
  TodayWeatherResponse,
} from '../types';

const fallbackTodoTypes = [
  LifestyleInsightType.DAILY_WEATHER_CHECK,
  LifestyleInsightType.FLEXIBLE_DAY_PLAN,
  LifestyleInsightType.DAILY_HYDRATION,
];

export function buildLifestyleMessages(
  insights: LifestyleInsight[],
): TodayWeatherResponse['lifestyleMessages'] {
  const messages = insights.map((item) => ({
    type: item.type,
    score: item.score,
    ...lifestyleMessageFor(item.type, item.score, item.context),
  }));

  for (const type of fallbackTodoTypes) {
    if (messages.length >= 3) break;
    if (messages.some((message) => message.type === type)) continue;
    messages.push({
      type,
      score: 0,
      ...lifestyleMessageFor(type),
    });
  }
  return messages;
}
