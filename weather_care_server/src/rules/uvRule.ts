import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';
import { isDayWindow, snapshotTime } from './timeWindows';

export function applyUvRule(snapshot: WeatherSnapshot, config: RuleConfig): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [];
  const uv = snapshot.uvIndex ?? 0;
  if (isDayWindow(snapshot) && uv >= config.uv.highThreshold) {
    facts.push({
      type: WeatherRuleFactType.UV_HIGH,
      severity: Math.min(100, Math.round(uv * 10)),
      evidence: { uvIndex: uv },
      validFrom: snapshotTime(snapshot),
      validUntil: snapshot.validTo,
    });
  }
  return facts;
}
