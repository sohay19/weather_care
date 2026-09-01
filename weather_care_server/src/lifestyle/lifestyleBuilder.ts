import { LifestyleInsight, WeatherRuleFact, WeatherRuleFactType, LifestyleInsightType } from '../types';

export function deriveInsightFromRules(facts: WeatherRuleFact[]): LifestyleInsight[] {
  const has = (type: WeatherRuleFactType) => facts.some((f) => f.type === type);
  const score = (type: WeatherRuleFactType) => facts.find((f) => f.type === type)?.severity ?? 0;

  const result: LifestyleInsight[] = [];
  if (has(WeatherRuleFactType.UV_HIGH)) {
    result.push({
      type: LifestyleInsightType.STRONG_SUN_EXPOSURE,
      score: Math.max(score(WeatherRuleFactType.UV_HIGH), score(WeatherRuleFactType.TEMPERATURE_HIGH)),
      sourceFacts: [WeatherRuleFactType.UV_HIGH],
    });
  }
  if (has(WeatherRuleFactType.UV_HIGH)) {
    result.push({
      type: LifestyleInsightType.SUNSCREEN_USEFUL,
      score: score(WeatherRuleFactType.UV_HIGH),
      sourceFacts: [WeatherRuleFactType.UV_HIGH],
    });
  }
  if (
    has(WeatherRuleFactType.AIR_QUALITY_BAD) ||
    has(WeatherRuleFactType.PM10_HIGH) ||
    has(WeatherRuleFactType.PM25_HIGH)
  ) {
    result.push({
      type: LifestyleInsightType.MASK_USEFUL,
      score: Math.max(
        score(WeatherRuleFactType.AIR_QUALITY_BAD),
        score(WeatherRuleFactType.PM10_HIGH),
        score(WeatherRuleFactType.PM25_HIGH),
      ),
      sourceFacts: [
        WeatherRuleFactType.AIR_QUALITY_BAD,
        WeatherRuleFactType.PM10_HIGH,
        WeatherRuleFactType.PM25_HIGH,
      ],
    });
  }
  return result;
}

export function enrichAdditionalInsights(facts: WeatherRuleFact[]): LifestyleInsight[] {
  const extra: LifestyleInsight[] = [];
  const has = (type: WeatherRuleFactType) => facts.some((f) => f.type === type);
  const pick = (type: WeatherRuleFactType) => facts.find((f) => f.type === type)?.severity ?? 0;

  if (
    has(WeatherRuleFactType.TEMPERATURE_LOW) ||
    has(WeatherRuleFactType.COLD_STRESS_RISK)
  ) {
    extra.push({
      type: LifestyleInsightType.OUTERWEAR_USEFUL,
      score: Math.min(
        100,
        Math.max(
          pick(WeatherRuleFactType.TEMPERATURE_LOW),
          pick(WeatherRuleFactType.COLD_STRESS_RISK),
        ) + (has(WeatherRuleFactType.STRONG_WIND) ? 10 : 0),
      ),
      sourceFacts: [
        WeatherRuleFactType.TEMPERATURE_LOW,
        WeatherRuleFactType.COLD_STRESS_RISK,
        WeatherRuleFactType.STRONG_WIND,
      ],
      context: { reason: 'Cold or wind chill' },
    });
  }

  if (has(WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH)) {
    extra.push({
      type: LifestyleInsightType.HYDRATION_IMPORTANT,
      score: Math.min(
        100,
        pick(WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH) +
          (has(WeatherRuleFactType.HUMIDITY_HIGH) ? 10 : 0),
      ),
      sourceFacts: [
        WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH,
        WeatherRuleFactType.HUMIDITY_HIGH,
      ],
    });
  }

  if (
    has(WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH) &&
    has(WeatherRuleFactType.HUMIDITY_HIGH)
  ) {
    extra.push({
      type: LifestyleInsightType.VERY_HOT_AND_HUMID,
      score: Math.min(
        100,
        Math.max(
          pick(WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH),
          pick(WeatherRuleFactType.HUMIDITY_HIGH),
        ) + 10,
      ),
      sourceFacts: [
        WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH,
        WeatherRuleFactType.HUMIDITY_HIGH,
      ],
    });
  }

  if (has(WeatherRuleFactType.HEAVY_SNOW) || has(WeatherRuleFactType.SNOW_LIKELY)) {
    extra.push({
      type: LifestyleInsightType.SNOW_TRAVEL_CAUTION,
      score: Math.max(pick(WeatherRuleFactType.HEAVY_SNOW), pick(WeatherRuleFactType.SNOW_LIKELY)),
      sourceFacts: [WeatherRuleFactType.HEAVY_SNOW, WeatherRuleFactType.SNOW_LIKELY],
    });
  }

  if (has(WeatherRuleFactType.RAIN_LIKELY) || has(WeatherRuleFactType.HEAVY_RAIN)) {
    extra.push({
      type: LifestyleInsightType.RAIN_GEAR_USEFUL,
      score: Math.max(pick(WeatherRuleFactType.RAIN_LIKELY), pick(WeatherRuleFactType.HEAVY_RAIN)),
      sourceFacts: [WeatherRuleFactType.RAIN_LIKELY, WeatherRuleFactType.HEAVY_RAIN],
    });
  }

  if (has(WeatherRuleFactType.LARGE_DIURNAL_RANGE)) {
    extra.push({
      type: LifestyleInsightType.LARGE_TEMPERATURE_SWING,
      score: pick(WeatherRuleFactType.LARGE_DIURNAL_RANGE),
      sourceFacts: [WeatherRuleFactType.LARGE_DIURNAL_RANGE],
    });
  }

  if (has(WeatherRuleFactType.STRONG_WIND)) {
    extra.push({
      type: LifestyleInsightType.OUTDOOR_ACTIVITY_CAUTION,
      score: pick(WeatherRuleFactType.STRONG_WIND),
      sourceFacts: [WeatherRuleFactType.STRONG_WIND],
    });
  }

  if (has(WeatherRuleFactType.RAPID_TEMPERATURE_DROP)) {
    extra.push({
      type: LifestyleInsightType.RAPID_TEMPERATURE_DROP,
      score: pick(WeatherRuleFactType.RAPID_TEMPERATURE_DROP),
      sourceFacts: [WeatherRuleFactType.RAPID_TEMPERATURE_DROP],
    });
  }
  if (has(WeatherRuleFactType.WARM_HUMID_NIGHT_FORECAST)) {
    extra.push({
      type: LifestyleInsightType.NIGHT_WEATHER_CHECK,
      score: pick(WeatherRuleFactType.WARM_HUMID_NIGHT_FORECAST),
      sourceFacts: [WeatherRuleFactType.WARM_HUMID_NIGHT_FORECAST],
    });
  }
  return extra;
}
