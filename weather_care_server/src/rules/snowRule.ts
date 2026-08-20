import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';
import { amountMinimum, snapshotTime } from './timeWindows';

export function applySnowRule(snapshot: WeatherSnapshot, config: RuleConfig): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [];
  const amount = amountMinimum(
    snapshot.snowfallAmountRange,
    snapshot.snowfallAmount,
  );
  const expected =
    snapshot.precipitationType === 'SNOW' ||
    snapshot.precipitationType === 'RAIN_SNOW' ||
    amount > config.snow.minAmount;
  if (expected) {
    facts.push({
      type: WeatherRuleFactType.SNOW_LIKELY,
      severity: Math.min(
        89,
        Math.max(50, Math.round((snapshot.precipitationProbability ?? 0))),
      ),
      evidence: {
        precipitationType: snapshot.precipitationType ?? 'NONE',
        snowfallAmountMinimum: amount,
      },
      validFrom: snapshotTime(snapshot),
      validUntil: snapshot.validTo,
    });
  }
  if (amount >= config.snow.heavyHourlyAmount) {
    facts.push({
      type: WeatherRuleFactType.HEAVY_SNOW,
      severity: Math.min(100, Math.max(95, Math.round(amount * 5))),
      evidence: {
        precipitationType: snapshot.precipitationType ?? 'NONE',
        snowfallAmountMinimum: amount,
      },
      validFrom: snapshotTime(snapshot),
      validUntil: snapshot.validTo,
    });
  }
  return facts;
}
