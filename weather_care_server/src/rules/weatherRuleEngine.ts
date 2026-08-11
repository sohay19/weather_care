import { RuleConfig, defaultRuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherSnapshot } from '../types';
import { applyRainRule } from './rainRule';
import { applySnowRule } from './snowRule';
import { applyUvRule } from './uvRule';
import { applyHeatRule } from './heatRule';
import { applyColdRule } from './coldRule';
import { applyAirQualityRule } from './airQualityRule';
import { applyLaundryRule } from './laundryRule';

export function runWeatherRuleEngine(snapshot: WeatherSnapshot, config: RuleConfig = defaultRuleConfig): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [
    ...applyRainRule(snapshot, config),
    ...applySnowRule(snapshot, config),
    ...applyUvRule(snapshot, config),
    ...applyHeatRule(snapshot, config),
    ...applyColdRule(snapshot, config),
    ...applyAirQualityRule(snapshot, config),
    ...applyLaundryRule(snapshot, config),
  ];
  return dedupeByType(facts);
}

function dedupeByType(facts: WeatherRuleFact[]): WeatherRuleFact[] {
  const map = new Map<string, WeatherRuleFact>();
  for (const f of facts) {
    const prev = map.get(f.type);
    if (!prev || f.severity > prev.severity) {
      map.set(f.type, f);
    }
  }
  return Array.from(map.values());
}

