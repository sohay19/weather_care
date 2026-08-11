import { LifestyleInsight, WeatherRuleFact, WeatherRuleFactType, LifestyleInsightType } from '../types';

export function deriveInsightFromRules(facts: WeatherRuleFact[]): LifestyleInsight[] {
  const has = (type: WeatherRuleFactType) => facts.some((f) => f.type === type);
  const score = (type: WeatherRuleFactType) => facts.find((f) => f.type === type)?.severity ?? 0;

  const result: LifestyleInsight[] = [];
  if (has(WeatherRuleFactType.UV_HIGH) && has(WeatherRuleFactType.TEMPERATURE_HIGH)) {
    result.push({
      type: LifestyleInsightType.STRONG_SUN_EXPOSURE,
      score: Math.max(score(WeatherRuleFactType.UV_HIGH), score(WeatherRuleFactType.TEMPERATURE_HIGH)),
      sourceFacts: [WeatherRuleFactType.UV_HIGH, WeatherRuleFactType.TEMPERATURE_HIGH],
      context: { reason: 'UV and heat combined' },
    });
  }
  if (has(WeatherRuleFactType.UV_HIGH)) {
    result.push({
      type: LifestyleInsightType.SUNSCREEN_USEFUL,
      score: score(WeatherRuleFactType.UV_HIGH),
      sourceFacts: [WeatherRuleFactType.UV_HIGH],
    });
  }
  if (has(WeatherRuleFactType.PM10_HIGH) || has(WeatherRuleFactType.PM25_HIGH)) {
    result.push({
      type: LifestyleInsightType.MASK_USEFUL,
      score: Math.max(score(WeatherRuleFactType.PM10_HIGH), score(WeatherRuleFactType.PM25_HIGH)),
      sourceFacts: [WeatherRuleFactType.PM10_HIGH, WeatherRuleFactType.PM25_HIGH],
    });
  }
  return result;
}

export function enrichAdditionalInsights(facts: WeatherRuleFact[]): LifestyleInsight[] {
  const extra: LifestyleInsight[] = [];
  const has = (type: WeatherRuleFactType) => facts.some((f) => f.type === type);
  const pick = (type: WeatherRuleFactType) => facts.find((f) => f.type === type)?.severity ?? 0;

  if (has(WeatherRuleFactType.TEMPERATURE_LOW) || has(WeatherRuleFactType.WIND_CHILL_HIGH)) {
    extra.push({
      type: LifestyleInsightType.OUTERWEAR_USEFUL,
      score: Math.max(pick(WeatherRuleFactType.TEMPERATURE_LOW), pick(WeatherRuleFactType.WIND_CHILL_HIGH)),
      sourceFacts: [WeatherRuleFactType.TEMPERATURE_LOW, WeatherRuleFactType.WIND_CHILL_HIGH],
      context: { reason: 'Cold or wind chill' },
    });
  }

  if (has(WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH) && has(WeatherRuleFactType.LARGE_DIURNAL_RANGE)) {
    extra.push({
      type: LifestyleInsightType.HYDRATION_IMPORTANT,
      score: Math.max(pick(WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH), pick(WeatherRuleFactType.LARGE_DIURNAL_RANGE)),
      sourceFacts: [WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH, WeatherRuleFactType.LARGE_DIURNAL_RANGE],
    });
  }

  if (has(WeatherRuleFactType.HEAVY_SNOW) || has(WeatherRuleFactType.SNOW_LIKELY)) {
    extra.push({
      type: LifestyleInsightType.SNOW_TRAVEL_CAUTION,
      score: Math.max(pick(WeatherRuleFactType.HEAVY_SNOW), pick(WeatherRuleFactType.SNOW_LIKELY)),
      sourceFacts: [WeatherRuleFactType.HEAVY_SNOW, WeatherRuleFactType.SNOW_LIKELY],
    });
  }

  if (has(WeatherRuleFactType.LAUNDRY_DRYING_GOOD)) {
    extra.push({
      type: LifestyleInsightType.LAUNDRY_GOOD,
      score: pick(WeatherRuleFactType.LAUNDRY_DRYING_GOOD),
      sourceFacts: [WeatherRuleFactType.LAUNDRY_DRYING_GOOD],
    });
  }

  if (has(WeatherRuleFactType.RAIN_LIKELY) || has(WeatherRuleFactType.HEAVY_RAIN)) {
    extra.push({
      type: LifestyleInsightType.RAIN_GEAR_USEFUL,
      score: Math.max(pick(WeatherRuleFactType.RAIN_LIKELY), pick(WeatherRuleFactType.HEAVY_RAIN)),
      sourceFacts: [WeatherRuleFactType.RAIN_LIKELY, WeatherRuleFactType.HEAVY_RAIN],
    });
  }
  return extra;
}
