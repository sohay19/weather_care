export interface HistoricalWeather {
  observationDate: string;
  temperature: number;
  apparentTemperature: number;
  pm10?: number;
  pm25?: number;
}

export interface HistoricalProvider {
  getByDate(nx: number, ny: number, targetDate: string): Promise<HistoricalWeather | null>;
}

