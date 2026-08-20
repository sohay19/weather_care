import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';
import {
  isDayWindow,
  isKnownNoAmount,
  snapshotTime,
} from './timeWindows';

export function applyLaundryRule(snapshot: WeatherSnapshot, config: RuleConfig): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [];
  const hasRequiredInputs =
    snapshot.precipitationProbability !== undefined &&
    snapshot.humidity !== undefined &&
    snapshot.windSpeed !== undefined &&
    (snapshot.precipitationAmountRange !== undefined ||
      snapshot.precipitationAmount !== undefined);
  const score =
    hasRequiredInputs &&
    isDayWindow(snapshot) &&
    (snapshot.precipitationProbability ?? 100) <
      config.laundry.maxProbability &&
    isKnownNoAmount(
      snapshot.precipitationAmountRange,
      snapshot.precipitationAmount,
    ) &&
    (snapshot.humidity ?? 100) <= config.laundry.maxHumidity &&
    (snapshot.windSpeed ?? 0) >= config.laundry.minWind &&
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
        windSpeed: snapshot.windSpeed ?? 0,
      },
      validFrom: snapshotTime(snapshot),
      validUntil: snapshot.validTo,
    });
  }

  if (
    snapshot.minTemperature !== undefined &&
    snapshot.maxTemperature !== undefined
  ) {
    const swing = snapshot.maxTemperature - snapshot.minTemperature;
    if (swing >= config.cold.diurnalRange) {
      facts.push({
        type: WeatherRuleFactType.LARGE_DIURNAL_RANGE,
        severity: Math.min(100, Math.round(swing)),
        evidence: {
          minTemperature: snapshot.minTemperature,
          maxTemperature: snapshot.maxTemperature,
          dailyTemperatureRange: swing,
        },
      });
    }
  }
  return facts;
}
