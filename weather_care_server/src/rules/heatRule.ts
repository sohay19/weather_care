import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';

export function applyHeatRule(snapshot: WeatherSnapshot, config: RuleConfig): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [];
  const apparent = snapshot.apparentTemperature ?? -999;
  if (snapshot.temperature !== undefined && snapshot.temperature >= config.heat.apparentTemperature) {
    facts.push({
      type: WeatherRuleFactType.TEMPERATURE_HIGH,
      severity: Math.min(100, Math.round(snapshot.temperature)),
      evidence: { temperature: snapshot.temperature },
      validFrom: snapshot.observedAt,
    });
  }
  if (apparent >= config.heat.apparentTemperature) {
    facts.push({
      type: WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH,
      severity: Math.min(100, Math.round(apparent)),
      evidence: { apparentTemperature: apparent },
    });
  }
  return facts;
}

