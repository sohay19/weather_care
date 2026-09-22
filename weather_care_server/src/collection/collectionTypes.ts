import type { EnvironmentalDataBundle } from '../providers/environmental/environmentalDataService';
import type { DailyAirQualityForecastAtDate } from '../providers/air/airKoreaForecastProvider';
import type { OfficialWeatherWarning } from '../providers/warnings/kmaWarningProvider';
import type { DailyWeatherForecast, WeatherForecast } from '../providers/weather/weatherProvider';
import type { UvForecast } from '../providers/uv/uvProvider';

export interface CollectedWarningBundle {
  warnings: OfficialWeatherWarning[];
  regionName?: string;
}

export interface CollectedWeeklyBundle {
  forecast?: WeatherForecast;
  midTermDays: DailyWeatherForecast[];
  observedDays: DailyWeatherForecast[];
  uv?: UvForecast;
  airQuality: DailyAirQualityForecastAtDate[];
  midTermIssue?: string;
  midTermTaRegId?: string;
  midTermLandRegId?: string;
  uvIssue?: string;
  airQualityIssue?: string;
  collectedAt: string;
}

export interface CollectedRegionBundle {
  forecast: WeatherForecast;
  environmental: EnvironmentalDataBundle;
}

export interface CollectionTarget {
  nx: number;
  ny: number;
  latitude?: number;
  longitude?: number;
}
