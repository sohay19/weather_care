import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';
import { snapshotTime } from './timeWindows';

export function applyColdRule(snapshot: WeatherSnapshot, config: RuleConfig): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [];
  const temp = snapshot.temperature;
  const apparent = snapshot.apparentTemperature;
  if (
    (temp !== undefined && temp <= config.cold.temperature) ||
    (apparent !== undefined && apparent <= config.cold.apparentTemperature)
  ) {
    facts.push({
      type: WeatherRuleFactType.TEMPERATURE_LOW,
      severity: Math.max(40, 100 - Math.round(apparent ?? temp ?? 0)),
      evidence: {
        temperature: temp ?? 0,
        apparentTemperature: apparent ?? temp ?? 0,
      },
      validFrom: snapshotTime(snapshot),
      validUntil: snapshot.validTo,
    });
  }
  const apparentGap =
    temp !== undefined && apparent !== undefined ? temp - apparent : 0;
  if (
    apparentGap >= config.cold.apparentGap ||
    ((temp ?? Infinity) <= config.cold.temperature &&
      (snapshot.windSpeed ?? 0) >= config.wind.caution)
  ) {
    facts.push({
      type: WeatherRuleFactType.WIND_CHILL_HIGH,
      severity: Math.min(100, Math.max(50, Math.round(apparentGap * 12))),
      evidence: {
        windSpeed: snapshot.windSpeed ?? 0,
        apparentTemperature: apparent ?? temp ?? 0,
        apparentTemperatureGap: apparentGap,
      },
      validFrom: snapshotTime(snapshot),
      validUntil: snapshot.validTo,
    });
    facts.push({
      type: WeatherRuleFactType.COLD_STRESS_RISK,
      severity: Math.min(100, Math.max(50, Math.round(apparentGap * 12))),
      evidence: {
        windSpeed: snapshot.windSpeed ?? 0,
        apparentTemperatureGap: apparentGap,
      },
      validFrom: snapshotTime(snapshot),
      validUntil: snapshot.validTo,
    });
  }
  if ((snapshot.windSpeed ?? 0) >= config.wind.caution) {
    facts.push({
      type: WeatherRuleFactType.STRONG_WIND,
      severity:
        (snapshot.windSpeed ?? 0) >= config.wind.high
          ? 90
          : Math.min(89, Math.round((snapshot.windSpeed ?? 0) * 10)),
      evidence: { windSpeed: snapshot.windSpeed ?? 0 },
      validFrom: snapshotTime(snapshot),
      validUntil: snapshot.validTo,
    });
  }
  return facts;
}
