import { WeatherSnapshot } from '../../types';
import { WeatherProvider } from './weatherProvider';

export class DummyWeatherProvider implements WeatherProvider {
  async getByRegion(): Promise<WeatherSnapshot> {
    return {
      observedAt: new Date().toISOString(),
      temperature: 29.5,
      apparentTemperature: 32.1,
      minTemperature: 22,
      maxTemperature: 33,
      humidity: 58,
      windSpeed: 2.4,
      precipitationProbability: 65,
      precipitationAmount: 10,
      snowProbability: 5,
      snowfallAmount: 0,
      uvIndex: 7,
      skyCondition: 'Cloudy',
      pm10: 33,
      pm25: 18,
      airQualityGrade: 'Moderate',
    };
  }
}

