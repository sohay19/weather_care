import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';

export function applyUvRule(snapshot: WeatherSnapshot, config: RuleConfig): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [];
  const uv = snapshot.uvIndex ?? 0;
  if (uv >= config.uv.highThreshold) {
    facts.push({
      type: WeatherRuleFactType.UV_HIGH,
      severity: Math.min(100, Math.round(uv * 10)),
      evidence: { uvIndex: uv },
      validFrom: snapshot.observedAt,
    });
  }
  return facts;
}

