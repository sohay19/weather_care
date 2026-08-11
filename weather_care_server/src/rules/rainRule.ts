import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';

export function applyRainRule(snapshot: WeatherSnapshot, config: RuleConfig): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [];
  const p = snapshot.precipitationProbability ?? 0;
  if (p >= config.rain.minProbability) {
    facts.push({
      type: WeatherRuleFactType.RAIN_LIKELY,
      severity: Math.min(100, Math.round(p)),
      evidence: { precipitationProbability: p },
      validFrom: snapshot.observedAt,
    });
  }
  if (p >= config.rain.heavyThreshold) {
    facts.push({
      type: WeatherRuleFactType.HEAVY_RAIN,
      severity: Math.min(100, Math.round(p)),
      evidence: { precipitationProbability: p, precipitationAmount: snapshot.precipitationAmount ?? 0 },
    });
  }
  return facts;
}

