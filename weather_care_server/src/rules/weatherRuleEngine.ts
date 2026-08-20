import { RuleConfig, defaultRuleConfig } from '../config/ruleConfig';
import {
  WeatherRuleFact,
  WeatherRuleFactType,
  WeatherSnapshot,
} from '../types';
import { applyRainRule } from './rainRule';
import { applySnowRule } from './snowRule';
import { applyUvRule } from './uvRule';
import { applyHeatRule } from './heatRule';
import { applyColdRule } from './coldRule';
import { applyAirQualityRule } from './airQualityRule';
import { applyLaundryRule } from './laundryRule';
import {
  amountMinimum,
  findHysteresisRuns,
  findRuns,
  isCommuteWindow,
  isDayWindow,
  isKnownNoAmount,
  isNightWindow,
  snapshotEnd,
  snapshotTime,
  sortSnapshots,
} from './timeWindows';

export const DECISION_VERSION = 'weather-rules-1.1.0';

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

export function runWeatherRuleEngineForHourly(
  hourly: WeatherSnapshot[],
  config: RuleConfig = defaultRuleConfig,
): WeatherRuleFact[] {
  const snapshots = sortSnapshots(hourly);
  if (snapshots.length === 0) return [];

  const facts: WeatherRuleFact[] = [];
  const rainPredicate = (snapshot: WeatherSnapshot) => {
    const amount = amountMinimum(
      snapshot.precipitationAmountRange,
      snapshot.precipitationAmount,
    );
    return (
      (snapshot.precipitationProbability ?? 0) >=
        config.rain.minProbability || amount >= config.rain.minAmount
    );
  };
  const snowPredicate = (snapshot: WeatherSnapshot) =>
    snapshot.precipitationType === 'SNOW' ||
    snapshot.precipitationType === 'RAIN_SNOW' ||
    amountMinimum(
      snapshot.snowfallAmountRange,
      snapshot.snowfallAmount,
    ) > config.snow.minAmount;

  for (const run of findHysteresisRuns(
    snapshots,
    rainPredicate,
    (snapshot) =>
      (snapshot.precipitationProbability ?? 100) < 30 &&
      isKnownNoAmount(
        snapshot.precipitationAmountRange,
        snapshot.precipitationAmount,
      ),
    config.series.generalSlots,
  )) {
    facts.push(
      factForRun(
        WeatherRuleFactType.RAIN_LIKELY,
        run,
        Math.min(
          89,
          Math.max(
            40,
            ...run.map((item) => item.precipitationProbability ?? 0),
          ),
        ),
        {
          maximumPrecipitationProbability: Math.max(
            ...run.map((item) => item.precipitationProbability ?? 0),
          ),
          maximumHourlyAmountMinimum: Math.max(
            ...run.map((item) =>
              amountMinimum(
                item.precipitationAmountRange,
                item.precipitationAmount,
              ),
            ),
          ),
          consecutiveSlots: run.length,
        },
      ),
    );
  }
  for (const snapshot of snapshots.filter(
    (item) => isCommuteWindow(item) && rainPredicate(item),
  )) {
    facts.push(
      factForRun(
        WeatherRuleFactType.RAIN_LIKELY,
        [snapshot],
        Math.min(
          89,
          Math.max(40, snapshot.precipitationProbability ?? 0),
        ),
        {
          precipitationProbability: snapshot.precipitationProbability ?? 0,
          commuteWindow: true,
        },
      ),
    );
  }

  for (const snapshot of snapshots) {
    const amount = amountMinimum(
      snapshot.precipitationAmountRange,
      snapshot.precipitationAmount,
    );
    const heavy =
      amount >= config.rain.instantHeavyAmount ||
      ((snapshot.precipitationProbability ?? 0) >=
        config.rain.heavyProbability && amount >= config.rain.heavyAmount);
    if (heavy) {
      facts.push(
        factForRun(
          WeatherRuleFactType.HEAVY_RAIN,
          [snapshot],
          Math.min(100, Math.max(90, Math.round(amount * 3))),
          {
            precipitationProbability: snapshot.precipitationProbability ?? 0,
            precipitationAmountMinimum: amount,
          },
        ),
      );
    }

    const icy =
      rainPredicate(snapshot) || snowPredicate(snapshot)
        ? Math.min(
            snapshot.temperature ?? Infinity,
            snapshot.apparentTemperature ?? Infinity,
          ) <= 0
        : false;
    if (icy) {
      facts.push(
        factForRun(WeatherRuleFactType.ICY_ROAD_RISK, [snapshot], 95, {
          temperature: snapshot.temperature ?? 0,
          apparentTemperature:
            snapshot.apparentTemperature ?? snapshot.temperature ?? 0,
          inferred: true,
        }),
      );
    }
  }

  for (const run of findHysteresisRuns(
    snapshots,
    snowPredicate,
    (snapshot) =>
      snapshot.precipitationType !== 'SNOW' &&
      snapshot.precipitationType !== 'RAIN_SNOW' &&
      isKnownNoAmount(
        snapshot.snowfallAmountRange,
        snapshot.snowfallAmount,
      ),
    config.series.generalSlots,
  )) {
    facts.push(
      factForRun(
        WeatherRuleFactType.SNOW_LIKELY,
        run,
        Math.min(
          89,
          Math.max(
            50,
            ...run.map((item) => item.precipitationProbability ?? 0),
          ),
        ),
        {
          precipitationTypes: run
            .map((item) => item.precipitationType ?? 'NONE')
            .join(','),
          consecutiveSlots: run.length,
        },
      ),
    );
  }
  snapshots.forEach((snapshot, index) => {
    const hourlySnow = amountMinimum(
      snapshot.snowfallAmountRange,
      snapshot.snowfallAmount,
    );
    const threeHourSnow = snapshots
      .slice(Math.max(0, index - 2), index + 1)
      .reduce(
        (sum, item) =>
          sum +
          amountMinimum(item.snowfallAmountRange, item.snowfallAmount),
        0,
      );
    if (
      hourlySnow >= config.snow.heavyHourlyAmount ||
      threeHourSnow >= config.snow.heavyThreeHourAmount
    ) {
      facts.push(
        factForRun(WeatherRuleFactType.HEAVY_SNOW, [snapshot], 95, {
          snowfallAmountMinimum: hourlySnow,
          threeHourSnowfallMinimum: threeHourSnow,
        }),
      );
    }
  });

  addTemperatureFacts(facts, snapshots, config);
  addLaundryAndVentilationFacts(facts, snapshots, config);
  facts.push(
    ...snapshots.flatMap((snapshot) => applyAirQualityRule(snapshot, config)),
  );

  return dedupeByType(facts);
}

function addTemperatureFacts(
  facts: WeatherRuleFact[],
  snapshots: WeatherSnapshot[],
  config: RuleConfig,
): void {
  const heatPredicate = (snapshot: WeatherSnapshot) =>
    isDayWindow(snapshot) &&
    (snapshot.apparentTemperature ?? -Infinity) >=
      config.heat.apparentTemperature;
  for (const run of findHysteresisRuns(
    snapshots,
    heatPredicate,
    (snapshot) => (snapshot.apparentTemperature ?? Infinity) < 31,
    config.series.generalSlots,
  )) {
    facts.push(
      factForRun(
        WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH,
        run,
        Math.min(
          100,
          Math.round(
            Math.max(
              ...run.map((item) => item.apparentTemperature ?? 0),
            ) * 2.5,
          ),
        ),
        {
          maximumApparentTemperature: Math.max(
            ...run.map((item) => item.apparentTemperature ?? 0),
          ),
          consecutiveSlots: run.length,
        },
      ),
    );
  }
  for (const snapshot of snapshots.filter(
    (item) =>
      isDayWindow(item) &&
      (item.apparentTemperature ?? -Infinity) >=
        config.heat.instantApparentTemperature,
  )) {
    facts.push(
      factForRun(
        WeatherRuleFactType.APPARENT_TEMPERATURE_HIGH,
        [snapshot],
        90,
        { apparentTemperature: snapshot.apparentTemperature ?? 0 },
      ),
    );
  }

  const coldPredicate = (snapshot: WeatherSnapshot) =>
    (snapshot.temperature ?? Infinity) <= config.cold.temperature ||
    (snapshot.apparentTemperature ?? Infinity) <=
      config.cold.apparentTemperature;
  for (const run of findHysteresisRuns(
    snapshots,
    coldPredicate,
    (snapshot) =>
      (snapshot.temperature ?? -Infinity) > 14 &&
      (snapshot.apparentTemperature ?? -Infinity) > 12,
    config.series.generalSlots,
  )) {
    facts.push(
      factForRun(WeatherRuleFactType.TEMPERATURE_LOW, run, 70, {
        minimumTemperature: Math.min(
          ...run.map((item) => item.temperature ?? Infinity),
        ),
        minimumApparentTemperature: Math.min(
          ...run.map((item) => item.apparentTemperature ?? Infinity),
        ),
      }),
    );
  }

  const coldStressPredicate = (snapshot: WeatherSnapshot) => {
    const gap =
      snapshot.temperature !== undefined &&
      snapshot.apparentTemperature !== undefined
        ? snapshot.temperature - snapshot.apparentTemperature
        : 0;
    return (
      gap >= config.cold.apparentGap ||
      ((snapshot.temperature ?? Infinity) <= config.cold.temperature &&
        (snapshot.windSpeed ?? 0) >= config.wind.caution)
    );
  };
  for (const run of findHysteresisRuns(
    snapshots,
    coldStressPredicate,
    (snapshot) => {
      const gap =
        snapshot.temperature !== undefined &&
        snapshot.apparentTemperature !== undefined
          ? snapshot.temperature - snapshot.apparentTemperature
          : Infinity;
      return gap < 2 && (snapshot.windSpeed ?? Infinity) < 4;
    },
    config.series.generalSlots,
  )) {
    facts.push(
      factForRun(WeatherRuleFactType.COLD_STRESS_RISK, run, 70, {
        maximumWindSpeed: Math.max(
          ...run.map((item) => item.windSpeed ?? 0),
        ),
      }),
    );
  }

  const strongWindPredicate = (snapshot: WeatherSnapshot) =>
    (snapshot.windSpeed ?? 0) >= config.wind.caution;
  for (const run of findHysteresisRuns(
    snapshots,
    strongWindPredicate,
    (snapshot) => (snapshot.windSpeed ?? Infinity) < 4,
    config.series.generalSlots,
  )) {
    facts.push(
      factForRun(WeatherRuleFactType.STRONG_WIND, run, 70, {
        maximumWindSpeed: Math.max(
          ...run.map((item) => item.windSpeed ?? 0),
        ),
      }),
    );
  }
  for (const snapshot of snapshots.filter(
    (item) => (item.windSpeed ?? 0) >= config.wind.high,
  )) {
    facts.push(
      factForRun(WeatherRuleFactType.STRONG_WIND, [snapshot], 90, {
        windSpeed: snapshot.windSpeed ?? 0,
      }),
    );
  }

  const uvPredicate = (snapshot: WeatherSnapshot) =>
    isDayWindow(snapshot) &&
    (snapshot.uvIndex ?? -Infinity) >= config.uv.highThreshold;
  for (const run of findHysteresisRuns(
    snapshots,
    uvPredicate,
    (snapshot) =>
      (snapshot.uvIndex ?? Infinity) < 5 ||
      Number(snapshotTime(snapshot).slice(11, 13)) >= 17,
    config.series.generalSlots,
  )) {
    facts.push(
      factForRun(WeatherRuleFactType.UV_HIGH, run, 70, {
        maximumUvIndex: Math.max(...run.map((item) => item.uvIndex ?? 0)),
      }),
    );
  }
  for (const snapshot of snapshots.filter(
    (item) =>
      isDayWindow(item) &&
      (item.uvIndex ?? -Infinity) >= config.uv.veryHighThreshold,
  )) {
    facts.push(
      factForRun(WeatherRuleFactType.UV_HIGH, [snapshot], 90, {
        uvIndex: snapshot.uvIndex ?? 0,
      }),
    );
  }

  const temperatures = snapshots
    .map((item) => item.temperature)
    .filter((value): value is number => value !== undefined);
  if (temperatures.length > 1) {
    const range = Math.max(...temperatures) - Math.min(...temperatures);
    if (range >= config.cold.diurnalRange) {
      facts.push(
        factForRun(
          WeatherRuleFactType.LARGE_DIURNAL_RANGE,
          snapshots,
          Math.min(100, Math.round(range * 8)),
          {
            minimumTemperature: Math.min(...temperatures),
            maximumTemperature: Math.max(...temperatures),
            dailyTemperatureRange: range,
          },
        ),
      );
    }
  }

  const dropThresholds = [
    { hours: 3, change: -4 },
    { hours: 6, change: -6 },
    { hours: 12, change: -8 },
  ];
  snapshots.forEach((snapshot, index) => {
    if (snapshot.temperature === undefined) return;
    for (const threshold of dropThresholds) {
      const expectedDifference = threshold.hours * 60 * 60 * 1000;
      const target = snapshots.slice(index + 1).find((candidate) => {
        const difference =
          Date.parse(snapshotTime(candidate)) - Date.parse(snapshotTime(snapshot));
        return Math.abs(difference - expectedDifference) <= 30 * 60 * 1000;
      });
      if (target?.temperature === undefined) continue;
      const change = target.temperature - snapshot.temperature;
      if (change <= threshold.change) {
        facts.push(
          factForRun(
            WeatherRuleFactType.RAPID_TEMPERATURE_DROP,
            [snapshot, target],
            Math.min(100, 70 + Math.round(Math.abs(change))),
            {
              hours: threshold.hours,
              temperatureChange: change,
            },
          ),
        );
      }
    }
  });

  for (const run of findRuns(
    snapshots,
    (snapshot) =>
      isNightWindow(snapshot) &&
      (snapshot.temperature ?? -Infinity) >= 25 &&
      (snapshot.humidity ?? -Infinity) >= 75,
    3,
  )) {
    facts.push(
      factForRun(
        WeatherRuleFactType.SLEEP_DISCOMFORT_EXPECTED,
        run,
        70,
        {
          minimumNightTemperature: Math.min(
            ...run.map((item) => item.temperature ?? Infinity),
          ),
          minimumNightHumidity: Math.min(
            ...run.map((item) => item.humidity ?? Infinity),
          ),
        },
      ),
    );
  }
}

function addLaundryAndVentilationFacts(
  facts: WeatherRuleFact[],
  snapshots: WeatherSnapshot[],
  config: RuleConfig,
): void {
  const laundryPredicate = (snapshot: WeatherSnapshot) =>
    isDayWindow(snapshot) &&
    snapshot.precipitationProbability !== undefined &&
    snapshot.humidity !== undefined &&
    snapshot.windSpeed !== undefined &&
    (snapshot.precipitationAmountRange !== undefined ||
      snapshot.precipitationAmount !== undefined) &&
    snapshot.precipitationProbability < config.laundry.maxProbability &&
    isKnownNoAmount(
      snapshot.precipitationAmountRange,
      snapshot.precipitationAmount,
    ) &&
    snapshot.humidity <= config.laundry.maxHumidity &&
    snapshot.windSpeed >= config.laundry.minWind &&
    snapshot.windSpeed <= config.laundry.maxWind;
  for (const run of findRuns(
    snapshots,
    laundryPredicate,
    config.series.laundrySlots,
  )) {
    facts.push(
      factForRun(
        WeatherRuleFactType.LAUNDRY_DRYING_GOOD,
        run,
        80,
        { consecutiveSlots: run.length },
      ),
    );
  }

  const ventilationPredicate = (snapshot: WeatherSnapshot) => {
    const airKnown =
      (snapshot.airQualityGrade !== undefined ||
        snapshot.pm10 !== undefined ||
        snapshot.pm25 !== undefined) &&
      (snapshot.ozone !== undefined || snapshot.ozoneGrade !== undefined);
    const badAir = config.airQuality.gradeBad.includes(
      snapshot.airQualityGrade ?? '',
    );
    const badOzone = ['Bad', 'Very Bad', '나쁨', '매우 나쁨'].includes(
      snapshot.ozoneGrade ?? '',
    );
    return (
      airKnown &&
      !badAir &&
      !badOzone &&
      snapshot.precipitationProbability !== undefined &&
      snapshot.precipitationProbability < 20 &&
      isKnownNoAmount(
        snapshot.precipitationAmountRange,
        snapshot.precipitationAmount,
      ) &&
      snapshot.windSpeed !== undefined &&
      snapshot.windSpeed >= 1 &&
      snapshot.windSpeed <= 5
    );
  };
  for (const run of findRuns(snapshots, ventilationPredicate, 2)) {
    facts.push(
      factForRun(
        WeatherRuleFactType.VENTILATION_GOOD,
        run,
        60,
        { consecutiveSlots: run.length },
      ),
    );
  }

  for (const run of findRuns(
    snapshots,
    (snapshot) =>
      snapshot.humidity !== undefined &&
      snapshot.humidity >= config.humidity.high,
    3,
  )) {
    facts.push(
      factForRun(WeatherRuleFactType.HUMIDITY_HIGH, run, 70, {
        minimumHumidity: Math.min(
          ...run.map((item) => item.humidity ?? Infinity),
        ),
      }),
    );
  }
  for (const run of findRuns(
    snapshots,
    (snapshot) =>
      snapshot.humidity !== undefined &&
      snapshot.humidity <= config.humidity.low,
    3,
  )) {
    facts.push(
      factForRun(WeatherRuleFactType.HUMIDITY_LOW, run, 70, {
        maximumHumidity: Math.max(...run.map((item) => item.humidity ?? 0)),
      }),
    );
  }
}

function factForRun(
  type: WeatherRuleFactType,
  run: WeatherSnapshot[],
  severity: number,
  evidence: Record<string, string | number | boolean>,
): WeatherRuleFact {
  return {
    type,
    severity: Math.min(100, Math.max(0, Math.round(severity))),
    evidence,
    validFrom: snapshotTime(run[0]),
    validUntil: snapshotEnd(run.at(-1) ?? run[0]),
  };
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
