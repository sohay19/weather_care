export interface UvForecastPoint {
  forecastAt: string;
  uvIndex: number;
}

export interface UvForecast {
  areaNo: string;
  issuedAt: string;
  points: UvForecastPoint[];
  provider: 'KMA_LIVING_INDEX_V5';
}

export interface UvProvider {
  getForecast(areaNo: string): Promise<UvForecast>;
}
