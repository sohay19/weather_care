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
  LAUNDRY_DRYING_GOOD = 'LAUNDRY_DRYING_GOOD',
  LARGE_DIURNAL_RANGE = 'LARGE_DIURNAL_RANGE',
  ICY_ROAD_RISK = 'ICY_ROAD_RISK',
  COLD_STRESS_RISK = 'COLD_STRESS_RISK',
  STRONG_WIND = 'STRONG_WIND',
  RAPID_TEMPERATURE_DROP = 'RAPID_TEMPERATURE_DROP',
  SLEEP_DISCOMFORT_EXPECTED = 'SLEEP_DISCOMFORT_EXPECTED',
  VENTILATION_GOOD = 'VENTILATION_GOOD',
  HUMIDITY_LOW = 'HUMIDITY_LOW',
}

export enum LifestyleInsightType {
  RAIN_GEAR_USEFUL = 'RAIN_GEAR_USEFUL',
  STRONG_SUN_EXPOSURE = 'STRONG_SUN_EXPOSURE',
  OUTERWEAR_USEFUL = 'OUTERWEAR_USEFUL',
  MASK_USEFUL = 'MASK_USEFUL',
  HYDRATION_IMPORTANT = 'HYDRATION_IMPORTANT',
  SUNSCREEN_USEFUL = 'SUNSCREEN_USEFUL',
  SNOW_TRAVEL_CAUTION = 'SNOW_TRAVEL_CAUTION',
  LAUNDRY_GOOD = 'LAUNDRY_GOOD',
  VERY_HOT_AND_HUMID = 'VERY_HOT_AND_HUMID',
  COOLER_THAN_TEMPERATURE = 'COOLER_THAN_TEMPERATURE',
  LARGE_TEMPERATURE_SWING = 'LARGE_TEMPERATURE_SWING',
  OUTDOOR_ACTIVITY_CAUTION = 'OUTDOOR_ACTIVITY_CAUTION',
  VENTILATION_GOOD = 'VENTILATION_GOOD',
  COMMUTE_WEATHER_CHANGE = 'COMMUTE_WEATHER_CHANGE',
  RAIN_BREAK_WINDOW = 'RAIN_BREAK_WINDOW',
  BEST_OUTING_WINDOW = 'BEST_OUTING_WINDOW',
  PET_WALK_WINDOW = 'PET_WALK_WINDOW',
  COMMUTE_RISK = 'COMMUTE_RISK',
  WET_ROAD_CAUTION = 'WET_ROAD_CAUTION',
  CAR_WASH_SCORE = 'CAR_WASH_SCORE',
  LAUNDRY_PICKUP_DUE = 'LAUNDRY_PICKUP_DUE',
  INDOOR_DRYING_PREFERRED = 'INDOOR_DRYING_PREFERRED',
  VENTILATION_WINDOW = 'VENTILATION_WINDOW',
  WINDOW_CLOSE_SOON = 'WINDOW_CLOSE_SOON',
  DEHUMIDIFIER_USEFUL = 'DEHUMIDIFIER_USEFUL',
  HUMIDIFIER_USEFUL = 'HUMIDIFIER_USEFUL',
  UMBRELLA_DRYING_REMINDER = 'UMBRELLA_DRYING_REMINDER',
  ALLERGY_CAUTION = 'ALLERGY_CAUTION',
  RESPIRATORY_CAUTION = 'RESPIRATORY_CAUTION',
  SLEEP_DISCOMFORT_EXPECTED = 'SLEEP_DISCOMFORT_EXPECTED',
  VEHICLE_FROST_RISK = 'VEHICLE_FROST_RISK',
  FREEZE_CAUTION = 'FREEZE_CAUTION',
  RAPID_TEMPERATURE_DROP = 'RAPID_TEMPERATURE_DROP',
  DAILY_WEATHER_CHECK = 'DAILY_WEATHER_CHECK',
  DAILY_HYDRATION = 'DAILY_HYDRATION',
  FLEXIBLE_DAY_PLAN = 'FLEXIBLE_DAY_PLAN',
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
  forecastAt?: string;
  validFrom?: string;
  validTo?: string;
  issuedAt?: string;
  fetchedAt?: string;
  temperature?: number;
  apparentTemperature?: number;
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
  level?: 'NONE' | 'INFO' | 'CAUTION' | 'WARNING' | 'DANGER';
  score?: number;
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

export interface ServerEnv {
  DB: any;
  APP_ORIGIN?: string;
  KMA_SERVICE_KEY?: string;
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
    score: number;
  }[];
  timeline: {
    timeLabel: string;
    stateLabel: string;
    detail: string;
    recommendations: Recommendation[];
  }[];
  decisionVersion?: string;
  catalogVersion?: string;
  generatedAt?: string;
}
