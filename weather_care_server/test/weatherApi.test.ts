import { describe, expect, it, vi } from 'vitest';
import router, {
  buildOptionalProviderTimeoutStatusMessages,
  buildTimeline,
  enrichWeeklyForecastDays,
  isFreshMainSnapshot,
  mergeWeeklyForecastDays,
  recommendationsForDay,
  settleWithin,
  weeklyCalendarDays,
} from '../src/api/weather';
import { KmaWeatherProvider } from '../src/providers/weather/kmaWeatherProvider';
import * as settingsRepository from '../src/database/notificationSettingsRepository';
import type { DailyWeatherForecast } from '../src/providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../src/types';
import {
  createExecutionContext,
  env,
  waitOnExecutionContext,
} from 'cloudflare:test';
import { authorizeFixture, testAuthHeaders } from './installationAuthFixture';
import * as environmental from '../src/providers/environmental/environmentalDataService';
import { KmaMidTermProvider } from '../src/providers/weather/kmaMidTermProvider';
import { seedCollectedRegion, seedCollectedWeekly } from './collectedWeatherFixture';

describe('fast Main weather', () => {
  it('returns KMA core weather without waiting for optional providers', async () => {
    const forecast = {
      current: snapshot(15),
      hourly: [snapshot(15), snapshot(18)],
      timelineHourly: [snapshot(15), snapshot(18)],
      daily: [day(28)],
      baseDate: '20260915',
      baseTime: '1400',
      dataSource: '기상청 단기예보',
    };
    const provider = vi.spyOn(
      KmaWeatherProvider.prototype,
      'getLatestForecastByRegion',
    ).mockResolvedValue(forecast);
    const optional = vi.spyOn(environmental, 'loadEnvironmentalData');
    try {
      await seedCollectedRegion(58, 124, forecast);
      const response = await router.request('/main?nx=58&ny=124', {}, {
        DB: env.DB,
      });
      const data = await response.json<{
        region: { nx: number; ny: number };
        current: WeatherSnapshot;
        hourly: WeatherSnapshot[];
      }>();

      expect(response.status).toBe(200);
      expect(data.region).toMatchObject({ nx: 58, ny: 124 });
      expect(data.current.temperature).toBe(24);
      expect(data.hourly).toEqual([]);
      expect(optional).not.toHaveBeenCalled();
      expect(provider).not.toHaveBeenCalled();
    } finally {
      provider.mockRestore();
      optional.mockRestore();
    }
  });

  it('uses cached Main weather only inside its short freshness window', () => {
    const now = new Date('2026-09-15T06:00:00Z');
    expect(isFreshMainSnapshot({
      ...snapshot(15),
      forecastAt: '2026-09-15T15:00:00+09:00',
      fetchedAt: '2026-09-15T05:30:00Z',
    }, now)).toBe(true);
    expect(isFreshMainSnapshot({
      ...snapshot(15),
      forecastAt: '2026-09-15T13:00:00+09:00',
      fetchedAt: '2026-09-15T04:00:00Z',
    }, now)).toBe(false);
  });
});

describe('weekly calendar date contract', () => {
  it('adds only date-matched UV and air-quality fields to weekly days', () => {
    const enriched = enrichWeeklyForecastDays(
      [{ ...day(25), date: '20260915' }, { ...day(27), date: '20260916' }],
      {
        areaNo: '4111356000',
        issuedAt: '2026-09-15T09:00:00+09:00',
        provider: 'KMA_LIVING_INDEX_V5',
        points: [
          { forecastAt: '2026-09-15T09:00:00+09:00', uvIndex: 4 },
          { forecastAt: '2026-09-15T12:00:00+09:00', uvIndex: 7 },
        ],
      },
      [{ date: '20260916', pm25Grade: '낮음', confidence: '높음' }],
    );

    expect(enriched[0]).toMatchObject({ maximumUvIndex: 7 });
    expect(enriched[0].airQualityForecast).toBeUndefined();
    expect(enriched[1]).toMatchObject({
      airQualityForecast: { pm25Grade: '낮음', confidence: '높음' },
    });
    expect(enriched[1].maximumUvIndex).toBeUndefined();
  });

  it('uses short-term days first, fills later dates from mid-term, and keeps saved past records', () => {
    const short = {
      ...day(25),
      date: '20260915',
      forecastSource: 'KMA_SHORT_TERM' as const,
      minTemperatureSource: 'DAILY' as const,
      maxTemperatureSource: 'DAILY' as const,
    };
    const mid = { ...day(27), date: '20260919', forecastSource: 'KMA_MID_TERM' as const };
    const merged = mergeWeeklyForecastDays([short], [
      { ...mid, date: '20260915' },
      mid,
    ]);
    expect(merged).toEqual([short, mid]);

    expect(mergeWeeklyForecastDays([
      {
        ...short,
        date: '20260919',
        minTemperatureSource: 'HOURLY',
        maxTemperatureSource: 'HOURLY',
      },
    ], [mid])).toEqual([mid]);

    const recorded = {
      ...day(21),
      date: '20260913',
      recordedAt: '2026-09-12T21:00:00.000Z',
    };
    expect(weeklyCalendarDays(
      merged,
      [],
      [recorded],
      ['2026-09-13', '2026-09-15', '2026-09-19'],
      '2026-09-15',
    )).toEqual([
      { ...recorded, historical: true },
      { ...short, historical: false },
      { ...mid, historical: false },
    ]);

    const observed = {
      ...day(20),
      date: '20260913',
      forecastSource: 'KMA_OBSERVATION' as const,
    };
    expect(weeklyCalendarDays(
      merged,
      [observed],
      [recorded],
      ['2026-09-13'],
      '2026-09-15',
    )).toEqual([{ ...observed, historical: true }]);
  });

  it('filters disabled recommendations before selecting the first three and exposes coverage metadata', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-08-20T01:00:00Z'));
    await authorizeFixture('test');
    const settings = { ...settingsRepository.defaultNotificationSettings('test'), umbrellaEnabled: false, parasolEnabled: false };
    const hourly = [snapshot(14, { temperature: 35, apparentTemperature: 38, humidity: 85, uvIndex: 9, pm25: 90,
      precipitationProbability: 90, precipitationAmount: 10, precipitationType: 'RAIN' })];
    const forecastDay = { ...day(35), weatherDataComplete: false, minTemperatureSource: 'HOURLY' as const, maxTemperatureSource: 'DAILY' as const };
    const expected = recommendationsForDay(forecastDay, hourly, settings).filter((r) => r.recommended).slice(0, 3);
    expect(expected).toHaveLength(3);
    expect(recommendationsForDay(forecastDay, hourly, settings).slice(0, 3).some((r) => !r.recommended)).toBe(true);
    const provider = vi.spyOn(KmaWeatherProvider.prototype, 'getForecastByRegion').mockResolvedValue({
      current: hourly[0], hourly, daily: [forecastDay], baseDate: '20260820', baseTime: '1100', dataSource: '기상청',
    });
    const savedSettings = vi.spyOn(settingsRepository, 'getNotificationSettings').mockResolvedValue(settings);
    try {
      await seedCollectedWeekly(60, 121, {
        forecast: {
          current: hourly[0], hourly, daily: [forecastDay], baseDate: '20260820',
          baseTime: '1100', dataSource: '기상청',
        },
        midTermDays: [],
        observedDays: [],
        airQuality: [],
      });
      const response = await router.request('/weekly?nx=60&ny=121&installationId=test', { headers: testAuthHeaders }, { DB: env.DB, KMA_SERVICE_KEY: 'test-key' });
      expect(response.status).toBe(200);
      expect(await response.json()).toMatchObject({ days: [{
        weatherDataComplete: false, minTemperatureSource: 'HOURLY', maxTemperatureSource: 'DAILY',
        recommendations: expected.map(({ type, recommended }) => ({ type, recommended })),
      }] });
    } finally {
      provider.mockRestore();
      savedSettings.mockRestore();
      vi.useRealTimers();
    }
  });
  it.each([
    ['20260910', '2026-09-10', '목'],
    ['20261231', '2026-12-31', '목'],
    ['20270101', '2027-01-01', '금'],
  ])('adds the exact forecast date without replacing the legacy weekday (%s)', async (date, forecastDate, weekday) => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(`${forecastDate}T01:00:00Z`));
    const provider = vi.spyOn(KmaWeatherProvider.prototype, 'getForecastByRegion')
      .mockResolvedValue({
        current: snapshot(14),
        hourly: [],
        daily: [{ ...day(28), date }],
        baseDate: '20260910',
        baseTime: '1100',
        dataSource: '기상청',
      });
    try {
      await seedCollectedWeekly(60, 121, {
        forecast: {
          current: snapshot(14),
          hourly: [],
          daily: [{ ...day(28), date }],
          baseDate: '20260910',
          baseTime: '1100',
          dataSource: '기상청',
        },
        midTermDays: [],
        observedDays: [],
        airQuality: [],
      });
      const response = await router.request('/weekly?nx=60&ny=121', {}, {
        DB: env.DB,
      });
      expect(response.status).toBe(200);
      expect(await response.json()).toMatchObject({
        regionId: '60_121',
        days: [{ date: weekday, forecastDate, min: '22', max: '28' }],
      });
      expect(provider).not.toHaveBeenCalled();
    } finally {
      provider.mockRestore();
      vi.useRealTimers();
    }
  });
});

describe('weekly provider independence', () => {
  it('returns mid-term days even when the short-term provider fails', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-09-13T03:00:00Z'));
    const short = vi.spyOn(KmaWeatherProvider.prototype, 'getForecastByRegion')
      .mockRejectedValue(new Error('short unavailable'));
    const midDay = {
      ...day(24),
      date: '20260917',
      forecastSource: 'KMA_MID_TERM' as const,
    };
    const mid = vi.spyOn(KmaMidTermProvider.prototype, 'getForecast')
      .mockResolvedValue([midDay]);
    try {
      await seedCollectedWeekly(58, 124, {
        forecast: undefined,
        midTermDays: [midDay],
        observedDays: [],
        airQuality: [],
      });
      const response = await router.request(
        '/weekly?nx=58&ny=124&regionName=%EC%8B%9C%ED%9D%A5%EC%8B%9C',
        {},
        { DB: env.DB, KMA_SERVICE_KEY: 'short-key', KMA_APIHUB_KEY: 'hub-key' },
      );
      expect(response.status).toBe(200);
      expect(await response.json()).toMatchObject({
        dataSource: '기상청 중기예보',
        days: [{ forecastDate: '2026-09-17', forecastSource: 'KMA_MID_TERM' }],
      });
    } finally {
      short.mockRestore();
      mid.mockRestore();
      vi.useRealTimers();
    }
  });

  it('returns an honest empty week when both forecast providers fail', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-09-13T03:00:00Z'));
    const short = vi.spyOn(KmaWeatherProvider.prototype, 'getForecastByRegion')
      .mockRejectedValue(new Error('short unavailable'));
    const mid = vi.spyOn(KmaMidTermProvider.prototype, 'getForecast')
      .mockRejectedValue(new Error('mid unavailable'));
    try {
      await seedCollectedWeekly(58, 124, {
        forecast: undefined,
        midTermDays: [],
        observedDays: [],
        airQuality: [],
      });
      const response = await router.request(
        '/weekly?nx=58&ny=124&regionName=%EC%8B%9C%ED%9D%A5%EC%8B%9C',
        {},
        { DB: env.DB, KMA_SERVICE_KEY: 'short-key', KMA_APIHUB_KEY: 'hub-key' },
      );
      expect(response.status).toBe(200);
      expect(await response.json()).toMatchObject({
        dataSource: '기상청 자료 없음',
        days: [],
      });
    } finally {
      short.mockRestore();
      mid.mockRestore();
      vi.useRealTimers();
    }
  });
});

describe('weekly recommendation inputs', () => {
  it('uses hourly apparent temperature instead of treating the daily maximum as apparent', () => {
    const hotAirOnly = recommendationsForDay(day(35), [
      snapshot(14, { temperature: 35, apparentTemperature: 30 }),
    ]);
    expect(hotAirOnly.map((item) => item.type)).not.toContain('WATER');

    const highApparent = recommendationsForDay(day(30), [
      snapshot(14, { temperature: 30, apparentTemperature: 35 }),
    ]);
    expect(highApparent.map((item) => item.type)).toContain('WATER');
  });

  it('marks disabled preparation recommendations as not recommended', () => {
    const recommendations = recommendationsForDay(day(24), [
      snapshot(14, {
        precipitationType: 'RAIN',
        precipitationProbability: 90,
        precipitationAmount: 5,
      }),
      snapshot(15, {
        precipitationType: 'RAIN',
        precipitationProbability: 90,
        precipitationAmount: 5,
      }),
    ], {
      umbrellaEnabled: false,
    });

    expect(recommendations.find((item) => item.type === 'UMBRELLA')).toMatchObject({
      recommended: false,
    });
  });
});

describe('today timeline', () => {
  it('uses retained early hours while keeping the detail forecast current-first', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-08-20T09:30:00+09:00'));
    const hourly = [snapshot(9), snapshot(12)];
    const timelineHourly = [3, 6, 9, 12, 15, 18, 21, 24].map((hour) =>
      snapshot(hour),
    );
    const provider = vi.spyOn(
      KmaWeatherProvider.prototype,
      'getForecastByRegion',
    ).mockResolvedValue({
      current: hourly[0],
      hourly,
      timelineHourly,
      daily: [day(28)],
      baseDate: '20260820',
      baseTime: '0800',
      dataSource: '기상청',
    });
    const environmentalLoader = vi.spyOn(
      environmental,
      'loadEnvironmentalData',
    ).mockResolvedValue({
      sources: {
        uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNAVAILABLE' },
        airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' },
      },
    });
    const ctx = createExecutionContext();

    try {
      await seedCollectedRegion(60, 121, {
        current: hourly[0],
        hourly,
        timelineHourly,
        daily: [day(28)],
        baseDate: '20260820',
        baseTime: '0800',
        dataSource: '기상청',
      });
      const response = await router.request(
        '/today?nx=60&ny=121',
        {},
        { DB: env.DB },
        ctx,
      );
      const data = await response.json<{
        hourly: WeatherSnapshot[];
        timeline: ReturnType<typeof buildTimeline>;
      }>();

      expect(response.status).toBe(200);
      expect(data.hourly.map((item) => item.observedAt.slice(11, 13))).toEqual([
        '09',
        '12',
      ]);
      expect(data.timeline[0].detail).toBe('예상기온 24.0℃ / 맑음');
      expect(data.timeline[1].detail).toBe('예상기온 24.0℃ / 맑음');
      await waitOnExecutionContext(ctx);
    } finally {
      provider.mockRestore();
      environmentalLoader.mockRestore();
      vi.useRealTimers();
    }
  });

  it('shows eight points from 03:00 through next-day midnight', () => {
    const timeline = buildTimeline(
      Array.from({ length: 22 }, (_, index) => snapshot(3 + index)),
    );

    expect(timeline.map((item) => item.timeLabel)).toEqual([
      '03',
      '06',
      '09',
      '12',
      '15',
      '18',
      '21',
      '24',
    ]);
    expect(timeline[0]).toMatchObject({
      stateLabel: '맑은 하늘이 이어져요',
      detail: '예상기온 24.0℃ / 맑음',
    });
    expect(timeline[7]).toMatchObject({
      stateLabel: '맑은 하늘이 이어져요',
      detail: '예상기온 24.0℃ / 맑음',
    });
  });

  it('uses weather, temperature, wind, and humidity titles when no item is recommended', () => {
    const timeline = buildTimeline([
      snapshot(3, { temperature: 20, skyCondition: '맑음' }),
      snapshot(6, { temperature: 17, skyCondition: '맑음' }),
      snapshot(9, { temperature: 21, skyCondition: '맑음' }),
      snapshot(12, { temperature: 21, windSpeed: 10, skyCondition: '맑음' }),
      snapshot(15, { temperature: 24, skyCondition: '맑음' }),
      snapshot(18, { temperature: 20, skyCondition: '맑음' }),
      snapshot(21, { temperature: 20, skyCondition: '구름많음' }),
      snapshot(24, { temperature: 20, skyCondition: '흐림' }),
    ]);

    expect(timeline.map((item) => item.stateLabel)).toEqual([
      '맑은 하늘이 이어져요',
      '오늘 가장 쌀쌀한 시간이에요',
      '기온이 크게 오르는 시간이에요',
      '바람이 강하게 불어요',
      '오늘 가장 따뜻한 시간이에요',
      '기온이 크게 내려가는 시간이에요',
      '구름이 많은 날씨예요',
      '흐린 날씨가 이어져요',
    ]);
  });

  it('shows humidity and low-probability precipitation titles without a recommendation', () => {
    const humid = buildTimeline([
      snapshot(15, { humidity: 85, skyCondition: '맑음' }),
    ]);
    const precipitation = buildTimeline([
      snapshot(15, {
        precipitationProbability: 20,
        precipitationType: 'NONE',
      }),
    ]);

    expect(humid[4].stateLabel).toBe('습도가 높은 시간이에요');
    expect(precipitation[4].stateLabel).toBe('강수 가능성이 있어요');
  });

  it('keeps all eight slots and marks unavailable target slots honestly', () => {
    const timeline = buildTimeline([snapshot(15)]);

    expect(timeline.map((item) => item.timeLabel)).toEqual([
      '03',
      '06',
      '09',
      '12',
      '15',
      '18',
      '21',
      '24',
    ]);
    expect(timeline[0]).toMatchObject({
      stateLabel: '시간별 예보를 확인하세요',
      detail: '예상기온 자료 없음 / 날씨 자료 없음',
      recommendations: [],
    });
    expect(timeline[4].detail).toBe('예상기온 24.0℃ / 맑음');
    expect(timeline[7].detail).toBe('예상기온 자료 없음 / 날씨 자료 없음');
  });

  it.each([
    {
      name: 'rain',
      overrides: {
        precipitationType: 'RAIN' as const,
        precipitationProbability: 80,
        precipitationAmount: 3,
      },
      expected: '오후 2시~3시 강수 예보 · 강수확률 80%',
    },
    {
      name: 'snow',
      overrides: {
        precipitationType: 'SNOW' as const,
        precipitationProbability: 60,
        snowProbability: 60,
        snowExpected: true,
        snowfallAmount: 1,
      },
      expected: '오후 2시~3시 강설 예보 · 강수확률 60%',
    },
  ])('adds a separate second line only for a $name forecast', ({
    overrides,
    expected,
  }) => {
    const timeline = buildTimeline([
      snapshot(15, {
        ...overrides,
        precipitationPeriod: {
          start: '2026-08-20T14:00:00+09:00',
          end: '2026-08-20T15:00:00+09:00',
        },
      }),
    ]);

    expect(timeline[4].detail).toBe(
      `예상기온 24.0℃ / 맑음\n${expected}`,
    );
  });
});

describe('today optional provider deadline', () => {
  it('returns a provider result that arrives within the deadline', async () => {
    await expect(settleWithin(Promise.resolve('ready'), 'fallback', 3_500))
      .resolves.toEqual({ value: 'ready', timedOut: false });
  });

  it('returns the fallback when the provider exceeds the deadline', async () => {
    vi.useFakeTimers();
    try {
      const result = settleWithin(
        new Promise<string>(() => undefined),
        'fallback',
        3_500,
      );

      await vi.advanceTimersByTimeAsync(3_500);

      await expect(result).resolves.toEqual({
        value: 'fallback',
        timedOut: true,
      });
    } finally {
      vi.useRealTimers();
    }
  });

  it('explains only the optional data that missed the deadline', () => {
    expect(
      buildOptionalProviderTimeoutStatusMessages({
        precipitation: true,
        warning: false,
        roadIce: false,
        roadControl: true,
      }),
    ).toEqual([
      {
        role: 'DATA_STATUS',
        text: '자료를 받아오지 못해 현재 강수 상태를 확인하기 어려워요',
        source: '기상청 관측분석자료·기상청 레이더',
      },
      {
        role: 'DATA_STATUS',
        text: '자료를 받아오지 못해 현재 도로 통제 상태를 확인하기 어려워요',
        source: '국가교통정보센터 돌발상황정보',
      },
    ]);
  });
});

function day(maxTemperature: number): DailyWeatherForecast {
  return {
    date: '20260820',
    minTemperature: 22,
    maxTemperature,
    skyCondition: '맑음',
    precipitationProbability: 0,
    precipitationAmount: 0,
    snowProbability: 0,
    snowfallAmount: 0,
  };
}

function snapshot(
  hour: number,
  overrides: Partial<WeatherSnapshot> = {},
): WeatherSnapshot {
  const date = hour === 24 ? '2026-08-21' : '2026-08-20';
  const normalizedHour = hour % 24;
  const time = `${date}T${String(normalizedHour).padStart(2, '0')}:00:00+09:00`;
  return {
    observedAt: time,
    forecastAt: time,
    validFrom: time,
    validTo: `${date}T${String(normalizedHour).padStart(2, '0')}:59:59+09:00`,
    temperature: 24,
    apparentTemperature: 24,
    humidity: 60,
    windSpeed: 2,
    precipitationType: 'NONE',
    precipitationProbability: 0,
    precipitationAmount: 0,
    snowfallAmount: 0,
    skyCondition: '맑음',
    ...overrides,
  };
}
