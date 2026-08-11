export interface RuleConfig {
  rain: { minProbability: number; heavyThreshold: number };
  snow: { minProbability: number; heavyThreshold: number };
  uv: { highThreshold: number };
  heat: { apparentTemperature: number };
  cold: { temperature: number; windChill: number; diurnalRange: number };
  airQuality: { pm10: number; pm25: number; gradeBad: string[] };
  laundry: { maxPrecipitation: number; maxHumidity: number; minSun: number; maxWind: number };
}

export const defaultRuleConfig: RuleConfig = {
  rain: { minProbability: 40, heavyThreshold: 70 },
  snow: { minProbability: 35, heavyThreshold: 65 },
  uv: { highThreshold: 6 },
  heat: { apparentTemperature: 33 },
  cold: { temperature: 12, windChill: 8, diurnalRange: 8 },
  airQuality: { pm10: 80, pm25: 55, gradeBad: ['Bad', 'Very Bad'] },
  laundry: { maxPrecipitation: 2, maxHumidity: 75, minSun: 4, maxWind: 6 },
};

// TODO: 운영 임계값 운영 콘피그 테이블/KV로 이동 예정

