import { describe, expect, it } from 'vitest';
import type { DailyWeatherForecast } from '../src/providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../src/types';
import {
  buildThermalBrief,
  classifyThermalSensation,
  enrichSnapshotWithPerceivedTemperature,
  perceivedDifferenceBand,
  recentTemperatureContext,
} from '../src/thermal/perceivedTemperature';

describe('사람 중심 체감온도 v2', () => {
  it.each([
    [19.9, 'COOL_COMFORTABLE'], [20, 'COMFORTABLE'], [20.1, 'COMFORTABLE'],
    [23.9, 'COMFORTABLE'], [24, 'WARM_COMFORTABLE'], [24.1, 'WARM_COMFORTABLE'],
    [26.9, 'WARM_COMFORTABLE'], [27, 'WARM'], [27.1, 'WARM'],
    [27.9, 'WARM'], [28, 'WARM'], [28.1, 'WARM'],
    [28.9, 'WARM'], [29, 'SLIGHTLY_HOT'], [29.1, 'SLIGHTLY_HOT'],
    [35.9, 'HOT'], [36, 'VERY_HOT'], [36.1, 'VERY_HOT'],
    [42.9, 'VERY_HOT'], [43, 'EXTREME_HOT'], [43.1, 'EXTREME_HOT'],
  ])('%s℃를 %s 구간으로 분류한다', (value, expected) => {
    expect(classifyThermalSensation(value as number)).toBe(expected);
  });

  it('하강 시 0.3℃ 히스테리시스로 경계 문구 깜빡임을 줄인다', () => {
    expect(classifyThermalSensation(26.9, 'WARM')).toBe('WARM');
    expect(classifyThermalSensation(26.8, 'WARM')).toBe('WARM');
    expect(classifyThermalSensation(26.7, 'WARM')).toBe('WARM_COMFORTABLE');
    expect(classifyThermalSensation(27, 'WARM_COMFORTABLE')).toBe('WARM');
  });

  it.each([
    [0, 'NEAR'], [0.5, 'NEAR'], [0.6, 'SMALL'],
    [1.4, 'SMALL'], [1.5, 'MODERATE'], [2.9, 'MODERATE'],
    [3, 'CLEAR'], [4.9, 'CLEAR'], [5, 'LARGE'],
  ])('기온과 체감 차이 %s℃를 %s로 분류한다', (difference, expected) => {
    expect(perceivedDifferenceBand(20 + (difference as number), 20)).toBe(expected);
  });

  it('같은 입력 세트에서 습도·바람·복사열·강수 방향을 보존한다', () => {
    const neutral = perceived({ temperature: 25, humidity: 60, windSpeed: 1.5, skyCondition: '흐림' });
    const humidCalm = perceived({ temperature: 25, humidity: 90, windSpeed: 0.1, skyCondition: '흐림' });
    const dryWindy = perceived({ temperature: 25, humidity: 30, windSpeed: 4, skyCondition: '흐림' });
    const hotSunny = perceived({ temperature: 29, humidity: 90, windSpeed: 0.3, skyCondition: '맑음', uvIndex: 8 });
    const rainyWindy = perceived({
      temperature: 18,
      humidity: 90,
      windSpeed: 5,
      skyCondition: '흐림',
      precipitationType: 'RAIN',
      precipitationAmount: 5,
    });

    expect(humidCalm.perceivedTemperature!).toBeGreaterThan(neutral.perceivedTemperature!);
    expect(dryWindy.perceivedTemperature!).toBeLessThan(neutral.perceivedTemperature!);
    expect(hotSunny.perceivedTemperature!).toBeGreaterThan(hotSunny.temperature!);
    expect(hotSunny.dominantFactors).toContain('RADIATION');
    expect(rainyWindy.perceivedTemperature!).toBeLessThan(rainyWindy.temperature!);
    expect(rainyWindy.dominantFactors).toContain('PRECIPITATION');
  });

  it('최근 7일 기온에 따라 의복량과 적응 방향을 다르게 계산한다', () => {
    const spring = perceived(
      { temperature: 18, humidity: 60, windSpeed: 1, skyCondition: '흐림' },
      10,
    );
    const autumn = perceived(
      { temperature: 18, humidity: 60, windSpeed: 1, skyCondition: '흐림' },
      24,
    );

    expect(spring.estimatedClothingClo!).toBeGreaterThan(autumn.estimatedClothingClo!);
    expect(spring.temperatureTrend).toBe('WARMER_THAN_RECENT');
    expect(autumn.temperatureTrend).toBe('COLDER_THAN_RECENT');
    expect(spring.thermalBrief).toContain('최근보다 포근해져');
  });

  it('최근 실제 관측 4일 이상만 같은 관측소 출처와 함께 사용한다', () => {
    const context = recentTemperatureContext([
      observedDay('20260915', 10, 20, '108', 2.3),
      observedDay('20260916', 12, 22, '108', 2.3),
      observedDay('20260917', 14, 24, '108', 2.4),
      observedDay('20260918', 16, 26, '108', 2.4),
      { ...observedDay('20260919', 0, 40, '999', 30), forecastSource: 'KMA_SHORT_TERM' },
    ]);

    expect(context).toEqual({
      meanTemperature: 18,
      source: {
        stationId: '108',
        stationName: undefined,
        distanceKm: 2.4,
        coverageDays: 4,
        fromDate: '2026-09-15',
        toDate: '2026-09-18',
      },
    });
    expect(recentTemperatureContext([
      observedDay('20260915', 10, 20, '108', 2.3),
      observedDay('20260916', 12, 22, '108', 2.3),
      observedDay('20260917', 14, 24, '108', 2.4),
    ])).toBeUndefined();
  });

  it('필수 입력 일부가 없으면 관측 기반 기상청 값으로 명시적으로 fallback한다', () => {
    const result = enrichSnapshotWithPerceivedTemperature({
      observedAt: '2026-09-22T12:00:00+09:00',
      dataRole: 'OBSERVATION',
      temperature: 25,
      windSpeed: 1,
    }, context());

    expect(result.perceivedTemperature).toBe(25);
    expect(result.modelSource).toBe('KMA_FALLBACK_FROM_OBSERVATION');
    expect(result.perceivedConfidence).toBe('LOW');
    expect(result.thermalBrief).toContain('기온과 바람·습도를 중심으로');
  });

  it('0.1℃ 차이를 문장으로 과장하지 않고 같은 seed 문구를 고정한다', () => {
    const options = {
      regionKey: '57:125',
      at: '2026-09-22T12:00:00+09:00',
      thermalSensation: 'WARM_COMFORTABLE' as const,
      perceivedTemperature: 25.1,
      airTemperature: 25,
      dominantFactors: ['TEMPERATURE' as const],
      clothingLabel: 'LIGHT' as const,
    };
    const first = buildThermalBrief(options);
    const second = buildThermalBrief(options);

    expect(first).toBe(second);
    expect(first).not.toMatch(/0\.1|기온보다/);
    expect(first).not.toContain('조금 더워');
  });

  it('관측과 예보 입력 역할·위치를 필드별로 추적한다', () => {
    const observation = perceived({ temperature: 25, humidity: 60, windSpeed: 1 });
    const forecast = enrichSnapshotWithPerceivedTemperature({
      ...baseSnapshot(),
      dataRole: 'FORECAST',
      forecastAt: '2026-09-22T15:00:00+09:00',
      observedAt: '2026-09-22T15:00:00+09:00',
    }, context());

    expect(observation.sourceLocation).toEqual({
      type: 'GRID', nx: 57, ny: 125, locationMatch: 'EXACT_GRID',
    });
    expect(observation.fieldSources?.temperature).toMatchObject({
      role: 'OBSERVATION', field: 'T1H',
    });
    expect(observation.fieldSources?.sky?.role).toBe('FORECAST_PROXY');
    expect(forecast.fieldSources?.temperature).toMatchObject({
      role: 'FORECAST', field: 'TMP', forecastAt: '2026-09-22T15:00:00+09:00',
    });
    expect(forecast.modelSource).toBe('KR_PT_V2_FROM_FORECAST');
  });
});

function perceived(
  overrides: Partial<WeatherSnapshot>,
  recentMean = 22,
): WeatherSnapshot {
  return enrichSnapshotWithPerceivedTemperature(
    { ...baseSnapshot(), ...overrides },
    context(recentMean),
  );
}

function baseSnapshot(): WeatherSnapshot {
  return {
    observedAt: '2026-09-22T12:00:00+09:00',
    dataRole: 'OBSERVATION',
    temperature: 25,
    humidity: 60,
    windSpeed: 1.5,
    precipitationType: 'NONE',
    skyCondition: '흐림',
  };
}

function context(recentMean?: number) {
  return {
    regionKey: '57:125',
    latitude: 37.48,
    longitude: 126.82,
    now: new Date('2026-09-22T12:05:00+09:00'),
    recentTemperature: recentMean === undefined ? undefined : {
      meanTemperature: recentMean,
      source: {
        stationId: '108',
        distanceKm: 2.4,
        coverageDays: 7,
        fromDate: '2026-09-15',
        toDate: '2026-09-21',
      },
    },
  };
}

function observedDay(
  date: string,
  minTemperature: number,
  maxTemperature: number,
  stationId: string,
  observationDistanceKm: number,
): DailyWeatherForecast {
  return {
    date,
    forecastSource: 'KMA_OBSERVATION',
    minTemperature,
    maxTemperature,
    observationStationId: stationId,
    observationDistanceKm,
    skyCondition: '강수 관측 없음',
    precipitationProbability: 0,
    precipitationAmount: 0,
    snowProbability: 0,
    snowfallAmount: 0,
  };
}
