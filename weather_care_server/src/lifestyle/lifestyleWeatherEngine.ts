import { WeatherRuleFact, LifestyleInsight, WeatherSnapshot } from '../types';
import { deriveInsightFromRules, enrichAdditionalInsights } from './lifestyleBuilder';
import { enrichTimeSeriesInsights } from './timeSeriesLifestyleBuilder';

export function runLifestyleWeatherEngine(
  facts: WeatherRuleFact[],
  hourly: WeatherSnapshot[] = [],
): LifestyleInsight[] {
  const insights = [
    ...deriveInsightFromRules(facts),
    ...enrichAdditionalInsights(facts),
    ...enrichTimeSeriesInsights(hourly),
  ];
  const map = new Map<string, LifestyleInsight>();
  for (const item of insights) {
    const availableSourceFactTypes = item.sourceFacts.filter((type) =>
      facts.some((fact) => fact.type === type),
    );
    const sourceFacts = facts.filter((fact) =>
      availableSourceFactTypes.includes(fact.type),
    );
    const enriched = {
      ...item,
      sourceFacts: availableSourceFactTypes,
      context: {
        ...item.context,
        validFrom:
          item.context?.validFrom ??
          sourceFacts.map((fact) => fact.validFrom).find(Boolean),
        validUntil:
          item.context?.validUntil ??
          sourceFacts.map((fact) => fact.validUntil).find(Boolean),
      },
    };
    const key = item.type;
    if (!map.has(key) || (map.get(key)?.score ?? 0) < enriched.score) {
      map.set(key, enriched);
    }
  }
  return Array.from(map.values()).sort((a, b) => b.score - a.score);
}
