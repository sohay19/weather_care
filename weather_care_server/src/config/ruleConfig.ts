export interface RuleConfig {
  rain: {
    minProbability: number;
    minAmount: number;
    heavyProbability: number;
    heavyAmount: number;
    instantHeavyAmount: number;
  };
  snow: {
    minAmount: number;
    heavyHourlyAmount: number;
    heavyThreeHourAmount: number;
  };
  uv: { highThreshold: number; veryHighThreshold: number };
  heat: { apparentTemperature: number; instantApparentTemperature: number };
  cold: {
    temperature: number;
    apparentTemperature: number;
    diurnalRange: number;
    apparentGap: number;
  };
  wind: { caution: number; high: number };
  airQuality: { pm10: number; pm25: number; gradeBad: string[] };
  laundry: {
    maxProbability: number;
    maxHumidity: number;
    minWind: number;
    maxWind: number;
  };
  humidity: { high: number; low: number };
  series: { generalSlots: number; laundrySlots: number };
}

export const defaultRuleConfig: RuleConfig = {
  rain: {
    minProbability: 40,
    minAmount: 0.5,
    heavyProbability: 70,
    heavyAmount: 5,
    instantHeavyAmount: 10,
  },
  snow: {
    minAmount: 0,
    heavyHourlyAmount: 1,
    heavyThreeHourAmount: 3,
  },
  uv: { highThreshold: 6, veryHighThreshold: 8 },
  heat: { apparentTemperature: 33, instantApparentTemperature: 35 },
  cold: {
    temperature: 12,
    apparentTemperature: 10,
    diurnalRange: 8,
    apparentGap: 4,
  },
  wind: { caution: 6, high: 9 },
  airQuality: { pm10: 80, pm25: 55, gradeBad: ['Bad', 'Very Bad'] },
  laundry: { maxProbability: 20, maxHumidity: 75, minWind: 1, maxWind: 6 },
  humidity: { high: 80, low: 35 },
  series: { generalSlots: 2, laundrySlots: 3 },
};

// TODO: 운영 임계값 운영 콘피그 테이블/KV로 이동 예정
