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
  heat: {
    actionAirTemperature: number;
    actionApparentTemperature: number;
    immediateActionApparentTemperature: number;
    releaseApparentTemperature: number;
    warmNightTemperature: number;
  };
  cold: {
    temperature: number;
    apparentTemperature: number;
    diurnalRange: number;
    apparentGap: number;
  };
  wind: { caution: number; high: number };
  airQuality: { pm10: number; pm25: number; gradeBad: string[] };
  humidity: { high: number; low: number };
  series: { generalSlots: number };
}

export const defaultRuleConfig: RuleConfig = {
  rain: {
    minProbability: 40,
    minAmount: 0.5,
    heavyProbability: 70,
    heavyAmount: 15,
    instantHeavyAmount: 30,
  },
  snow: {
    minAmount: 0,
    heavyHourlyAmount: 5,
    heavyThreeHourAmount: 5,
  },
  uv: { highThreshold: 6, veryHighThreshold: 8 },
  heat: {
    actionAirTemperature: 33,
    actionApparentTemperature: 33,
    immediateActionApparentTemperature: 35,
    releaseApparentTemperature: 31,
    warmNightTemperature: 25,
  },
  cold: {
    temperature: 12,
    apparentTemperature: 10,
    diurnalRange: 8,
    apparentGap: 4,
  },
  wind: { caution: 9, high: 14 },
  airQuality: { pm10: 81, pm25: 36, gradeBad: ['Bad', 'Very Bad'] },
  humidity: { high: 80, low: 35 },
  series: { generalSlots: 2 },
};

// TODO: 운영 임계값 운영 콘피그 테이블/KV로 이동 예정
