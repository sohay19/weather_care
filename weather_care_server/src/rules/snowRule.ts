import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';

export function applySnowRule(snapshot: WeatherSnapshot, config: RuleConfig): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [];
  const p = snapshot.snowProbability ?? 0;
  if (p >= config.snow.minProbability) {
    facts.push({
      type: WeatherRuleFactType.SNOW_LIKELY,
      severity: Math.min(100, Math.round(p)),
      evidence: { snowProbability: p },
      validFrom: snapshot.observedAt,
    });
  }
  if (p >= config.snow.heavyThreshold) {
    facts.push({
      type: WeatherRuleFactType.HEAVY_SNOW,
      severity: Math.min(100, Math.round(p)),
      evidence: { snowProbability: p, snowfallAmount: snapshot.snowfallAmount ?? 0 },
    });
  }
  return facts;
}

