import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';
import { snapshotTime } from './timeWindows';

export function applyHeatRule(snapshot: WeatherSnapshot, config: RuleConfig): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [];
  const apparent = snapshot.apparentTemperature ?? -999;
  if (
    snapshot.temperature !== undefined &&
    snapshot.temperature >= config.heat.actionAirTemperature
  ) {
    facts.push({
      type: WeatherRuleFactType.TEMPERATURE_HIGH,
      severity: Math.min(100, Math.round(snapshot.temperature)),
      evidence: { temperature: snapshot.temperature },
      validFrom: snapshotTime(snapshot),
      validUntil: snapshot.validTo,
    });
  }
  if (apparent >= config.heat.actionApparentTemperature) {
    facts.push({
      type: WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH,
      severity: Math.min(100, Math.round(apparent)),
      evidence: { apparentTemperature: apparent },
      validFrom: snapshotTime(snapshot),
      validUntil: snapshot.validTo,
    });
  }
  if ((snapshot.humidity ?? 0) >= config.humidity.high) {
    facts.push({
      type: WeatherRuleFactType.HUMIDITY_HIGH,
      severity: Math.round(snapshot.humidity ?? 0),
      evidence: { humidity: snapshot.humidity ?? 0 },
      validFrom: snapshotTime(snapshot),
      validUntil: snapshot.validTo,
    });
  }
  if (
    snapshot.humidity !== undefined &&
    snapshot.humidity <= config.humidity.low
  ) {
    facts.push({
      type: WeatherRuleFactType.HUMIDITY_LOW,
      severity: Math.max(40, 100 - Math.round(snapshot.humidity)),
      evidence: { humidity: snapshot.humidity },
      validFrom: snapshotTime(snapshot),
      validUntil: snapshot.validTo,
    });
  }
  return facts;
}
