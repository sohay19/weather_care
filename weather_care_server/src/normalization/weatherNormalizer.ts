import { WeatherSnapshot } from '../types';

export interface RawWeatherPayload {
  [key: string]: unknown;
}

export class WeatherNormalizer {
  static normalize(payload: RawWeatherPayload): WeatherSnapshot {
    const safe = (key: string): number | undefined => {
      const v = (payload as any)[key];
      if (typeof v === 'number') return v;
      if (typeof v === 'string') {
        const n = Number(v);
        return Number.isFinite(n) ? n : undefined;
      }
      return undefined;
    };
    return {
      observedAt: new Date().toISOString(),
      temperature: safe('temperature'),
      apparentTemperature: safe('apparentTemperature'),
      minTemperature: safe('minTemperature'),
      maxTemperature: safe('maxTemperature'),
      humidity: safe('humidity'),
      windSpeed: safe('windSpeed'),
      precipitationProbability: safe('precipitationProbability'),
      precipitationAmount: safe('precipitationAmount'),
      snowProbability: safe('snowProbability'),
      snowfallAmount: safe('snowfallAmount'),
      uvIndex: safe('uvIndex'),
      skyCondition: typeof payload.skyCondition === 'string' ? (payload.skyCondition as string) : undefined,
      pm10: safe('pm10'),
      pm25: safe('pm25'),
      airQualityGrade: typeof payload.airQualityGrade === 'string' ? (payload.airQualityGrade as string) : undefined,
    };
  }
}

