import { AirQualityProvider, AirQualitySnapshot } from './airQualityProvider';

export class DummyAirQualityProvider implements AirQualityProvider {
  async getByRegion(_nx: number, _ny: number): Promise<AirQualitySnapshot> {
    return {
      pm10: 33,
      pm25: 18,
      airQualityGrade: 'Moderate',
    };
  }
}
