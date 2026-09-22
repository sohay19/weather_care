import type { DailyWeatherForecast, WeatherForecast } from '../providers/weather/weatherProvider';
import { calculateKmaApparentTemperature } from '../providers/weather/kmaWeatherProvider';
import type { WeatherSnapshot } from '../types';

export const PERCEIVED_TEMPERATURE_MODEL_VERSION = 'KR_PERCEIVED_V2_2026.1';

export type ThermalSensation = NonNullable<WeatherSnapshot['thermalSensation']>;
export type ThermalSeason = NonNullable<WeatherSnapshot['thermalSeason']>;
export type DominantFactor = NonNullable<WeatherSnapshot['dominantFactors']>[number];

export interface PerceivedTemperatureContext {
  regionKey: string;
  latitude?: number;
  longitude?: number;
  now?: Date;
  recentTemperature?: RecentTemperatureContext;
  previousThermalSensation?: ThermalSensation;
}

export interface RecentTemperatureContext {
  meanTemperature: number;
  source: NonNullable<WeatherSnapshot['recentTemperatureSource']>;
}

interface ThermalInputs {
  temperature: number;
  humidity: number;
  windSpeed: number;
  meanRadiantTemperature: number;
  clothingClo: number;
}

interface ThermalCalculation {
  perceivedTemperature: number;
  meanRadiantTemperature: number;
  radiationLevel: NonNullable<WeatherSnapshot['radiationLevel']>;
  estimatedClothingClo: number;
  estimatedClothingLabel: NonNullable<WeatherSnapshot['estimatedClothingLabel']>;
  thermalSeason: ThermalSeason;
  temperatureTrend: NonNullable<WeatherSnapshot['temperatureTrend']>;
  dominantFactors: DominantFactor[];
  confidence: NonNullable<WeatherSnapshot['perceivedConfidence']>;
}

const LIGHT_WALK_MET = 1.7;
const MIN_RECENT_COVERAGE_DAYS = 4;

export function enrichForecastWithPerceivedTemperature(
  forecast: WeatherForecast,
  context: PerceivedTemperatureContext,
): WeatherForecast {
  const current = enrichSnapshotWithPerceivedTemperature(forecast.current, context);
  let previous = current.thermalSensation;
  const hourly = forecast.hourly.map((snapshot) => {
    const enriched = enrichSnapshotWithPerceivedTemperature(snapshot, {
      ...context,
      previousThermalSensation: previous,
    });
    previous = enriched.thermalSensation;
    return enriched;
  });
  const byTime = new Map(hourly.map((snapshot) => [snapshotTime(snapshot), snapshot]));
  const timelineHourly = forecast.timelineHourly?.map((snapshot) =>
    byTime.get(snapshotTime(snapshot)) ??
      enrichSnapshotWithPerceivedTemperature(snapshot, context));
  return { ...forecast, current, hourly, timelineHourly };
}

export function enrichSnapshotWithPerceivedTemperature(
  snapshot: WeatherSnapshot,
  context: PerceivedTemperatureContext,
): WeatherSnapshot {
  const temperature = finite(snapshot.temperature);
  const humidity = finite(snapshot.humidity);
  const windSpeed = finite(snapshot.windSpeed);
  const at = snapshot.forecastAt ?? snapshot.observedAt;
  const role = snapshot.dataRole === 'OBSERVATION' ? 'OBSERVATION' : 'FORECAST';
  const kmaApparentTemperature = temperature === undefined
    ? undefined
    : snapshot.apparentTemperature ?? calculateKmaApparentTemperature(
      temperature,
      humidity,
      windSpeed,
      at,
    );
  const trace = traceMetadata(snapshot, context, role);

  if (temperature === undefined) {
    return {
      ...snapshot,
      ...trace,
      kmaApparentTemperature,
    };
  }

  if (humidity === undefined || windSpeed === undefined) {
    if (kmaApparentTemperature === undefined) {
      return { ...snapshot, ...trace };
    }
    const perceivedTemperature = roundOne(kmaApparentTemperature);
    const thermalSensation = classifyThermalSensation(
      perceivedTemperature,
      context.previousThermalSensation,
    );
    return {
      ...snapshot,
      ...trace,
      kmaApparentTemperature,
      perceivedTemperature,
      perceivedDifference: roundOne(perceivedTemperature - temperature),
      perceivedModelVersion: PERCEIVED_TEMPERATURE_MODEL_VERSION,
      perceivedConfidence: 'LOW',
      modelSource: role === 'OBSERVATION'
        ? 'KMA_FALLBACK_FROM_OBSERVATION'
        : 'KMA_FALLBACK_FROM_FORECAST',
      thermalSensation,
      dominantFactors: ['TEMPERATURE'],
      thermalBrief: buildThermalBrief({
        regionKey: context.regionKey,
        at,
        thermalSensation,
        perceivedTemperature,
        airTemperature: temperature,
        dominantFactors: ['TEMPERATURE'],
        fallback: true,
      }),
    };
  }

  const calculation = calculatePerceivedTemperature({
    snapshot,
    temperature,
    humidity,
    windSpeed,
    context,
  });
  const thermalSensation = classifyThermalSensation(
    calculation.perceivedTemperature,
    context.previousThermalSensation,
  );
  const perceivedDifference = roundOne(
    calculation.perceivedTemperature - temperature,
  );
  return {
    ...snapshot,
    ...trace,
    kmaApparentTemperature,
    perceivedTemperature: calculation.perceivedTemperature,
    perceivedDifference,
    perceivedModelVersion: PERCEIVED_TEMPERATURE_MODEL_VERSION,
    perceivedConfidence: calculation.confidence,
    modelSource: role === 'OBSERVATION'
      ? 'KR_PT_V2_FROM_OBSERVATION'
      : 'KR_PT_V2_FROM_FORECAST',
    thermalSensation,
    estimatedClothingClo: calculation.estimatedClothingClo,
    estimatedClothingLabel: calculation.estimatedClothingLabel,
    thermalSeason: calculation.thermalSeason,
    recentMeanTemperature7d: context.recentTemperature?.meanTemperature,
    recentTemperatureSource: context.recentTemperature?.source,
    temperatureTrend: calculation.temperatureTrend,
    meanRadiantTemperature: calculation.meanRadiantTemperature,
    radiationLevel: calculation.radiationLevel,
    dominantFactors: calculation.dominantFactors,
    thermalBrief: buildThermalBrief({
      regionKey: context.regionKey,
      at,
      thermalSensation,
      perceivedTemperature: calculation.perceivedTemperature,
      airTemperature: temperature,
      dominantFactors: calculation.dominantFactors,
      clothingLabel: calculation.estimatedClothingLabel,
      trend: calculation.temperatureTrend,
    }),
  };
}

export function recentTemperatureContext(
  observedDays: DailyWeatherForecast[],
): RecentTemperatureContext | undefined {
  const usable = observedDays
    .filter((day) =>
      day.forecastSource === 'KMA_OBSERVATION' &&
      finite(day.minTemperature) !== undefined &&
      finite(day.maxTemperature) !== undefined)
    .sort((left, right) => left.date.localeCompare(right.date))
    .slice(-7);
  if (usable.length < MIN_RECENT_COVERAGE_DAYS) return undefined;
  const meanTemperature = usable.reduce(
    (sum, day) => sum + (day.minTemperature! + day.maxTemperature!) / 2,
    0,
  ) / usable.length;
  const stations = usable.map((day) => day.observationStationId).filter(Boolean);
  const stationId = mostFrequent(stations as string[]);
  const matching = usable.filter((day) => day.observationStationId === stationId);
  const distance = matching
    .map((day) => day.observationDistanceKm)
    .filter((value): value is number => finite(value) !== undefined);
  return {
    meanTemperature: roundOne(meanTemperature),
    source: {
      stationId,
      stationName: matching.find((day) => day.observationStationName)
        ?.observationStationName,
      distanceKm: distance.length === 0
        ? undefined
        : roundOne(distance.reduce((sum, value) => sum + value, 0) / distance.length),
      coverageDays: usable.length,
      fromDate: calendarDate(usable[0].date),
      toDate: calendarDate(usable.at(-1)!.date),
    },
  };
}

export function classifyThermalSensation(
  perceivedTemperature: number,
  previous?: ThermalSensation,
): ThermalSensation {
  const resolved = sensationForValue(perceivedTemperature);
  if (previous === undefined || previous === resolved) return resolved;
  const previousIndex = THERMAL_SENSATIONS.indexOf(previous);
  const resolvedIndex = THERMAL_SENSATIONS.indexOf(resolved);
  // 상승 시에는 경계에서 바로 진입하되, 하강 시에는 0.3℃ 아래까지
  // 이전 상태를 유지해 26.9↔27.0 같은 표시 깜빡임을 줄인다.
  if (previousIndex === resolvedIndex + 1) {
    const releaseBoundary = SENSATION_LOWER_BOUNDS[previousIndex] - 0.3;
    if (perceivedTemperature > releaseBoundary) return previous;
  }
  return resolved;
}

const THERMAL_SENSATIONS: ThermalSensation[] = [
  'VERY_COLD', 'COLD', 'CHILLY', 'COOL', 'COOL_COMFORTABLE', 'COMFORTABLE',
  'WARM_COMFORTABLE', 'WARM', 'SLIGHTLY_HOT', 'HOT', 'VERY_HOT', 'EXTREME_HOT',
];
const SENSATION_LOWER_BOUNDS = [
  Number.NEGATIVE_INFINITY, -5, 4, 10, 16, 20, 24, 27, 29, 32, 36, 43,
];

function sensationForValue(perceivedTemperature: number): ThermalSensation {
  if (perceivedTemperature < -5) return 'VERY_COLD';
  if (perceivedTemperature < 4) return 'COLD';
  if (perceivedTemperature < 10) return 'CHILLY';
  if (perceivedTemperature < 16) return 'COOL';
  if (perceivedTemperature < 20) return 'COOL_COMFORTABLE';
  if (perceivedTemperature < 24) return 'COMFORTABLE';
  if (perceivedTemperature < 27) return 'WARM_COMFORTABLE';
  if (perceivedTemperature < 29) return 'WARM';
  if (perceivedTemperature < 32) return 'SLIGHTLY_HOT';
  if (perceivedTemperature < 36) return 'HOT';
  if (perceivedTemperature < 43) return 'VERY_HOT';
  return 'EXTREME_HOT';
}

export function perceivedDifferenceBand(
  perceivedTemperature: number,
  airTemperature: number,
): 'NEAR' | 'SMALL' | 'MODERATE' | 'CLEAR' | 'LARGE' {
  const difference = Math.abs(perceivedTemperature - airTemperature);
  if (difference < 0.6) return 'NEAR';
  if (difference < 1.5) return 'SMALL';
  if (difference < 3) return 'MODERATE';
  if (difference < 5) return 'CLEAR';
  return 'LARGE';
}

export function buildThermalBrief(options: {
  regionKey: string;
  at: string;
  thermalSensation: ThermalSensation;
  perceivedTemperature: number;
  airTemperature: number;
  dominantFactors: DominantFactor[];
  clothingLabel?: NonNullable<WeatherSnapshot['estimatedClothingLabel']>;
  trend?: NonNullable<WeatherSnapshot['temperatureTrend']>;
  fallback?: boolean;
}): string {
  const factor = options.dominantFactors[0] ?? 'TEMPERATURE';
  const candidates = sensationMessages(options.thermalSensation, factor, options.trend);
  const slot = Math.floor(koreanLocalHour(options.at) / 3);
  const seed = [
    options.regionKey,
    options.at.slice(0, 10),
    String(slot),
    options.thermalSensation,
    factor,
  ].join('|');
  const blocks = [candidates[stableIndex(seed, candidates.length)]];
  const difference = differenceMessage(
    options.perceivedTemperature,
    options.airTemperature,
  );
  if (difference) blocks.push(difference);
  const clothing = options.clothingLabel === undefined
    ? undefined
    : clothingMessage(options.clothingLabel, options.thermalSensation);
  if (clothing && blocks.length < 3) blocks.push(clothing);
  if (options.fallback) {
    blocks.push('현재 자료로는 기온과 바람·습도를 중심으로 체감을 계산했어요.');
  }
  return blocks.slice(0, 3).join(' ');
}

function calculatePerceivedTemperature(options: {
  snapshot: WeatherSnapshot;
  temperature: number;
  humidity: number;
  windSpeed: number;
  context: PerceivedTemperatureContext;
}): ThermalCalculation {
  const recentMean = options.context.recentTemperature?.meanTemperature;
  const thermalSeason = thermalSeasonFor(recentMean ?? options.temperature);
  const clothingClo = clothingForTemperature(recentMean ?? options.temperature);
  const radiation = radiantEnvironment(
    options.snapshot,
    options.temperature,
    options.context.latitude,
    options.context.longitude,
  );
  const inputs: ThermalInputs = {
    temperature: options.temperature,
    humidity: options.humidity,
    windSpeed: options.windSpeed,
    meanRadiantTemperature: radiation.meanRadiantTemperature,
    clothingClo,
  };
  const base = equivalentTemperature(inputs);
  const wetness = precipitationWetnessAdjustment(
    options.snapshot,
    base,
    options.windSpeed,
  );
  const adaptation = adaptationAdjustment(options.temperature, recentMean);
  const perceivedTemperature = roundOne(base + wetness + adaptation);
  const impacts: Array<{ factor: DominantFactor; impact: number }> = [
    {
      factor: 'HUMIDITY',
      impact: base - equivalentTemperature({ ...inputs, humidity: 50 }),
    },
    {
      factor: 'WIND',
      impact: base - equivalentTemperature({ ...inputs, windSpeed: 1 }),
    },
    {
      factor: 'RADIATION',
      impact: base - equivalentTemperature({
        ...inputs,
        meanRadiantTemperature: options.temperature,
      }),
    },
    {
      factor: 'CLOTHING',
      impact: base - equivalentTemperature({
        ...inputs,
        clothingClo: neutralClothingFor(thermalSeason),
      }),
    },
    { factor: 'PRECIPITATION', impact: wetness },
    { factor: 'RECENT_TEMPERATURE', impact: adaptation },
  ];
  const dominantFactors = impacts
    .filter(({ impact }) => Math.abs(impact) >= 0.3)
    .sort((left, right) => Math.abs(right.impact) - Math.abs(left.impact))
    .slice(0, 2)
    .map(({ factor }) => factor);
  if (dominantFactors.length === 0) dominantFactors.push('TEMPERATURE');
  return {
    perceivedTemperature,
    meanRadiantTemperature: roundOne(radiation.meanRadiantTemperature),
    radiationLevel: radiation.level,
    estimatedClothingClo: roundTwo(clothingClo),
    estimatedClothingLabel: clothingLabel(clothingClo),
    thermalSeason,
    temperatureTrend: temperatureTrend(options.temperature, recentMean),
    dominantFactors,
    confidence: radiation.source === 'MEASURED'
      ? recentMean === undefined ? 'MEDIUM' : 'HIGH'
      : radiation.source === 'ESTIMATED' && recentMean !== undefined
        ? 'MEDIUM'
        : 'LOW',
  };
}

function equivalentTemperature(inputs: ThermalInputs): number {
  const target = pmv(inputs);
  let low = -50;
  let high = 70;
  for (let index = 0; index < 40; index += 1) {
    const middle = (low + high) / 2;
    const reference = pmv({
      ...inputs,
      temperature: middle,
      humidity: 50,
      windSpeed: 0.1,
      meanRadiantTemperature: middle,
    });
    if (reference < target) low = middle;
    else high = middle;
  }
  return clamp((low + high) / 2, -60, 70);
}

/** ISO 7730 Fanger PMV heat-balance implementation used as the v2 PT engine. */
function pmv(inputs: ThermalInputs): number {
  const tdb = clamp(inputs.temperature, -60, 60);
  const tr = clamp(inputs.meanRadiantTemperature, -60, 90);
  const vr = clamp(inputs.windSpeed, 0.1, 20);
  const rh = clamp(inputs.humidity, 0, 100);
  const met = LIGHT_WALK_MET;
  const clo = clamp(inputs.clothingClo, 0.5, 1.75);
  const pa = rh * 10 * Math.exp(16.6536 - 4030.183 / (tdb + 235));
  const icl = 0.155 * clo;
  const m = met * 58.15;
  const mw = m;
  const fcl = icl <= 0.078 ? 1 + 1.29 * icl : 1.05 + 0.645 * icl;
  const hcf = 12.1 * Math.sqrt(vr);
  const taa = tdb + 273;
  const tra = tr + 273;
  const tcla = taa + (35.5 - tdb) / (3.5 * (6.45 * icl + 0.1));
  const p1 = icl * fcl;
  const p2 = p1 * 3.96;
  const p3 = p1 * 100;
  const p4 = p1 * taa;
  const p5 = 308.7 - 0.028 * mw + p2 * (tra / 100) ** 4;
  let xn = tcla / 100;
  let xf = tcla / 50;
  let hc = hcf;
  for (let index = 0; index < 150 && Math.abs(xn - xf) > 0.00015; index += 1) {
    xf = (xf + xn) / 2;
    const hcn = 2.38 * Math.abs(100 * xf - taa) ** 0.25;
    hc = Math.max(hcf, hcn);
    xn = (p5 + p4 * hc - p2 * xn ** 4) / (100 + p3 * hc);
  }
  const tcl = 100 * xn - 273;
  const heatLoss =
    3.05 * 0.001 * (5733 - 6.99 * mw - pa) +
    (mw > 58.15 ? 0.42 * (mw - 58.15) : 0) +
    1.7e-5 * m * (5867 - pa) +
    0.0014 * m * (34 - tdb) +
    3.96 * fcl * (xn ** 4 - (tra / 100) ** 4) +
    fcl * hc * (tcl - tdb);
  return (0.303 * Math.exp(-0.036 * m) + 0.028) * (mw - heatLoss);
}

function radiantEnvironment(
  snapshot: WeatherSnapshot,
  temperature: number,
  latitude?: number,
  longitude?: number,
): {
  meanRadiantTemperature: number;
  level: NonNullable<WeatherSnapshot['radiationLevel']>;
  source: 'MEASURED' | 'ESTIMATED' | 'UNAVAILABLE';
} {
  if (finite(snapshot.meanRadiantTemperature) !== undefined) {
    const meanRadiantTemperature = snapshot.meanRadiantTemperature!;
    return {
      meanRadiantTemperature,
      level: radiationLevel(meanRadiantTemperature - temperature),
      source: 'MEASURED',
    };
  }
  const solarRadiation = finite(snapshot.solarRadiation);
  if (solarRadiation !== undefined) {
    const delta = clamp(Math.sqrt(Math.max(0, solarRadiation)) * 0.65, 0, 20);
    return {
      meanRadiantTemperature: temperature + delta,
      level: radiationLevel(delta),
      source: 'MEASURED',
    };
  }
  if (!snapshot.skyCondition && snapshot.uvIndex === undefined) {
    return {
      meanRadiantTemperature: temperature,
      level: 'LOW',
      source: 'UNAVAILABLE',
    };
  }
  const at = snapshot.forecastAt ?? snapshot.observedAt;
  const elevation = solarElevation(at, latitude, longitude);
  if (elevation <= 0) {
    return {
      meanRadiantTemperature: temperature,
      level: 'LOW',
      source: 'ESTIMATED',
    };
  }
  const sky = snapshot.skyCondition ?? '';
  const cloudFactor = sky.includes('흐림') ? 0.35
    : sky.includes('구름') ? 0.65
      : hasPrecipitation(snapshot) ? 0.25
        : 1;
  const uvFactor = snapshot.uvIndex === undefined
    ? 1
    : clamp(0.75 + snapshot.uvIndex / 20, 0.75, 1.25);
  const delta = clamp(
    18 * Math.sin(elevation * Math.PI / 180) ** 0.7 * cloudFactor * uvFactor,
    0,
    20,
  );
  return {
    meanRadiantTemperature: temperature + delta,
    level: radiationLevel(delta),
    source: 'ESTIMATED',
  };
}

function solarElevation(at: string, latitude?: number, longitude?: number): number {
  const instant = Date.parse(at);
  if (!Number.isFinite(instant) || finite(latitude) === undefined ||
      finite(longitude) === undefined) {
    const hour = koreanLocalHour(at);
    return hour >= 7 && hour < 19 ? 35 : -10;
  }
  const date = new Date(instant);
  const start = Date.UTC(date.getUTCFullYear(), 0, 0);
  const day = Math.floor((instant - start) / 86_400_000);
  const hour = date.getUTCHours() + date.getUTCMinutes() / 60;
  const gamma = 2 * Math.PI / 365 * (day - 1 + (hour - 12) / 24);
  const equationOfTime = 229.18 * (
    0.000075 + 0.001868 * Math.cos(gamma) - 0.032077 * Math.sin(gamma) -
    0.014615 * Math.cos(2 * gamma) - 0.040849 * Math.sin(2 * gamma)
  );
  const declination =
    0.006918 - 0.399912 * Math.cos(gamma) + 0.070257 * Math.sin(gamma) -
    0.006758 * Math.cos(2 * gamma) + 0.000907 * Math.sin(2 * gamma) -
    0.002697 * Math.cos(3 * gamma) + 0.00148 * Math.sin(3 * gamma);
  const solarMinutes = hour * 60 + equationOfTime + 4 * longitude!;
  const hourAngle = (solarMinutes / 4 - 180) * Math.PI / 180;
  const lat = latitude! * Math.PI / 180;
  return Math.asin(
    Math.sin(lat) * Math.sin(declination) +
    Math.cos(lat) * Math.cos(declination) * Math.cos(hourAngle),
  ) * 180 / Math.PI;
}

function precipitationWetnessAdjustment(
  snapshot: WeatherSnapshot,
  basePerceivedTemperature: number,
  windSpeed: number,
): number {
  const type = snapshot.precipitationType;
  if (type === 'SNOW') return basePerceivedTemperature <= 24 ? -0.3 : 0;
  if (type === 'RAIN_SNOW') return basePerceivedTemperature <= 24 ? -0.7 : 0;
  if (type !== 'RAIN' && type !== 'SHOWER') return 0;
  if (basePerceivedTemperature > 24) return 0;
  const amount = snapshot.precipitationAmount ??
    snapshot.precipitationAmountRange?.min ?? 0;
  let adjustment = amount >= 5 && basePerceivedTemperature <= 20
    ? -1
    : amount >= 1 ? -0.6 : -0.3;
  if (windSpeed >= 5) adjustment -= 0.3;
  return Math.max(-1.3, adjustment);
}

function adaptationAdjustment(
  currentTemperature: number,
  recentMean: number | undefined,
): number {
  if (recentMean === undefined) return 0;
  const difference = currentTemperature - recentMean;
  if (difference >= 6) return 1;
  if (difference > 3) return 0.5;
  if (difference <= -6) return -1;
  if (difference < -3) return -0.5;
  return 0;
}

function clothingForTemperature(temperature: number): number {
  if (temperature <= 20) {
    return clamp(1 - (temperature - 10) * 0.023, 0.5, 1.75);
  }
  return clamp(0.77 - (temperature - 20) * 0.022, 0.5, 1.75);
}

function clothingLabel(
  clo: number,
): NonNullable<WeatherSnapshot['estimatedClothingLabel']> {
  if (clo <= 0.55) return 'VERY_LIGHT';
  if (clo <= 0.7) return 'LIGHT';
  if (clo <= 0.85) return 'LIGHT_LAYER';
  if (clo <= 1.05) return 'JACKET';
  if (clo <= 1.25) return 'COAT';
  if (clo <= 1.45) return 'LIGHT_PADDING';
  return 'WINTER_LAYER';
}

function clothingMessage(
  label: NonNullable<WeatherSnapshot['estimatedClothingLabel']>,
  sensation: ThermalSensation,
): string | undefined {
  if (['WARM', 'SLIGHTLY_HOT', 'HOT', 'VERY_HOT', 'EXTREME_HOT'].includes(sensation)) {
    return undefined;
  }
  return {
    VERY_LIGHT: '가벼운 옷차림이 자연스러운 날씨예요.',
    LIGHT: '반팔이나 얇은 긴팔 정도가 편안해요.',
    LIGHT_LAYER: '얇은 긴팔이나 가벼운 겉옷이 어울려요.',
    JACKET: '가벼운 자켓을 입기 좋은 정도예요.',
    COAT: '겉옷이 필요한 쌀쌀한 날씨예요.',
    LIGHT_PADDING: '따뜻한 겉옷이 있어야 편안해요.',
    WINTER_LAYER: '두꺼운 방한 옷차림이 필요한 추위예요.',
  }[label];
}

function sensationMessages(
  sensation: ThermalSensation,
  factor: DominantFactor,
  trend?: NonNullable<WeatherSnapshot['temperatureTrend']>,
): string[] {
  if (sensation === 'COOL_COMFORTABLE' && trend === 'WARMER_THAN_RECENT') {
    return ['최근보다 포근해져 한결 편안하게 느껴져요.'];
  }
  if (sensation === 'COOL_COMFORTABLE' && trend === 'COLDER_THAN_RECENT') {
    return ['더위가 누그러져 선선하고 쾌적해요.'];
  }
  if (factor === 'HUMIDITY' && ['WARM', 'SLIGHTLY_HOT', 'HOT', 'VERY_HOT'].includes(sensation)) {
    return ['습도까지 높아 후텁지근해요.', '따뜻하고 조금 후텁지근하게 느껴져요.'];
  }
  if (factor === 'RADIATION' && ['WARM', 'SLIGHTLY_HOT', 'HOT', 'VERY_HOT'].includes(sensation)) {
    return ['햇볕 아래에서는 더 덥게 느껴질 수 있어요.', '햇볕이 강해 체감 더위가 커요.'];
  }
  if (factor === 'WIND' && ['VERY_COLD', 'COLD', 'CHILLY', 'COOL'].includes(sensation)) {
    return ['바람 때문에 제법 쌀쌀하게 느껴져요.', '바람이 불어 체감 추위가 더 커요.'];
  }
  if (factor === 'PRECIPITATION' && ['VERY_COLD', 'COLD', 'CHILLY', 'COOL'].includes(sensation)) {
    return ['비와 바람 때문에 제법 서늘해요.', '비가 내려 체감이 더 서늘해요.'];
  }
  return {
    VERY_COLD: ['매섭게 추운 날씨예요.', '매우 춥고 차가운 공기가 느껴져요.'],
    COLD: ['추워요.', '차가운 공기가 확실히 느껴져요.'],
    CHILLY: ['꽤 쌀쌀해요.', '찬 기운이 느껴지는 날씨예요.'],
    COOL: ['서늘하게 느껴져요.', '가벼운 겉옷이 생각나는 서늘함이에요.'],
    COOL_COMFORTABLE: ['선선하고 쾌적하게 느껴져요.', '공기가 선선해 활동하기 편안해요.'],
    COMFORTABLE: ['덥지도 춥지도 않아 쾌적해요.', '크게 덥거나 춥지 않아 편안해요.', '활동하기 무난하고 쾌적한 날씨예요.'],
    WARM_COMFORTABLE: ['따뜻하지만 크게 덥지 않아 쾌적해요.', '포근하고 편안하게 느껴지는 날씨예요.', '따뜻한 편이지만 부담스러운 더위는 아니에요.'],
    WARM: ['제법 따뜻하게 느껴져요.', '따뜻함이 뚜렷한 날씨예요.'],
    SLIGHTLY_HOT: ['조금 더워요.', '움직이면 더위가 느껴질 정도예요.'],
    HOT: ['더운 느낌이 뚜렷해요.', '체감 더위가 강해요.'],
    VERY_HOT: ['많이 덥게 느껴지는 날씨예요.', '체감 더위가 매우 강해요.'],
    EXTREME_HOT: ['극심하게 덥게 느껴지는 날씨예요.'],
  }[sensation];
}

function differenceMessage(perceived: number, air: number): string | undefined {
  const difference = perceived - air;
  const direction = difference > 0 ? '높' : '낮';
  switch (perceivedDifferenceBand(perceived, air)) {
    case 'NEAR':
      return undefined;
    case 'SMALL':
      return difference > 0
        ? '기온보다 조금 더 따뜻하게 느껴져요.'
        : '기온보다 조금 더 서늘하게 느껴져요.';
    case 'MODERATE':
      return `기온보다 체감은 약 ${Math.round(Math.abs(difference))}℃ ${direction}아요.`;
    case 'CLEAR':
      return difference > 0
        ? '기온보다 확실히 더 덥게 느껴져요.'
        : '기온보다 확실히 더 춥게 느껴져요.';
    case 'LARGE':
      return difference > 0
        ? '기온 숫자보다 훨씬 덥게 느껴질 수 있어요.'
        : '기온 숫자보다 훨씬 춥게 느껴질 수 있어요.';
  }
}

function traceMetadata(
  snapshot: WeatherSnapshot,
  context: PerceivedTemperatureContext,
  role: 'OBSERVATION' | 'FORECAST',
): Pick<WeatherSnapshot, 'dataAgeMinutes' | 'sourceLocation' | 'fieldSources'> {
  const observedAt = role === 'OBSERVATION' ? snapshot.observedAt : undefined;
  const forecastAt = role === 'FORECAST'
    ? snapshot.forecastAt ?? snapshot.observedAt
    : undefined;
  const now = context.now ?? new Date();
  const observedInstant = observedAt === undefined ? Number.NaN : Date.parse(observedAt);
  return {
    dataAgeMinutes: Number.isFinite(observedInstant)
      ? Math.max(0, Math.round((now.getTime() - observedInstant) / 60_000))
      : undefined,
    sourceLocation: snapshot.sourceLocation ?? {
      type: 'GRID',
      nx: gridPart(context.regionKey, 0),
      ny: gridPart(context.regionKey, 1),
      locationMatch: 'EXACT_GRID',
    },
    fieldSources: snapshot.fieldSources ?? {
      temperature: { role, field: role === 'OBSERVATION' ? 'T1H' : 'TMP', observedAt, forecastAt },
      humidity: { role, field: 'REH', observedAt, forecastAt },
      windSpeed: { role, field: 'WSD', observedAt, forecastAt },
      sky: {
        role: role === 'OBSERVATION' ? 'FORECAST_PROXY' : 'FORECAST',
        field: 'SKY',
        forecastAt: snapshot.forecastAt ?? snapshot.observedAt,
      },
    },
  };
}

function thermalSeasonFor(temperature: number): ThermalSeason {
  if (temperature < 5) return 'COLD';
  if (temperature < 15) return 'COOL_TRANSITION';
  if (temperature < 23) return 'MILD';
  return 'HOT';
}

function temperatureTrend(
  current: number,
  recent: number | undefined,
): NonNullable<WeatherSnapshot['temperatureTrend']> {
  if (recent === undefined || Math.abs(current - recent) <= 3) return 'STABLE';
  return current > recent ? 'WARMER_THAN_RECENT' : 'COLDER_THAN_RECENT';
}

function neutralClothingFor(season: ThermalSeason): number {
  return { COLD: 1.5, COOL_TRANSITION: 1.1, MILD: 0.8, HOT: 0.58 }[season];
}

function radiationLevel(
  radiantDifference: number,
): NonNullable<WeatherSnapshot['radiationLevel']> {
  if (radiantDifference < 2) return 'LOW';
  if (radiantDifference < 7) return 'MODERATE';
  if (radiantDifference < 13) return 'HIGH';
  return 'VERY_HIGH';
}

function hasPrecipitation(snapshot: WeatherSnapshot): boolean {
  return snapshot.precipitationType !== undefined &&
    snapshot.precipitationType !== 'NONE';
}

function snapshotTime(snapshot: WeatherSnapshot): string {
  return snapshot.forecastAt ?? snapshot.observedAt;
}

function koreanLocalHour(value: string): number {
  const local = value.match(/T(\d{2}):/);
  if (local) return Number(local[1]);
  const parsed = Date.parse(value);
  return Number.isFinite(parsed)
    ? new Date(parsed + 9 * 60 * 60 * 1000).getUTCHours()
    : 0;
}

function stableIndex(seed: string, size: number): number {
  let hash = 2_166_136_261;
  for (let index = 0; index < seed.length; index += 1) {
    hash ^= seed.charCodeAt(index);
    hash = Math.imul(hash, 16_777_619);
  }
  return Math.abs(hash) % size;
}

function gridPart(regionKey: string, index: number): number | undefined {
  const value = Number(regionKey.split(':')[index]);
  return Number.isInteger(value) ? value : undefined;
}

function calendarDate(value: string): string {
  return /^\d{8}$/.test(value)
    ? `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`
    : value.slice(0, 10);
}

function mostFrequent(values: string[]): string | undefined {
  const counts = new Map<string, number>();
  for (const value of values) counts.set(value, (counts.get(value) ?? 0) + 1);
  return [...counts.entries()].sort((left, right) => right[1] - left[1])[0]?.[0];
}

function finite(value: number | undefined): number | undefined {
  return value !== undefined && Number.isFinite(value) ? value : undefined;
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}

function roundOne(value: number): number {
  return Math.round(value * 10) / 10;
}

function roundTwo(value: number): number {
  return Math.round(value * 100) / 100;
}
