import {
  LifestyleInsight,
  LifestyleInsightType,
  WeatherRuleFactType,
  WeatherSnapshot,
} from '../types';
import {
  findRuns,
  isKnownNoAmount,
  isWetSnapshot,
  snapshotEnd,
  snapshotTime,
  sortSnapshots,
} from '../rules/timeWindows';
import { precipitationAtPoint, precipitationDecisionSnapshot, precipitationStart,
  precipitationEnd, periodLabel } from '../rules/precipitationWindows';

export function enrichTimeSeriesInsights(
  hourly: WeatherSnapshot[],
  now?: Date,
): LifestyleInsight[] {
  const snapshots = sortSnapshots(hourly).map((item) => precipitationDecisionSnapshot(item, now));
  if (snapshots.length === 0) return [];

  const insights: LifestyleInsight[] = [];
  addRainWindowInsights(insights, snapshots);
  addConditionalHouseholdActions(insights, snapshots, now);
  addCompleteInputPositiveWindows(insights, snapshots);
  return insights;
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
        validFrom: precipitationStart(rainBreak[0]),
        validUntil: precipitationEnd(rainBreak.at(-1) ?? rainBreak[0]),
        timeLabel: periodLabel(precipitationStart(rainBreak[0]),
          exclusiveEnd(precipitationEnd(rainBreak.at(-1) ?? rainBreak[0]))),
      },
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
      context: { validFrom: precipitationStart(dry), validUntil: precipitationEnd(dry) },
    });
  }
}

function addConditionalHouseholdActions(
  insights: LifestyleInsight[],
  snapshots: WeatherSnapshot[],
  now?: Date,
): void {
  const reference = now?.getTime() ?? Date.parse(snapshots[0].fetchedAt ?? '');
  const firstTime = Number.isFinite(reference) ? reference : Date.parse(precipitationStart(snapshots[0]));
  const riskStart = (item: WeatherSnapshot) => isWetSnapshot(item) ? precipitationStart(item) : snapshotTime(item);
  const firstOutdoorRisk = [...snapshots].sort((a, b) => Date.parse(riskStart(a)) - Date.parse(riskStart(b))).find((item) => {
    const leadTime = Date.parse(riskStart(item)) - firstTime;
    return (
      leadTime >= -60 * 60 * 1000 &&
      leadTime <= 24 * 60 * 60 * 1000 &&
      (isWetSnapshot(item) || (item.windSpeed ?? 0) >= 9)
    );
  });
  if (!firstOutdoorRisk) return;

  const riskTime = Date.parse(riskStart(firstOutdoorRisk));
  const actionNow = riskTime - 30 * 60 * 1000 <= firstTime;
  const actionDeadline = formatTime(
    new Date(riskTime - 30 * 60 * 1000).toISOString(),
  );
  insights.push({
    type: LifestyleInsightType.LAUNDRY_PICKUP_DUE,
    score: 80,
    sourceFacts: sourceFactsForOutdoorRisk(firstOutdoorRisk),
    context: {
      actionDeadline,
      actionNow,
      groundingAt: snapshotTime(firstOutdoorRisk),
      validFrom: riskStart(firstOutdoorRisk),
      validUntil: isWetSnapshot(firstOutdoorRisk) ? precipitationEnd(firstOutdoorRisk) : snapshotEnd(firstOutdoorRisk),
      messageContext: outdoorRiskContext(firstOutdoorRisk),
    },
  });

  if (riskTime - firstTime <= 2 * 60 * 60 * 1000) {
    const minutesUntil = Math.max(
      0,
      Math.round((riskTime - firstTime) / 60_000),
    );
    insights.push({
      type: LifestyleInsightType.WINDOW_CLOSE_SOON,
      score: 80,
      sourceFacts: sourceFactsForOutdoorRisk(firstOutdoorRisk),
      context: {
        minutesUntil,
        actionDeadline,
        actionNow,
        groundingAt: snapshotTime(firstOutdoorRisk),
        validFrom: riskStart(firstOutdoorRisk),
        validUntil: isWetSnapshot(firstOutdoorRisk) ? precipitationEnd(firstOutdoorRisk) : snapshotEnd(firstOutdoorRisk),
        messageContext: outdoorRiskContext(firstOutdoorRisk),
      },
    });
  }
}

function sourceFactsForOutdoorRisk(
  snapshot: WeatherSnapshot,
): WeatherRuleFactType[] {
  const facts: WeatherRuleFactType[] = [];
  if (
    snapshot.precipitationType === 'SNOW' ||
    snapshot.precipitationType === 'RAIN_SNOW' ||
    snapshot.snowExpected === true
  ) {
    facts.push(WeatherRuleFactType.SNOW_LIKELY);
  } else if (isWetSnapshot(snapshot)) {
    facts.push(WeatherRuleFactType.RAIN_LIKELY);
  }
  if ((snapshot.windSpeed ?? 0) >= 9) {
    facts.push(WeatherRuleFactType.STRONG_WIND);
  }
  return facts;
}

function outdoorRiskContext(snapshot: WeatherSnapshot): 'RAIN' | 'SNOW' | 'WIND' {
  if (
    snapshot.precipitationType === 'SNOW' ||
    snapshot.precipitationType === 'RAIN_SNOW' ||
    snapshot.snowExpected === true
  ) {
    return 'SNOW';
  }
  if (isWetSnapshot(snapshot)) return 'RAIN';
  return 'WIND';
}

function addCompleteInputPositiveWindows(
  insights: LifestyleInsight[],
  snapshots: WeatherSnapshot[],
): void {
  const outingRuns = findRuns(
    snapshots.map((item) => precipitationAtPoint(item, snapshots)),
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
        (item.apparentTemperature ?? -Infinity) <= 26 &&
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
  if (!best) return;

  const validFrom = snapshotTime(best[0]);
  const validUntil = snapshotEnd(best.at(-1) ?? best[0]);
  const timeLabel = periodLabel(validFrom, exclusiveEnd(validUntil));
  insights.push({
    type: LifestyleInsightType.BEST_OUTING_WINDOW,
    score: 55,
    sourceFacts: [],
    context: { timeLabel, validFrom, validUntil },
  });
  insights.push({
    type: LifestyleInsightType.PET_WALK_WINDOW,
    score: 54,
    sourceFacts: [],
    context: { timeLabel, validFrom, validUntil },
  });
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

function exclusiveEnd(iso: string): string {
  return new Date((Math.floor(Date.parse(iso) / 1000) + 1) * 1000).toISOString();
}
