import { WeatherSnapshot } from '../../types';

export interface WeatherProvider {
  getByRegion(nx: number, ny: number): Promise<WeatherSnapshot>;
}

