import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';

export function applyColdRule(snapshot: WeatherSnapshot, config: RuleConfig): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [];
  const temp = snapshot.temperature;
  if (temp !== undefined && temp <= config.cold.temperature) {
    facts.push({
      type: WeatherRuleFactType.TEMPERATURE_LOW,
      severity: Math.max(0, 100 - Math.round(temp)),
      evidence: { temperature: temp },
      validFrom: snapshot.observedAt,
    });
  }
  if ((snapshot.windSpeed ?? 0) >= config.cold.windChill) {
    facts.push({
      type: WeatherRuleFactType.WIND_CHILL_HIGH,
      severity: Math.round((snapshot.windSpeed ?? 0) * 10),
      evidence: { windSpeed: snapshot.windSpeed ?? 0, apparentTemperature: snapshot.apparentTemperature ?? temp ?? 0 },
    });
  }
  return facts;
}

