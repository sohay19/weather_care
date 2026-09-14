import type { WeatherForecast } from '../providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../types';
import { defaultRuleConfig } from '../config/ruleConfig';
import { precipitationDecisionSnapshot, precipitationPeriod, periodLabel, otherDatePrefix, koreanHour } from '../rules/precipitationWindows';
import { snapshotTime } from '../rules/timeWindows';

export const WEATHER_BRIEF_CATALOG_VERSION = 'weather-brief-2026.09.4';
const HOUR = 3_600_000;
export type WeatherBriefScene =
  | 'WET_TRAVEL'
  | 'CAREFUL_STEPS'
  | 'MASK_READY'
  | 'SHADE_BREAK'
  | 'LAYER_READY'
  | 'STEADY_PACE'
  | 'DAILY_RHYTHM';

export interface WeatherBriefContext {
  regionKey?: string;
  dateKey?: string;
  now?: Date;
}

export interface WeatherBriefResult {
  text: string;
  scene: WeatherBriefScene;
  templateId: string;
  slots: Readonly<{ eventTime?: string }>;
  catalogVersion: string;
  /** Exclusive display deadline: re-evaluate when the event starts or ends. */
  expiresAt?: string;
}

interface SceneSelection {
  scene: WeatherBriefScene;
  snapshot: WeatherSnapshot;
  start?: number;
  end?: number;
  precipitation?: boolean;
}

export function buildWeatherBrief(
  forecast: WeatherForecast,
  context: WeatherBriefContext = {},
): string {
  return buildWeatherBriefResult(forecast, context).text;
}

export function buildWeatherBriefResult(
  forecast: WeatherForecast,
  context: WeatherBriefContext = {},
): WeatherBriefResult {
  const now = context.now ?? new Date();
  const reference = now.getTime();
  const selection = selectScene(forecast, now);
  let eventTime: string | undefined;
  let expiresAt: string | undefined;
  if (selection.start !== undefined && selection.end !== undefined) {
    const active = selection.start <= reference;
    const start = new Date(selection.start).toISOString();
    const end = new Date(selection.end).toISOString();
    eventTime = active ? '지금'
      : otherDatePrefix(start, now.toISOString()) +
        (selection.precipitation ? periodLabel(start, end) : koreanHour(start));
    expiresAt = active ? end : start;
  }
  return {
    text: messageFor(selection, eventTime ?? ''),
    scene: selection.scene,
    templateId: `policy-${selection.scene.toLowerCase()}`,
    slots: eventTime ? { eventTime } : {},
    catalogVersion: WEATHER_BRIEF_CATALOG_VERSION,
    expiresAt,
  };
}

function selectScene(forecast: WeatherForecast, now: Date): SceneSelection {
  const reference = now.getTime();
  const candidates = [forecast.current, ...forecast.hourly.slice(0, 24)]
    .map((item) => precipitationDecisionSnapshot(item, now))
    .filter((item) => Number.isFinite(Date.parse(snapshotTime(item))))
    .sort((a, b) => Date.parse(snapshotTime(a)) - Date.parse(snapshotTime(b)));

  // Point forecasts describe their own hour; PCP/SNO describe the preceding
  // interval. Do not shift raw forecast timestamps or reuse ended intervals.
  const find = (scene: WeatherBriefScene, predicate: (item: WeatherSnapshot) => boolean,
    precipitation = false): SceneSelection | undefined => {
    for (const snapshot of candidates) {
      const period = precipitation ? precipitationPeriod(snapshot) : undefined;
      const point = Date.parse(snapshotTime(snapshot));
      const start = period ? Date.parse(period.start) : point;
      const end = period ? Date.parse(period.end)
        : snapshot.validTo === undefined ? point + HOUR
          : Math.min(Date.parse(snapshot.validTo), point + HOUR);
      if (!Number.isFinite(reference) || !Number.isFinite(end) || end <= start ||
        end <= reference || start >= reference + 24 * HOUR) continue;
      if (predicate(snapshot)) return { scene, snapshot, start, end, precipitation: !!period };
    }
    return undefined;
  };

  const snowy = find('CAREFUL_STEPS', isSnowy, true);
  if (snowy) return snowy;

  const rainy = find('WET_TRAVEL', isRainy, true);
  if (rainy) return rainy;

  const poorAir = find('MASK_READY', hasPoorAirQuality);
  if (poorAir) return poorAir;

  const strongExposure = find('SHADE_BREAK',
    (item) =>
      (item.apparentTemperature ?? -Infinity) >=
        defaultRuleConfig.heat.actionApparentTemperature ||
      (item.temperature ?? -Infinity) >=
        defaultRuleConfig.heat.actionAirTemperature ||
      (item.uvIndex ?? 0) >= defaultRuleConfig.uv.highThreshold,
  );
  if (strongExposure) {
    return strongExposure;
  }

  const layerUseful = find('LAYER_READY',
    (item) =>
      (item.temperature ?? Infinity) <= defaultRuleConfig.cold.temperature ||
      (item.apparentTemperature ?? Infinity) <=
        defaultRuleConfig.cold.apparentTemperature,
  );
  if (layerUseful) return layerUseful;

  const strongWind = find('STEADY_PACE',
    (item) => (item.windSpeed ?? 0) >= defaultRuleConfig.wind.caution,
  );
  if (strongWind) return strongWind;

  return { scene: 'DAILY_RHYTHM', snapshot: forecast.current };
}

function messageFor(selection: SceneSelection, eventTime: string): string {
  const snapshot = selection.snapshot;
  switch (selection.scene) {
    case 'CAREFUL_STEPS':
      return `눈이 내릴 수 있으니, ${eventTime} 외출한다면 도로 상태와 대중교통 운행정보를 확인하세요`;
    case 'WET_TRAVEL':
      return snapshot.precipitationType === 'SHOWER'
        ? `소나기가 내릴 수 있으니, ${eventTime} 외출한다면 우산을 챙기세요`
        : `비가 올 수 있으니, ${eventTime} 외출한다면 우산을 챙기세요`;
    case 'MASK_READY':
      return `미세먼지나 초미세먼지가 나쁨 단계이니, ${eventTime} 외출한다면 보건용 마스크를 준비하세요`;
    case 'SHADE_BREAK':
      return (snapshot.uvIndex ?? 0) >= defaultRuleConfig.uv.highThreshold
        ? `자외선이 강할 수 있으니, ${eventTime} 외출한다면 양산이나 모자를 준비하세요`
        : `기온이 높거나 예상 체감온도가 높게 계산됐으니, ${eventTime} 외출한다면 물을 준비하세요`;
    case 'LAYER_READY':
      return `기온이 낮거나 예상 체감온도가 낮게 계산됐으니, ${eventTime} 외출한다면 겉옷을 준비하세요`;
    case 'STEADY_PACE':
      return `바람이 강할 수 있으니, ${eventTime} 외출한다면 소지품을 단단히 고정하세요`;
    case 'DAILY_RHYTHM':
      return '오늘은 외출 전에 시간별 예보를 확인하세요';
  }
}

function isSnowy(snapshot: WeatherSnapshot): boolean {
  return (
    snapshot.snowExpected === true ||
    snapshot.precipitationType === 'SNOW' ||
    snapshot.precipitationType === 'RAIN_SNOW'
  );
}

function isRainy(snapshot: WeatherSnapshot): boolean {
  return (
    (snapshot.precipitationProbability ?? 0) >=
      defaultRuleConfig.rain.minProbability ||
    snapshot.precipitationType === 'RAIN' ||
    snapshot.precipitationType === 'SHOWER'
  );
}

function hasPoorAirQuality(snapshot: WeatherSnapshot): boolean {
  const grade = (snapshot.airQualityGrade ?? '').toLowerCase();
  return (
    (snapshot.pm25 ?? 0) >= defaultRuleConfig.airQuality.pm25 ||
    (snapshot.pm10 ?? 0) >= defaultRuleConfig.airQuality.pm10 ||
    grade.includes('bad') ||
    grade.includes('나쁨')
  );
}
