import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';
import { amountMinimum } from './timeWindows';
import { precipitationDecisionSnapshot, precipitationStart, precipitationEnd } from './precipitationWindows';

export function applyRainRule(snapshot: WeatherSnapshot, config: RuleConfig): WeatherRuleFact[] {
  snapshot = precipitationDecisionSnapshot(snapshot);
  const facts: WeatherRuleFact[] = [];
  const probability = snapshot.precipitationProbability;
  const amount = amountMinimum(
    snapshot.precipitationAmountRange,
    snapshot.precipitationAmount,
  );
  if (
    (probability ?? 0) >= config.rain.minProbability ||
    amount >= config.rain.minAmount
  ) {
    facts.push({
      type: WeatherRuleFactType.RAIN_LIKELY,
      severity: Math.min(
        89,
        Math.max(Math.round(probability ?? 0), Math.round(amount * 10)),
      ),
      evidence: {
        precipitationProbability: probability ?? 0,
        precipitationAmountMinimum: amount,
        precipitationType: snapshot.precipitationType ?? 'NONE',
      },
      validFrom: precipitationStart(snapshot),
      validUntil: precipitationEnd(snapshot),
    });
  }
  if (
    amount >= config.rain.instantHeavyAmount ||
    ((probability ?? 0) >= config.rain.heavyProbability &&
      amount >= config.rain.heavyAmount)
  ) {
    facts.push({
      type: WeatherRuleFactType.HEAVY_RAIN,
      severity: Math.min(100, Math.max(90, Math.round(amount * 3))),
      evidence: {
        precipitationProbability: probability ?? 0,
        precipitationAmountMinimum: amount,
      },
      validFrom: precipitationStart(snapshot),
      validUntil: precipitationEnd(snapshot),
    });
  }
  return facts;
}
