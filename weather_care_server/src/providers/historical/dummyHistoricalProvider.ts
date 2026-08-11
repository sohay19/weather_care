import { HistoricalProvider, HistoricalWeather } from './historicalWeatherProvider';

export class DummyHistoricalProvider implements HistoricalProvider {
  async getByDate(_nx: number, _ny: number, targetDate: string): Promise<HistoricalWeather | null> {
    if (!targetDate) {
      return null;
    }
    return {
      observationDate: targetDate,
      temperature: 27.5,
      apparentTemperature: 30.0,
      pm10: 40,
      pm25: 22,
    };
  }
}

