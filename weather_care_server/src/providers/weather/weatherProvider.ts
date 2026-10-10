import { WeatherSnapshot } from '../../types';

export interface DailyPrecipitationDetail {
  kind: 'HOURLY' | 'EXTENDED' | 'OBSERVATION';
  /** Original one-hour PCP/POP values. forecastAt is the END of the interval. */
  hours: { forecastAt: string; probability?: number; amountText?: string }[];
  /** Extended forecasts are not quantitative hourly PCP; never sum their codes. */
  extendedMaxProbability?: number;
  /** Actual daily rainfall at the nearest available KMA station. */
  observedAmount?: number;
}

export interface DailyAirQualityForecast {
  pm10Grade?: string;
  pm25Grade?: string;
  ozoneGrade?: string;
  yellowDustMentioned?: boolean;
  confidence?: '높음' | '낮음';
}

export interface DailyWeatherForecast {
  date: string;
  forecastSource?: 'KMA_SHORT_TERM' | 'KMA_MID_TERM' | 'KMA_OBSERVATION';
  issuedAt?: string;
  recordedAt?: string;
  historical?: boolean;
  observationStationId?: string;
  observationStationName?: string;
  observationDistanceKm?: number;
  minTemperature?: number;
  maxTemperature?: number;
  minTemperatureSource?: 'DAILY' | 'HOURLY';
  maxTemperatureSource?: 'DAILY' | 'HOURLY';
  averageHumidity?: number;
  maximumWindSpeed?: number;
  maximumUvIndex?: number;
  snowfallDataAvailable?: boolean;
  observationAvailability?: Partial<Record<'minTemperature' | 'maxTemperature' | 'precipitationAmount' | 'snowfallAmount',
    'AVAILABLE' | 'NO_RECORD' | 'UNAVAILABLE'>>;
  airQualityForecast?: DailyAirQualityForecast;
  /** Completeness of the received slots, not a guarantee of 24-hour coverage. */
  weatherDataComplete?: boolean;
  precipitationDetail?: DailyPrecipitationDetail;
  skyCondition: string;
  precipitationProbability: number;
  precipitationAmount: number;
  snowProbability: number;
  /** Forecast new snowfall; KMA_OBSERVATION uses daily maximum new snow depth (sd_day_max). Never current total snow depth. */
  snowfallAmount: number;
}

export interface WeatherForecast {
  current: WeatherSnapshot;
  hourly: WeatherSnapshot[];
  /** Current Korean day's slots retained for fixed-time timeline rendering. */
  timelineHourly?: WeatherSnapshot[];
  daily: DailyWeatherForecast[];
  baseDate: string;
  baseTime: string;
  dataSource: string;
}

export interface WeatherProvider {
  getForecastByRegion(nx: number, ny: number): Promise<WeatherForecast>;
}
