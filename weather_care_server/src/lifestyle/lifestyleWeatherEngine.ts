import { WeatherRuleFact, LifestyleInsight } from '../types';
import { deriveInsightFromRules, enrichAdditionalInsights } from './lifestyleBuilder';

export function runLifestyleWeatherEngine(facts: WeatherRuleFact[]): LifestyleInsight[] {
  const insights = [...deriveInsightFromRules(facts), ...enrichAdditionalInsights(facts)];
  const map = new Map<string, LifestyleInsight>();
  for (const item of insights) {
    const key = item.type;
    if (!map.has(key) || (map.get(key)?.score ?? 0) < item.score) {
      map.set(key, item);
    }
  }
  return Array.from(map.values()).sort((a, b) => b.score - a.score);
}

