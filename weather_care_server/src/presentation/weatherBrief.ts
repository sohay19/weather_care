import type { WeatherForecast } from '../providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../types';
import { defaultRuleConfig } from '../config/ruleConfig';
import { precipitationDecisionSnapshot, precipitationLabel, koreanHour } from '../rules/precipitationWindows';

export const WEATHER_BRIEF_CATALOG_VERSION = 'weather-brief-2026.09.2';
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
}

export interface WeatherBriefResult {
  text: string;
  scene: WeatherBriefScene;
  templateId: string;
  slots: Readonly<{ eventTime?: string }>;
  catalogVersion: string;
}

interface SceneSelection {
  scene: WeatherBriefScene;
  snapshot: WeatherSnapshot;
}

export function buildWeatherBrief(
  forecast: WeatherForecast,
  context: WeatherBriefContext = {},
): string {
  return buildWeatherBriefResult(forecast, context).text;
}

export function buildWeatherBriefResult(
  forecast: WeatherForecast,
  _context: WeatherBriefContext = {},
): WeatherBriefResult {
  const selection = selectScene(forecast);
  const eventTime = ['CAREFUL_STEPS', 'WET_TRAVEL'].includes(selection.scene)
    ? precipitationLabel(selection.snapshot)
    : koreanHour(selection.snapshot.forecastAt ?? selection.snapshot.observedAt);
  return {
    text: messageFor(selection, eventTime),
    scene: selection.scene,
    templateId: `policy-${selection.scene.toLowerCase()}`,
    slots: { eventTime },
    catalogVersion: WEATHER_BRIEF_CATALOG_VERSION,
  };
}

function selectScene(forecast: WeatherForecast): SceneSelection {
  const candidates = [forecast.current, ...forecast.hourly.slice(0, 24)]
    .map((item) => precipitationDecisionSnapshot(item));

  const snowy = candidates.find(isSnowy);
  if (snowy) return { scene: 'CAREFUL_STEPS', snapshot: snowy };

  const rainy = candidates.find(isRainy);
  if (rainy) return { scene: 'WET_TRAVEL', snapshot: rainy };

  const poorAir = candidates.find(hasPoorAirQuality);
  if (poorAir) return { scene: 'MASK_READY', snapshot: poorAir };

  const strongExposure = candidates.find(
    (item) =>
      (item.apparentTemperature ?? -Infinity) >=
        defaultRuleConfig.heat.actionApparentTemperature ||
      (item.temperature ?? -Infinity) >=
        defaultRuleConfig.heat.actionAirTemperature ||
      (item.uvIndex ?? 0) >= defaultRuleConfig.uv.highThreshold,
  );
  if (strongExposure) {
    return { scene: 'SHADE_BREAK', snapshot: strongExposure };
  }

  const layerUseful = candidates.find(
    (item) =>
      (item.temperature ?? Infinity) <= defaultRuleConfig.cold.temperature ||
      (item.apparentTemperature ?? Infinity) <=
        defaultRuleConfig.cold.apparentTemperature,
  );
  if (layerUseful) return { scene: 'LAYER_READY', snapshot: layerUseful };

  const strongWind = candidates.find(
    (item) => (item.windSpeed ?? 0) >= defaultRuleConfig.wind.caution,
  );
  if (strongWind) return { scene: 'STEADY_PACE', snapshot: strongWind };

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
