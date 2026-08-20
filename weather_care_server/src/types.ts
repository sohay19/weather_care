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
}

export interface WeatherSnapshot {
  observedAt: string;
  temperature?: number;
  apparentTemperature?: number;
  minTemperature?: number;
  maxTemperature?: number;
  humidity?: number;
  windSpeed?: number;
  precipitationProbability?: number;
  precipitationAmount?: number;
  snowProbability?: number;
  snowfallAmount?: number;
  uvIndex?: number;
  skyCondition?: string;
  pm10?: number;
  pm25?: number;
  airQualityGrade?: string;
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
}

export interface TodayWeatherResponse {
  region: { nx: number; ny: number; name: string };
  brief: string;
  current: WeatherSnapshot;
  hourly: WeatherSnapshot[];
  recommendations: Recommendation[];
  lifestyleMessages: { type: LifestyleInsightType; title: string; description?: string }[];
  timeline: {
    timeLabel: string;
    stateLabel: string;
    detail: string;
    recommendations: Recommendation[];
  }[];
}
