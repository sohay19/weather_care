export type RecommendationType =
  | 'UMBRELLA'
  | 'RAINCOAT'
  | 'RAIN_BOOTS'
  | 'PARASOL'
  | 'SUNGLASSES'
  | 'HEAVY_SNOW_CAUTION'
  | 'OUTERWEAR'
  | 'SCARF'
  | 'HAND_WARMER'
  | 'MASK'
  | 'WATER'
  | 'PORTABLE_FAN'
  | 'COOLING_ITEM'
  | 'SUNSCREEN'
  | 'SNOW_CHAINS'
  | 'POWER_BANK'
  | 'WINTER_BOOTS';

export type BriefingSceneId =
  | 'OFFICIAL_WARNING'
  | 'CURRENT_PRECIPITATION'
  | 'HEAVY_RAIN'
  | 'SNOW'
  | 'ROAD_ICE'
  | 'ROAD_CONTROL'
  | 'RAIN'
  | 'UV'
  | 'AIR_QUALITY'
  | 'OZONE'
  | 'VISIBILITY'
  | 'THERMAL_HOT'
  | 'THERMAL_COLD'
  | 'THERMAL_COMFORTABLE'
  | 'THERMAL_CHANGE'
  | 'WIND'
  | 'HUMIDITY_HIGH'
  | 'HUMIDITY_LOW'
  | 'CLEAR_COMFORTABLE'
  | 'DEFAULT';

export type BriefingScope =
  | 'CURRENT'
  | 'NEAR_FUTURE'
  | 'TODAY'
  | 'TOMORROW'
  | 'EVENT';

export interface BriefingCopy {
  short: string;
  medium: string;
  long: string;
  notificationTitle: string;
  notificationBody: string;
}

export interface CanonicalBriefingIntent {
  briefingId: string;
  locationKey: string;
  sceneId: BriefingSceneId;
  topic: string;
  scope: BriefingScope;
  severity: 'INFO' | 'MODERATE' | 'HIGH' | 'CRITICAL';
  confidence: 'HIGH' | 'MEDIUM' | 'LOW';
  targetFrom?: string;
  targetUntil?: string;
  validFrom: string;
  validUntil: string;
  nextBriefingBoundary?: string;
  dataRole?: 'FORECAST' | 'OBSERVATION' | 'ANALYSIS';
  observedAt?: string;
  forecastAt?: string;
  issuedAt?: string;
  sourceLocation?: WeatherSnapshot['sourceLocation'];
  qualityFlags: string[];
  evidenceFields: string[];
  headlineFact: string;
  supportingFact?: string;
  action?: string;
  recommendedItems: RecommendationType[];
  copyVariantKey: string;
  copy: BriefingCopy;
}

export interface BriefingTimelineEntry {
  briefingId: string;
  sceneId: BriefingSceneId;
  validFrom: string;
  validUntil: string;
  targetFrom?: string;
  targetUntil?: string;
  action?: string;
  recommendedItems: RecommendationType[];
  copyVariantKey: string;
  copy: BriefingCopy;
}

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
  OZONE_HIGH = 'OZONE_HIGH',
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
  OZONE_CAUTION = 'OZONE_CAUTION',
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
  BLACK_ICE_CAUTION = 'BLACK_ICE_CAUTION',
  COMMUTE_ROUTE_CAUTION = 'COMMUTE_ROUTE_CAUTION',
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
  typeCode?: string;
  level?: string;
  levelCode?: string;
  commandCode?: string;
  regionId?: string;
  regionName?: string;
  announcedAt?: string;
  validFrom?: string;
  validUntil?: string;
  provider: string;
}

export interface WeatherSnapshot {
  observedAt: string;
  dataRole?: 'FORECAST' | 'OBSERVATION' | 'ANALYSIS';
  forecastAt?: string;
  // PCP/POP/PTY/SNO: preceding hour, end exclusive. Null means unsupported
  // (e.g. extended qualitative forecast); absent preserves legacy providers.
  precipitationPeriod?: { start: string; end: string } | null;
  validFrom?: string;
  validTo?: string;
  issuedAt?: string;
  fetchedAt?: string;
  temperature?: number;
  apparentTemperature?: number;
  apparentTemperatureSource?:
    | 'APP_KMA_METHOD_FROM_FORECAST'
    | 'APP_STEADMAN_FROM_FORECAST'
    | 'APP_STEADMAN_FROM_OBSERVATION'
    | 'APP_KMA_METHOD_FROM_OBSERVATION'
    | 'OFFICIAL_KMA_VALUE';
  apparentTemperatureFormulaVersion?: string;
  /** 기상청 계절별 산식 결과. apparentTemperature는 구버전 호환 별칭이다. */
  kmaApparentTemperature?: number;
  dataAgeMinutes?: number;
  sourceLocation?: {
    type: 'GRID' | 'STATION';
    nx?: number;
    ny?: number;
    stationId?: string;
    stationName?: string;
    distanceKm?: number;
    locationMatch: 'EXACT_GRID' | 'NEAREST_STATION' | 'NEAREST_GRID';
    distanceBasis?: 'GPS' | 'GRID_CENTER';
  };
  fieldSources?: Partial<Record<
    'temperature' | 'humidity' | 'windSpeed' | 'sky',
    {
      role: 'OBSERVATION' | 'FORECAST' | 'FORECAST_PROXY';
      field: string;
      observedAt?: string;
      forecastAt?: string;
    }
  >>;
  recentTemperatureSource?: {
    stationId?: string;
    stationName?: string;
    distanceKm?: number;
    coverageDays: number;
    fromDate: string;
    toDate: string;
  };
  minTemperature?: number;
  maxTemperature?: number;
  humidity?: number;
  windSpeed?: number;
  windDirection?: number;
  /** 가장 가까운 기상청 ASOS 관측소의 수평 시정 */
  visibilityMeters?: number;
  visibilityObservedAt?: string;
  visibilityStationId?: string;
  visibilityStationDistanceKm?: number;
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
  /** 해당 예보일의 에어코리아 초미세먼지 통보 등급 */
  pm25ForecastGrade?: string;
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
  minimumAgeConfirmed: true;
  agePolicyVersion: 1;
  fcmToken?: string;
  nx: number;
  ny: number;
  regionTopic: string;
  locationMode: 'GPS' | 'MANUAL';
  platform?: string;
  appVersion?: string;
  timezone: string;
  latitude?: number;
  longitude?: number;
}

export type PrecipitationConsensusState = 'RAIN' | 'DRY' | 'MISMATCH';

export interface CurrentPrecipitationObservation {
  observedAt: string;
  latitude: number;
  longitude: number;
  analysisRainDetected: boolean;
  radarRainDetected: boolean;
  state: PrecipitationConsensusState;
  radarDbz?: number;
  provider: 'KMA_ANALYSIS_RADAR';
}

export interface RoadIceRisk {
  producedAt: string;
  roadNumber: string;
  roadName: string;
  linkId: string;
  level: 1 | 2 | 3;
  levelLabel: '관심' | '주의' | '위험';
  sourceType: 'ANALYSIS' | 'OBSERVATION';
  fromLatitude: number;
  fromLongitude: number;
  toLatitude: number;
  toLongitude: number;
  distanceMeters: number;
  provider: '기상청 도로살얼음 발생 가능 정보';
}

export interface OfficialRoadControl {
  eventKey: string;
  startedAt: string;
  endsAt?: string;
  roadName?: string;
  direction?: string;
  controlKind: 'FULL' | 'PARTIAL';
  lanesBlocked?: string;
  eventType: string;
  eventDetailType?: string;
  message: string;
  linkId?: string;
  latitude: number;
  longitude: number;
  distanceMeters: number;
  provider: '국가교통정보센터 돌발상황정보';
}

export interface RateLimitBinding {
  limit(options: { key: string }): Promise<{ success: boolean }>;
}

export type ServerEnv = {
  DB: D1Database;
  INSTALLATION_ENROLL_LIMIT: RateLimitBinding;
  ANALYTICS_DELETION_LIMIT: RateLimitBinding;
  APP_ORIGIN: string;
  FCM_PROJECT_ID: string;
  GA_PROPERTY_ID: string;
  KMA_SERVICE_KEY: string;
  KMA_APIHUB_KEY: string;
  FCM_CLIENT_EMAIL: string;
  FCM_PRIVATE_KEY: string;
  GA_ADMIN_CLIENT_EMAIL: string;
  GA_ADMIN_PRIVATE_KEY: string;
  /** 구버전 앱의 workers.dev 요청을 미니 PC로 넘기는 전환기 전용 주소 */
  LEGACY_ORIGIN_URL?: string;
  /** Operational gate stored outside the database; any non-off value blocks. */
  RECOVERY_MODE?: string;
  /** Node 중앙 수집기가 앱 지원 전국 격자를 순환 선수집할지 여부 */
  NATIONWIDE_PRECOLLECT_ENABLED?: string;
  /** 국가교통정보센터 돌발상황정보 직접조회 인증키 */
  ITS_API_KEY?: string;
};

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
  reason?: 'PROVIDER_UNAVAILABLE' | 'UNSUPPORTED_REGION' | 'LOCATION_UNRESOLVED' | 'LOCATION_COORDINATES_REQUIRED' | 'UPSTREAM_AREA_MISSING';
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
  /** 독립 자료 상태를 Detail에서 묶어 표시할 항목 제목 */
  itemTitle?: string;
  source?: string;
  validFrom?: string;
  validUntil?: string;
  /** false이면 재요청으로 해결되지 않는 제공기간·지원범위 상태 */
  retryable?: boolean;
}

export interface TodayWeatherResponse {
  dataSource: string;
  region: { nx: number; ny: number; name: string };
  brief: string;
  /** Exclusive deadline for displaying the time-sensitive Main brief. */
  briefExpiresAt?: string;
  /** 모든 앱·위젯·요약 알림이 공유하는 대표 날씨 의미. */
  briefing: CanonicalBriefingIntent;
  /** 외부 재조회 없이 시간 경계에서 위젯 문구를 교체하기 위한 목록. */
  briefingTimeline: BriefingTimelineEntry[];
  sunriseAt?: string;
  sunsetAt?: string;
  current: WeatherSnapshot;
  /** First hourly forecast whose valid time is later than generatedAt. */
  nextForecast: WeatherSnapshot;
  currentPrecipitation?: CurrentPrecipitationObservation;
  currentRoadIce?: RoadIceRisk;
  currentRoadControl?: OfficialRoadControl;
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

export interface CurrentVisibilityObservation {
  observedAt: string;
  stationId: string;
  distanceKm: number;
  visibilityMeters: number;
  provider: 'KMA_ASOS';
}
