import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';

export function applyLaundryRule(snapshot: WeatherSnapshot, config: RuleConfig): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [];
  const score =
    (snapshot.precipitationProbability ?? 0) <= config.laundry.maxPrecipitation &&
    (snapshot.humidity ?? 100) <= config.laundry.maxHumidity &&
    (snapshot.uvIndex ?? 0) >= config.laundry.minSun &&
    (snapshot.windSpeed ?? 0) <= config.laundry.maxWind
      ? 80
      : 20;

  if (score >= 60) {
    facts.push({
      type: WeatherRuleFactType.LAUNDRY_DRYING_GOOD,
      severity: score,
      evidence: {
        precipitationProbability: snapshot.precipitationProbability ?? 0,
        humidity: snapshot.humidity ?? 0,
        uvIndex: snapshot.uvIndex ?? 0,
        windSpeed: snapshot.windSpeed ?? 0,
      },
    });
  }

  if (snapshot.apparentTemperature !== undefined && snapshot.temperature !== undefined) {
    const swing = Math.abs(snapshot.temperature - snapshot.apparentTemperature);
    if (swing >= config.cold.diurnalRange) {
      facts.push({
        type: WeatherRuleFactType.LARGE_DIURNAL_RANGE,
        severity: Math.min(100, Math.round(swing)),
        evidence: { temperature: snapshot.temperature, apparentTemperature: snapshot.apparentTemperature },
      });
    }
  }
  return facts;
}

