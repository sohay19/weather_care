import {
  LifestyleInsight,
  LifestyleInsightType,
  WeatherRuleFact,
  WeatherRuleFactType,
  WeatherSnapshot,
} from '../types';
import {
  findRuns,
  isCommuteWindow,
  isKnownNoAmount,
  isWetSnapshot,
  localHour,
  snapshotEnd,
  snapshotTime,
  sortSnapshots,
} from '../rules/timeWindows';

export function enrichTimeSeriesInsights(
  facts: WeatherRuleFact[],
  hourly: WeatherSnapshot[],
): LifestyleInsight[] {
  const snapshots = sortSnapshots(hourly);
  if (snapshots.length === 0) return [];

  const insights: LifestyleInsight[] = [];
  addCommuteInsights(insights, snapshots, facts);
  addRainWindowInsights(insights, snapshots);
  addIndoorInsights(insights, snapshots, facts);
  addSeasonalInsights(insights, snapshots);
  addCompleteInputPositiveWindows(insights, snapshots, facts);
  return insights;
}

function addCommuteInsights(
  insights: LifestyleInsight[],
  snapshots: WeatherSnapshot[],
  facts: WeatherRuleFact[],
): void {
  const morning = snapshots.filter((item) => {
    const hour = localHour(item);
    return hour >= 5 && hour <= 9;
  });
  const evening = snapshots.filter((item) => {
    const hour = localHour(item);
    return hour >= 17 && hour <= 20;
  });
  if (morning.length > 0 && evening.length > 0) {
    const morningWet = morning.some(isWetSnapshot);
    const eveningWet = evening.some(isWetSnapshot);
    const morningTemperature = averageTemperature(morning);
    const eveningTemperature = averageTemperature(evening);
    if (!morningWet && eveningWet) {
      insights.push({
        type: LifestyleInsightType.COMMUTE_WEATHER_CHANGE,
        score: 85,
        sourceFacts: [WeatherRuleFactType.RAIN_LIKELY],
        context: {
          messageContext: 'RAIN',
          validFrom: snapshotTime(evening.find(isWetSnapshot) ?? evening[0]),
        },
      });
    } else if (
      morningTemperature !== undefined &&
      eveningTemperature !== undefined &&
      eveningTemperature <= morningTemperature - 4
    ) {
      insights.push({
        type: LifestyleInsightType.COMMUTE_WEATHER_CHANGE,
        score: 75,
        sourceFacts: [WeatherRuleFactType.RAPID_TEMPERATURE_DROP],
        context: { messageContext: 'COLD' },
      });
    }
  }

  const riskyCommute = snapshots.find(
    (item) =>
      isCommuteWindow(item) &&
      isWetSnapshot(item) &&
      (item.windSpeed ?? 0) >= 6,
  );
  const icyFact = facts.find(
    (fact) => fact.type === WeatherRuleFactType.ICY_ROAD_RISK,
  );
  if (riskyCommute || icyFact) {
    insights.push({
      type: LifestyleInsightType.COMMUTE_RISK,
      score: icyFact ? 95 : 85,
      sourceFacts: [
        WeatherRuleFactType.RAIN_LIKELY,
        WeatherRuleFactType.STRONG_WIND,
        WeatherRuleFactType.ICY_ROAD_RISK,
      ],
      context: {
        messageContext: icyFact ? 'ICY' : 'RAIN_WIND',
        validFrom: riskyCommute
          ? snapshotTime(riskyCommute)
          : icyFact?.validFrom,
      },
    });
  }
}

function addRainWindowInsights(
  insights: LifestyleInsight[],
  snapshots: WeatherSnapshot[],
): void {
  const dryRuns = findRuns(
    snapshots,
    (item) =>
      item.precipitationType === 'NONE' &&
      (item.precipitationProbability ?? 100) < 30 &&
      isKnownNoAmount(
        item.precipitationAmountRange,
        item.precipitationAmount,
      ),
    2,
  );
  const rainBreak = dryRuns.find((run) => {
    const firstIndex = snapshots.indexOf(run[0]);
    const lastIndex = snapshots.indexOf(run.at(-1) ?? run[0]);
    return (
      snapshots.slice(0, firstIndex).some(isWetSnapshot) &&
      snapshots.slice(lastIndex + 1).some(isWetSnapshot)
    );
  });
  if (rainBreak) {
    insights.push({
      type: LifestyleInsightType.RAIN_BREAK_WINDOW,
      score: 60,
      sourceFacts: [WeatherRuleFactType.RAIN_LIKELY],
      context: {
        validFrom: formatTime(snapshotTime(rainBreak[0])),
        validTo: formatTime(snapshotEnd(rainBreak.at(-1) ?? rainBreak[0])),
      },
    });
  }

  const wetIndex = snapshots.findIndex(isWetSnapshot);
  if (wetIndex >= 0) {
    insights.push({
      type: LifestyleInsightType.CAR_WASH_SCORE,
      score: 55,
      sourceFacts: [WeatherRuleFactType.RAIN_LIKELY],
      context: { messageContext: 'POSTPONE' },
    });
  }

  const firstDryAfterRain = snapshots.findIndex(
    (item, index) =>
      index > 0 &&
      isWetSnapshot(snapshots[index - 1]) &&
      item.precipitationType === 'NONE' &&
      isKnownNoAmount(
        item.precipitationAmountRange,
        item.precipitationAmount,
      ),
  );
  if (firstDryAfterRain >= 0) {
    const dry = snapshots[firstDryAfterRain];
    insights.push({
      type: LifestyleInsightType.WET_ROAD_CAUTION,
      score: 70,
      sourceFacts: [WeatherRuleFactType.RAIN_LIKELY],
      context: { validFrom: snapshotTime(dry) },
    });
  }
}

function addIndoorInsights(
  insights: LifestyleInsight[],
  snapshots: WeatherSnapshot[],
  facts: WeatherRuleFact[],
): void {
  const indoorDryingRun = findRuns(
    snapshots,
    (item) => isWetSnapshot(item) && (item.humidity ?? -Infinity) >= 75,
    3,
  )[0];
  if (indoorDryingRun) {
    insights.push({
      type: LifestyleInsightType.INDOOR_DRYING_PREFERRED,
      score: 65,
      sourceFacts: [
        WeatherRuleFactType.RAIN_LIKELY,
        WeatherRuleFactType.HUMIDITY_HIGH,
      ],
      context: {
        validFrom: snapshotTime(indoorDryingRun[0]),
        validTo: snapshotEnd(indoorDryingRun.at(-1) ?? indoorDryingRun[0]),
      },
    });
  }

  const startTime = Date.parse(snapshotTime(snapshots[0]));
  const nearbyRiskIndex = snapshots.findIndex((item) => {
    const leadTime = Date.parse(snapshotTime(item)) - startTime;
    return (
      leadTime >= 0 &&
      leadTime <= 2 * 60 * 60 * 1000 &&
      (isWetSnapshot(item) || (item.windSpeed ?? 0) >= 9)
    );
  });
  if (nearbyRiskIndex >= 0) {
    const risk = snapshots[nearbyRiskIndex];
    const minutesUntil = Math.max(
      0,
      Math.round(
        (Date.parse(snapshotTime(risk)) - Date.parse(snapshotTime(snapshots[0]))) /
          60000,
      ),
    );
    insights.push({
      type: LifestyleInsightType.WINDOW_CLOSE_SOON,
      score: 80,
      sourceFacts: [
        WeatherRuleFactType.RAIN_LIKELY,
        WeatherRuleFactType.STRONG_WIND,
      ],
      context: {
        minutesUntil,
        actionDeadline: formatTime(
          new Date(Date.parse(snapshotTime(risk)) - 30 * 60 * 1000).toISOString(),
        ),
      },
    });
  }

  const highHumidity = facts.find(
    (fact) => fact.type === WeatherRuleFactType.HUMIDITY_HIGH,
  );
  if (highHumidity) {
    insights.push({
      type: LifestyleInsightType.DEHUMIDIFIER_USEFUL,
      score: highHumidity.severity,
      sourceFacts: [WeatherRuleFactType.HUMIDITY_HIGH],
      context: {
        validFrom: highHumidity.validFrom,
        validTo: highHumidity.validUntil,
      },
    });
  }
  const lowHumidity = facts.find(
    (fact) => fact.type === WeatherRuleFactType.HUMIDITY_LOW,
  );
  if (lowHumidity) {
    insights.push({
      type: LifestyleInsightType.HUMIDIFIER_USEFUL,
      score: lowHumidity.severity,
      sourceFacts: [WeatherRuleFactType.HUMIDITY_LOW],
      context: {
        validFrom: lowHumidity.validFrom,
        validTo: lowHumidity.validUntil,
      },
    });
  }
}

function addSeasonalInsights(
  insights: LifestyleInsight[],
  snapshots: WeatherSnapshot[],
): void {
  const frost = snapshots.find((item, index) => {
    const hour = localHour(item);
    const priorWet = snapshots
      .slice(Math.max(0, index - 6), index)
      .some(isWetSnapshot);
    return (
      hour >= 5 &&
      hour <= 9 &&
      (item.temperature ?? Infinity) <= 0 &&
      ((item.humidity ?? 0) >= 80 || priorWet)
    );
  });
  if (frost) {
    insights.push({
      type: LifestyleInsightType.VEHICLE_FROST_RISK,
      score: 75,
      sourceFacts: [WeatherRuleFactType.TEMPERATURE_LOW],
      context: { validFrom: snapshotTime(frost) },
    });
  }
}

function addCompleteInputPositiveWindows(
  insights: LifestyleInsight[],
  snapshots: WeatherSnapshot[],
  facts: WeatherRuleFact[],
): void {
  const ventilation = facts.find(
    (fact) => fact.type === WeatherRuleFactType.VENTILATION_GOOD,
  );
  if (ventilation?.validFrom && ventilation.validUntil) {
    const durationMinutes = Math.max(
      10,
      Math.round(
        (Date.parse(ventilation.validUntil) - Date.parse(ventilation.validFrom)) /
          60000,
      ),
    );
    insights.push({
      type: LifestyleInsightType.VENTILATION_WINDOW,
      score: ventilation.severity + 1,
      sourceFacts: [WeatherRuleFactType.VENTILATION_GOOD],
      context: {
        durationMinutes,
        validTo: formatTime(ventilation.validUntil),
      },
    });
  }

  const outingRuns = findRuns(
    snapshots,
    (item) => {
      const allRequired =
        item.apparentTemperature !== undefined &&
        item.uvIndex !== undefined &&
        item.windSpeed !== undefined &&
        item.precipitationProbability !== undefined &&
        (item.precipitationAmountRange !== undefined ||
          item.precipitationAmount !== undefined) &&
        (item.airQualityGrade !== undefined || item.pm10 !== undefined) &&
        (item.ozone !== undefined || item.ozoneGrade !== undefined);
      if (!allRequired) return false;
      return (
        !isWetSnapshot(item) &&
        (item.apparentTemperature ?? Infinity) >= 10 &&
        (item.apparentTemperature ?? -Infinity) <= 30 &&
        (item.uvIndex ?? Infinity) < 6 &&
        (item.windSpeed ?? Infinity) >= 1 &&
        (item.windSpeed ?? Infinity) <= 5 &&
        !['Bad', 'Very Bad', '나쁨', '매우 나쁨'].includes(
          item.airQualityGrade ?? '',
        ) &&
        !['Bad', 'Very Bad', '나쁨', '매우 나쁨'].includes(
          item.ozoneGrade ?? '',
        ) &&
        (item.activeWarnings?.length ?? 0) === 0
      );
    },
    2,
  );
  const best = outingRuns[0];
  if (best) {
    insights.push({
      type: LifestyleInsightType.BEST_OUTING_WINDOW,
      score: 55,
      sourceFacts: [],
      context: {
        timeLabel: `${formatTime(snapshotTime(best[0]))}~${formatTime(
          snapshotEnd(best.at(-1) ?? best[0]),
        )}`,
      },
    });
  }
}

function averageTemperature(
  snapshots: WeatherSnapshot[],
): number | undefined {
  const values = snapshots
    .map((item) => item.temperature)
    .filter((value): value is number => value !== undefined);
  if (values.length === 0) return undefined;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

function formatTime(iso: string): string {
  const hasOffset = /[+-]\d{2}:\d{2}$/.test(iso);
  const local = hasOffset
    ? iso.slice(11, 16)
    : new Date(Date.parse(iso) + 9 * 60 * 60 * 1000)
        .toISOString()
        .slice(11, 16);
  const hour = Number(local.slice(0, 2));
  const minute = Number(local.slice(3, 5));
  const period = hour < 12 ? '오전' : '오후';
  const hour12 = hour % 12 || 12;
  return `${period} ${hour12}시${minute === 0 ? '' : ` ${minute}분`}`;
}
