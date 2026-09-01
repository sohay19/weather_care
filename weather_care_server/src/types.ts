export type RecommendationType =
  | 'UMBRELLA'
  | 'PARASOL'
  | 'HEAVY_SNOW_CAUTION'
  | 'OUTERWEAR'
  | 'MASK'
  | 'WATER'
  | 'SUNSCREEN';

export enum WeatherRuleFactType {
  RAIN_LIKELY = 'RAIN_LIKELY',
  HEAVY_RAIN = 'HEAVY_RAIN',
  SNOW_LIKELY = 'SNOW_LIKELY',
  HEAVY_SNOW = 'HEAVY_SNOW',
  UV_HIGH = 'UV_HIGH',
  TEMPERATURE_HIGH = 'TEMPERATURE_HIGH',
  APPARENT_TEMPERATURE_HIGH = 'APPARENT_TEMPERATURE_HIGH',
  TEMPERATURE_LOW = 'TEMPERATURE_LOW',
  WIND_CHILL_HIGH = 'WIND_CHILL_HIGH',
  HUMIDITY_HIGH = 'HUMIDITY_HIGH',
  AIR_QUALITY_BAD = 'AIR_QUALITY_BAD',
  PM10_HIGH = 'PM10_HIGH',
  PM25_HIGH = 'PM25_HIGH',
  LARGE_DIURNAL_RANGE = 'LARGE_DIURNAL_RANGE',
  COLD_STRESS_RISK = 'COLD_STRESS_RISK',
  STRONG_WIND = 'STRONG_WIND',
  RAPID_TEMPERATURE_DROP = 'RAPID_TEMPERATURE_DROP',
  HUMIDITY_LOW = 'HUMIDITY_LOW',
  WARM_HUMID_NIGHT_FORECAST = 'WARM_HUMID_NIGHT_FORECAST',
}

export enum LifestyleInsightType {
  RAIN_GEAR_USEFUL = 'RAIN_GEAR_USEFUL',
  STRONG_SUN_EXPOSURE = 'STRONG_SUN_EXPOSURE',
  OUTERWEAR_USEFUL = 'OUTERWEAR_USEFUL',
  MASK_USEFUL = 'MASK_USEFUL',
  HYDRATION_IMPORTANT = 'HYDRATION_IMPORTANT',
  SUNSCREEN_USEFUL = 'SUNSCREEN_USEFUL',
  SNOW_TRAVEL_CAUTION = 'SNOW_TRAVEL_CAUTION',
  VERY_HOT_AND_HUMID = 'VERY_HOT_AND_HUMID',
  COOLER_THAN_TEMPERATURE = 'COOLER_THAN_TEMPERATURE',
  LARGE_TEMPERATURE_SWING = 'LARGE_TEMPERATURE_SWING',
  OUTDOOR_ACTIVITY_CAUTION = 'OUTDOOR_ACTIVITY_CAUTION',
  RAIN_BREAK_WINDOW = 'RAIN_BREAK_WINDOW',
  BEST_OUTING_WINDOW = 'BEST_OUTING_WINDOW',
  PET_WALK_WINDOW = 'PET_WALK_WINDOW',
  WET_ROAD_CAUTION = 'WET_ROAD_CAUTION',
  LAUNDRY_PICKUP_DUE = 'LAUNDRY_PICKUP_DUE',
  WINDOW_CLOSE_SOON = 'WINDOW_CLOSE_SOON',
  RAPID_TEMPERATURE_DROP = 'RAPID_TEMPERATURE_DROP',
  NIGHT_WEATHER_CHECK = 'NIGHT_WEATHER_CHECK',
}

export type PrecipitationType =
  | 'NONE'
  | 'RAIN'
  | 'RAIN_SNOW'
  | 'SNOW'
  | 'SHOWER';

export type AmountRangeType =
  | 'NONE'
  | 'VALUE'
  | 'LESS_THAN'
  | 'RANGE'
  | 'AT_LEAST';

export interface AmountRange {
  type: AmountRangeType;
  min?: number;
  max?: number;
  unit: 'MM' | 'CM';
  rawValue: string;
}

export interface WeatherWarning {
  type: string;
  level?: string;
  validFrom?: string;
  validUntil?: string;
  provider: string;
}

export interface WeatherSnapshot {
  observedAt: string;
  dataRole?: 'FORECAST' | 'OBSERVATION' | 'ANALYSIS';
  forecastAt?: string;
  validFrom?: string;
  validTo?: string;
  issuedAt?: string;
  fetchedAt?: string;
  temperature?: number;
  apparentTemperature?: number;
  apparentTemperatureSource?:
    | 'APP_KMA_METHOD_FROM_FORECAST'
    | 'APP_KMA_METHOD_FROM_OBSERVATION'
    | 'OFFICIAL_KMA_VALUE';
  apparentTemperatureFormulaVersion?: string;
  minTemperature?: number;
  maxTemperature?: number;
  humidity?: number;
  windSpeed?: number;
  windDirection?: number;
  precipitationType?: PrecipitationType;
  precipitationProbability?: number;
  /** 이전 앱과의 호환을 위한 보수적 하한값 */
  precipitationAmount?: number;
  precipitationAmountRange?: AmountRange;
  /** 이전 앱과의 호환을 위한 PTY 기반 파생값 */
  snowProbability?: number;
  snowExpected?: boolean;
  snowfallAmount?: number;
  snowfallAmountRange?: AmountRange;
  uvIndex?: number;
  skyCondition?: string;
  pm10?: number;
  pm25?: number;
  airQualityStationName?: string;
  airQualityObservedAt?: string;
  airQualityGrade?: string;
  ozone?: number;
  ozoneGrade?: string;
  airStagnationIndex?: number;
  pollenRisk?: string;
  freezeRisk?: string;
  activeWarnings?: WeatherWarning[];
  provider?: string;
  providerField?: string;
  rawValue?: Record<string, string>;
  qualityFlags?: string[];
}

export interface WeatherRuleFact {
  type: WeatherRuleFactType;
  severity: number;
  evidence: Record<string, string | number | boolean>;
  validFrom?: string;
  validUntil?: string;
}

export interface LifestyleInsight {
  type: LifestyleInsightType;
  score: number;
  sourceFacts: WeatherRuleFactType[];
  context?: Record<string, unknown>;
}

export interface Recommendation {
  type: RecommendationType;
  recommended: boolean;
  priority: number;
  title: string;
  description: string;
  reasonCodes: string[];
  validFrom?: string;
  validUntil?: string;
  notificationEligible: boolean;
  reasons?: string[];
  sourceFields?: string[];
  actionDeadline?: string;
  providerRefs?: string[];
  decisionVersion?: string;
  catalogVersion?: string;
}

export interface NotificationSettings {
  installationId: string;
  notificationEnabled: boolean;
  notificationTime: string;
  umbrellaEnabled: boolean;
  parasolEnabled: boolean;
  heavySnowEnabled: boolean;
  outerwearEnabled: boolean;
  maskEnabled: boolean;
  waterEnabled: boolean;
  sunscreenEnabled: boolean;
  dailyWeatherEnabled: boolean;
  heavyRainEnabled: boolean;
  heatwaveEnabled: boolean;
  coldWaveEnabled: boolean;
  showerAndLightRainEnabled: boolean;
}

export interface Installation {
  installationId: string;
  fcmToken?: string;
  nx: number;
  ny: number;
  regionTopic: string;
  locationMode: 'GPS' | 'MANUAL';
  platform?: string;
  appVersion?: string;
  timezone: string;
}

export type ServerEnv = CloudflareBindings;

export type EnvironmentalSourceState =
  | 'AVAILABLE'
  | 'CACHED'
  | 'STALE'
  | 'UNAVAILABLE'
  | 'UNSUPPORTED_REGION';

export interface EnvironmentalSourceStatus {
  provider: string;
  state: EnvironmentalSourceState;
  observedAt?: string;
  cachedAt?: string;
  reason?: 'PROVIDER_UNAVAILABLE' | 'UNSUPPORTED_REGION';
}

export type WeatherMessageRole =
  | 'APP_SUGGESTION'
  | 'INTERNAL_POSSIBILITY'
  | 'OFFICIAL_FACT'
  | 'CALCULATED_FACT'
  | 'DATA_STATUS';

export interface WeatherMessagePart {
  role: WeatherMessageRole;
  text: string;
  source?: string;
  validFrom?: string;
  validUntil?: string;
}

export interface TodayWeatherResponse {
  dataSource: string;
  region: { nx: number; ny: number; name: string };
  brief: string;
  current: WeatherSnapshot;
  hourly: WeatherSnapshot[];
  recommendations: Recommendation[];
  lifestyleMessages: {
    type: LifestyleInsightType;
    title: string;
    description?: string;
    priority: number;
    parts: WeatherMessagePart[];
  }[];
  dataStatusMessages: WeatherMessagePart[];
  timeline: {
    timeLabel: string;
    stateLabel: string;
    detail: string;
    recommendations: Recommendation[];
  }[];
  environmentalSources: {
    uv: EnvironmentalSourceStatus;
    airQuality: EnvironmentalSourceStatus;
  };
  decisionVersion?: string;
  catalogVersion?: string;
  generatedAt?: string;
}
