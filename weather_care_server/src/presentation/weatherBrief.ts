import type { WeatherForecast } from '../providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../types';
import { defaultRuleConfig } from '../config/ruleConfig';
import {
  WEATHER_BRIEF_SLOT_OPTIONS,
  WEATHER_BRIEF_TEMPLATES,
  type WeatherBriefScene,
  type WeatherBriefSlotKey,
  type WeatherBriefTemplate,
} from './weatherBriefCatalog';

export const WEATHER_BRIEF_CATALOG_VERSION = 'weather-brief-2026.08.1';
const HEAT_SENSATION_SCENE_THRESHOLD = 28;
const COLD_LAYER_SCENE_THRESHOLD = 8;

export const DIRECT_WEATHER_EXPRESSION_PATTERN =
  /기온|온도|날씨|맑음|흐림|구름|강수|습도|풍속|자외선|초?미세먼지|(?:^|\s)비가\s|비 오는|비 내|(?:^|\s)눈이\s|눈 오는|눈 내|\d+(?:\.\d+)?\s*°/;

export interface WeatherBriefContext {
  regionKey?: string;
  dateKey?: string;
}

export interface WeatherBriefResult {
  text: string;
  scene: WeatherBriefScene;
  templateId: string;
  slots: Readonly<Partial<Record<WeatherBriefSlotKey, string>>>;
  catalogVersion: string;
}

interface SceneSelection {
  scene: WeatherBriefScene;
  eventAt: string;
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
  const selection = selectScene(forecast);
  const dateKey = context.dateKey ?? forecast.baseDate;
  const regionKey = context.regionKey ?? 'default-region';
  const seed = `${regionKey}|${selection.scene}`;
  const rotation = dayRotation(dateKey);
  const templates = WEATHER_BRIEF_TEMPLATES.filter(
    (template) => template.scene === selection.scene,
  );
  const templatePool =
    templates.length > 0 ? templates : [WEATHER_BRIEF_TEMPLATES[0]];
  const template =
    templatePool[
      (stableIndex(`${seed}|template`, templatePool.length) + rotation) %
        templatePool.length
    ];
  const slots = selectSlots(template, selection.eventAt, seed, rotation);

  return {
    text: renderTemplate(template, slots),
    scene: selection.scene,
    templateId: template.id,
    slots,
    catalogVersion: WEATHER_BRIEF_CATALOG_VERSION,
  };
}

function selectScene(forecast: WeatherForecast): SceneSelection {
  const candidates = [forecast.current, ...forecast.hourly.slice(0, 24)];

  const snowy = candidates.find(isSnowy);
  if (snowy) {
    return { scene: 'CAREFUL_STEPS', eventAt: snowy.observedAt };
  }

  const rainy = candidates.find(isRainy);
  if (rainy) {
    return { scene: 'WET_TRAVEL', eventAt: rainy.observedAt };
  }

  const poorAir = candidates.find(hasPoorAirQuality);
  if (poorAir) {
    return { scene: 'MASK_READY', eventAt: poorAir.observedAt };
  }

  const strongExposure = candidates.find(
    (item) =>
      apparentTemperature(item) >= HEAT_SENSATION_SCENE_THRESHOLD ||
      (item.uvIndex ?? 0) >= defaultRuleConfig.uv.highThreshold,
  );
  if (strongExposure) {
    return { scene: 'SHADE_BREAK', eventAt: strongExposure.observedAt };
  }

  const layerUseful = candidates.find(
    (item) => apparentTemperature(item) <= COLD_LAYER_SCENE_THRESHOLD,
  );
  if (layerUseful) {
    return { scene: 'LAYER_READY', eventAt: layerUseful.observedAt };
  }

  const steadyPace = candidates.find(
    (item) => (item.windSpeed ?? 0) >= defaultRuleConfig.wind.caution,
  );
  if (steadyPace) {
    return { scene: 'STEADY_PACE', eventAt: steadyPace.observedAt };
  }

  return {
    scene: 'DAILY_RHYTHM',
    eventAt: forecast.current.observedAt,
  };
}

function selectSlots(
  template: WeatherBriefTemplate,
  eventAt: string,
  seed: string,
  rotation: number,
): Partial<Record<WeatherBriefSlotKey, string>> {
  const selected: Partial<Record<WeatherBriefSlotKey, string>> = {};
  for (const slot of template.slots) {
    const options = WEATHER_BRIEF_SLOT_OPTIONS[slot];
    const index =
      slot === 'eventTime'
        ? timeSlotIndex(eventAt)
        : (stableIndex(`${seed}|${template.id}|${slot}`, options.length) +
            rotation) %
          options.length;
    selected[slot] = options[index];
  }
  return selected;
}

function renderTemplate(
  template: WeatherBriefTemplate,
  slots: Partial<Record<WeatherBriefSlotKey, string>>,
): string {
  let rendered = template.text;
  for (const slot of template.slots) {
    rendered = rendered.replaceAll(`{${slot}}`, slots[slot] ?? '');
  }
  return rendered.replace(/\s+/g, ' ').trim();
}

function stableIndex(seed: string, length: number): number {
  let hash = 2166136261;
  for (let index = 0; index < seed.length; index += 1) {
    hash ^= seed.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0) % Math.max(1, length);
}

function dayRotation(dateKey: string): number {
  const match = dateKey.match(/^(\d{4})(\d{2})(\d{2})$/);
  if (!match) return 0;
  const timestamp = Date.UTC(
    Number(match[1]),
    Number(match[2]) - 1,
    Number(match[3]),
  );
  return Math.floor(timestamp / 86_400_000);
}

function timeSlotIndex(observedAt: string): number {
  const match = observedAt.match(/T(\d{2}):/);
  const hour = match ? Number(match[1]) : 12;
  if (hour < 6) return 0;
  if (hour < 8) return 1;
  if (hour < 10) return 2;
  if (hour < 12) return 3;
  if (hour < 14) return 4;
  if (hour < 16) return 5;
  if (hour < 18) return 6;
  if (hour < 20) return 7;
  if (hour < 22) return 8;
  return 9;
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

function apparentTemperature(snapshot: WeatherSnapshot): number {
  return snapshot.apparentTemperature ?? snapshot.temperature;
}
