import { WeatherSnapshot } from '../../types';

export interface DailyWeatherForecast {
  date: string;
  minTemperature?: number;
  maxTemperature?: number;
  minTemperatureSource?: 'DAILY' | 'HOURLY';
  maxTemperatureSource?: 'DAILY' | 'HOURLY';
  /** Completeness of the received slots, not a guarantee of 24-hour coverage. */
  weatherDataComplete?: boolean;
  skyCondition: string;
  precipitationProbability: number;
  precipitationAmount: number;
  snowProbability: number;
  snowfallAmount: number;
}

export interface WeatherForecast {
  current: WeatherSnapshot;
  hourly: WeatherSnapshot[];
  daily: DailyWeatherForecast[];
  baseDate: string;
  baseTime: string;
  dataSource: string;
}

export interface WeatherProvider {
  getForecastByRegion(nx: number, ny: number): Promise<WeatherForecast>;
}
