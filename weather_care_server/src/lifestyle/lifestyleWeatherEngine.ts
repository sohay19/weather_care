import { WeatherRuleFact, LifestyleInsight, WeatherSnapshot } from '../types';
import { deriveInsightFromRules, enrichAdditionalInsights } from './lifestyleBuilder';
import { enrichTimeSeriesInsights } from './timeSeriesLifestyleBuilder';
import { pollenEvidence } from '../services/livingIndexAdvice';
import { LifestyleInsightType } from '../types';

export function runLifestyleWeatherEngine(
  facts: WeatherRuleFact[],
  hourly: WeatherSnapshot[] = [],
  now?: Date,
): LifestyleInsight[] {
  const insights = [
    ...deriveInsightFromRules(facts),
    ...enrichAdditionalInsights(facts),
    ...enrichTimeSeriesInsights(hourly, now),
  ];
  const map = new Map<string, LifestyleInsight>();
  for (const item of insights) {
    const availableSourceFactTypes = item.sourceFacts.filter((type) =>
      facts.some((fact) => fact.type === type),
    );
    const sourceFacts = facts.filter((fact) =>
      availableSourceFactTypes.includes(fact.type),
    ).sort((a, b) => b.severity - a.severity);
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
  const pollen = hourly.map(pollenEvidence).find((parts) => parts.length > 0);
  if (pollen) {
    const existing = map.get(LifestyleInsightType.MASK_USEFUL);
    map.set(LifestyleInsightType.MASK_USEFUL, {
      type: LifestyleInsightType.MASK_USEFUL, score: Math.max(existing?.score ?? 0, 75),
      sourceFacts: existing?.sourceFacts ?? [],
      context: { ...existing?.context, pollenEvidence: pollen,
        messageContext: existing ? 'AIR_AND_POLLEN' : 'POLLEN',
        validFrom: pollen[0].validFrom, validUntil: pollen[0].validUntil },
    });
  }
  return Array.from(map.values()).sort((a, b) => b.score - a.score);
}
