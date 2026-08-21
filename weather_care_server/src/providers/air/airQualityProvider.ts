export interface AirQualitySnapshot {
  observedAt: string;
  stationName: string;
  pm10?: number;
  pm25?: number;
  airQualityGrade?: string;
  ozone?: number;
  ozoneGrade?: string;
  provider: 'AIRKOREA';
}

export interface AirQualityProvider {
  getByRegion(
    nx: number,
    ny: number,
    stationName?: string,
  ): Promise<AirQualitySnapshot>;
}
