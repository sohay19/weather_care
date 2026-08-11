export interface AirQualitySnapshot {
  pm10: number;
  pm25: number;
  airQualityGrade: string;
}

export interface AirQualityProvider {
  getByRegion(nx: number, ny: number): Promise<AirQualitySnapshot>;
}

