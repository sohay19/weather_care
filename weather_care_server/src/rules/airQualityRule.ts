import { RuleConfig } from '../config/ruleConfig';
import { WeatherRuleFact, WeatherRuleFactType, WeatherSnapshot } from '../types';

export function applyAirQualityRule(
  snapshot: WeatherSnapshot,
  config: RuleConfig,
): WeatherRuleFact[] {
  const facts: WeatherRuleFact[] = [];
  const pm10 = snapshot.pm10 ?? 0;
  const pm25 = snapshot.pm25 ?? 0;
  const ozone = snapshot.ozone;
  const gradeBad = config.airQuality.gradeBad.includes(
    snapshot.airQualityGrade ?? '',
  );
  const ozoneGradeBad = config.airQuality.gradeBad.includes(
    snapshot.ozoneGrade ?? '',
  );

  if (gradeBad || pm10 >= config.airQuality.pm10) {
    facts.push({
      type: WeatherRuleFactType.AIR_QUALITY_BAD,
      severity: Math.min(100, Math.round(pm10 + pm25)),
      evidence: { pm10, pm25, airQualityGrade: snapshot.airQualityGrade ?? '' },
      validFrom: snapshot.observedAt,
    });
  }
  if (pm10 >= config.airQuality.pm10) {
    facts.push({
      type: WeatherRuleFactType.PM10_HIGH,
      severity: Math.min(100, Math.round(pm10)),
      evidence: { pm10 },
    });
  }
  if (pm25 >= config.airQuality.pm25) {
    facts.push({
      type: WeatherRuleFactType.PM25_HIGH,
      severity: Math.min(100, Math.round(pm25)),
      evidence: { pm25 },
    });
  }
  if (
    ozoneGradeBad ||
    (ozone !== undefined && ozone >= config.airQuality.ozone)
  ) {
    facts.push({
      type: WeatherRuleFactType.OZONE_HIGH,
      severity:
        ozoneGradeBad && snapshot.ozoneGrade === 'Very Bad'
          ? 95
          : Math.min(
              94,
              Math.max(70, Math.round((ozone ?? 0.091) * 1_000)),
            ),
      evidence: {
        ozone: ozone ?? '',
        ozoneGrade: snapshot.ozoneGrade ?? '',
      },
      validFrom: snapshot.airQualityObservedAt ?? snapshot.observedAt,
    });
  }
  return facts;
}
