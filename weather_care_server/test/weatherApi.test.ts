import { describe, expect, it, vi } from 'vitest';
import router, {
  buildCurrentOptionalDataStatusMessages,
  buildOptionalProviderTimeoutStatusMessages,
  buildTimeline,
  currentFromUltraShortObservation,
  enrichWeeklyForecastDays,
  forecastForCurrentHour,
  isFreshMainSnapshot,
  mergeWeeklyForecastDays,
  nextForecastSnapshot,
  recommendationsForDay,
  settleWithin,
  weeklyCalendarDays,
} from '../src/api/weather';
import { KmaWeatherProvider } from '../src/providers/weather/kmaWeatherProvider';
import * as settingsRepository from '../src/database/notificationSettingsRepository';
import type { DailyWeatherForecast } from '../src/providers/weather/weatherProvider';
import type { CanonicalBriefingIntent, WeatherSnapshot } from '../src/types';
import {
  createExecutionContext,
  env,
  waitOnExecutionContext,
} from 'cloudflare:test';
import { authorizeFixture, testAuthHeaders } from './installationAuthFixture';
import * as environmental from '../src/providers/environmental/environmentalDataService';
import { buildEnvironmentalDataStatusMessages } from '../src/presentation/lifestyleMessages';
import { KmaMidTermProvider } from '../src/providers/weather/kmaMidTermProvider';
import {
  seedCollectedRegion,
  seedCollectedUltraShortObservation,
  seedCollectedWeekly,
} from './collectedWeatherFixture';

describe('fast Main weather', () => {
  it('returns KMA core weather without waiting for optional providers', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-08-20T15:35:00+09:00'));
    const forecast = {
      current: snapshot(14, { temperature: 21 }),
      hourly: [
        snapshot(14, { temperature: 21 }),
        snapshot(15),
        snapshot(18, { temperature: 28 }),
      ],
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
      await seedCollectedWeekly(58, 124, {
        forecast,
        midTermDays: [],
        observedDays: [],
        airQuality: [
          {
            date: '20260820',
            pm25Grade: '보통',
          },
        ],
      });
      await seedCollectedUltraShortObservation(58, 124, {
        observedAt: '2026-08-20T15:20:00+09:00',
        rainDetected: false,
        precipitationTypeCode: 0,
        temperature: 26,
        humidity: 60,
        windSpeed: 2,
        windDirection: 180,
        provider: 'KMA_APIHUB_GRID_OBSERVATION',
        sourceLocation: {
          type: 'GRID', nx: 58, ny: 124, locationMatch: 'EXACT_GRID',
        },
      });
      const response = await router.request('/main?nx=58&ny=124', {}, {
        DB: env.DB,
      });
      const data = await response.json<{
        region: { nx: number; ny: number };
        brief: string;
        briefing: CanonicalBriefingIntent;
        current: WeatherSnapshot;
        nextForecast: WeatherSnapshot;
        hourly: WeatherSnapshot[];
      }>();

      expect(response.status).toBe(200);
      expect(response.headers.get('Cache-Control')).toBe('no-store');
      expect(data.region).toMatchObject({ nx: 58, ny: 124 });
      expect(data.current).toMatchObject({
        observedAt: '2026-08-20T15:20:00+09:00',
        dataRole: 'OBSERVATION',
        temperature: 26,
        humidity: 60,
        windSpeed: 2,
        windDirection: 180,
        provider: 'KMA_APIHUB_GRID_OBSERVATION+KMA_FORECAST',
        providerField: 'T1H,REH,WSD,VEC,PTY,RN1;SKY=FORECAST',
      });
      expect(data.current.forecastAt).toBeUndefined();
      expect(data.current.apparentTemperatureSource)
        .toBe('APP_KMA_METHOD_FROM_OBSERVATION');
      expect(data.current.kmaApparentTemperature)
        .toBe(data.current.apparentTemperature);
      expect(data.current).toMatchObject({
        sourceLocation: {
          type: 'GRID', nx: 58, ny: 124, locationMatch: 'EXACT_GRID',
        },
      });
      expect(data.current).not.toHaveProperty('perceivedTemperature');
      expect(data.current).not.toHaveProperty('thermalSensation');
      expect(data.current).not.toHaveProperty('thermalBrief');
      expect(data.briefing).toMatchObject({
        sceneId: 'THERMAL_COMFORTABLE',
        dataRole: 'OBSERVATION',
        observedAt: '2026-08-20T15:20:00+09:00',
      });
      expect(data.brief).toBe(data.briefing.copy.medium);
      expect(data.nextForecast).toMatchObject({
        forecastAt: '2026-08-20T18:00:00+09:00',
        temperature: 28,
        kmaApparentTemperature: 24,
        pm25ForecastGrade: '보통',
      });
      expect(data.hourly).toEqual([]);
      expect(optional).not.toHaveBeenCalled();
      expect(provider).not.toHaveBeenCalled();
    } finally {
      provider.mockRestore();
      optional.mockRestore();
      vi.useRealTimers();
    }
  });

  it('keeps the grid observation after the full Today response replaces Main', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-08-20T15:35:00+09:00'));
    const forecast = {
      current: snapshot(14, { temperature: 21 }),
      hourly: [snapshot(15), snapshot(18)],
      timelineHourly: [snapshot(15), snapshot(18)],
      daily: [day(28)],
      baseDate: '20260820',
      baseTime: '1400',
      dataSource: '기상청 단기예보',
    };
    const ctx = createExecutionContext();
    try {
      await seedCollectedRegion(59, 125, forecast);
      await seedCollectedUltraShortObservation(59, 125, {
        observedAt: '2026-08-20T15:20:00+09:00',
        rainDetected: false,
        temperature: 25.5,
        humidity: 58,
        windSpeed: 1.5,
        provider: 'KMA_ULTRA_SHORT_OBSERVATION',
      });

      const response = await router.request(
        '/today?nx=59&ny=125',
        {},
        { DB: env.DB },
        ctx,
      );
      const data = await response.json<{ current: WeatherSnapshot }>();

      expect(response.status).toBe(200);
      expect(data.current).toMatchObject({
        observedAt: '2026-08-20T15:20:00+09:00',
        dataRole: 'OBSERVATION',
        temperature: 25.5,
        humidity: 58,
        windSpeed: 1.5,
      });
      expect(data.current.forecastAt).toBeUndefined();
      await waitOnExecutionContext(ctx);
    } finally {
      vi.useRealTimers();
    }
  });

  it('does not present a stale observation or forecast as current temperature', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-08-20T15:35:00+09:00'));
    const forecast = {
      current: snapshot(14, { temperature: 21 }),
      hourly: [snapshot(15), snapshot(18)],
      timelineHourly: [snapshot(15), snapshot(18)],
      daily: [day(28)],
      baseDate: '20260820',
      baseTime: '1400',
      dataSource: '기상청 단기예보',
    };
    try {
      await seedCollectedRegion(59, 126, forecast);
      await seedCollectedUltraShortObservation(59, 126, {
        observedAt: '2026-08-20T12:00:00+09:00',
        rainDetected: false,
        temperature: 30,
        humidity: 40,
        windSpeed: 3,
        provider: 'KMA_ULTRA_SHORT_OBSERVATION',
      });

      const response = await router.request('/main?nx=59&ny=126', {}, {
        DB: env.DB,
      });
      const data = await response.json<{ current: WeatherSnapshot }>();

      expect(response.status).toBe(200);
      expect(data.current.temperature).toBeUndefined();
      expect(data.current.apparentTemperature).toBeUndefined();
      expect(data.current.qualityFlags)
        .toContain('CURRENT_OBSERVATION_UNAVAILABLE');
    } finally {
      vi.useRealTimers();
    }
  });

  it('marks 20~30 minute observations delayed and rejects older values', () => {
    const forecast = snapshot(15, { temperature: 21 });
    const value = {
      observedAt: '2026-08-20T15:10:00+09:00',
      rainDetected: false,
      temperature: 25,
      humidity: 60,
      windSpeed: 2,
      provider: 'KMA_APIHUB_GRID_OBSERVATION' as const,
    };

    const delayed = currentFromUltraShortObservation(
      forecast,
      { status: 'AVAILABLE', updatedAt: value.observedAt, value },
      new Date('2026-08-20T15:35:00+09:00'),
    );
    expect(delayed.temperature).toBe(25);
    expect(delayed.qualityFlags).toContain('SOURCE_DELAYED');

    const unavailable = currentFromUltraShortObservation(
      forecast,
      { status: 'AVAILABLE', updatedAt: value.observedAt, value },
      new Date('2026-08-20T15:41:00+09:00'),
    );
    expect(unavailable.temperature).toBeUndefined();
    expect(unavailable.qualityFlags).toContain('CURRENT_OBSERVATION_UNAVAILABLE');
  });

  it('calculates the same estimated apparent temperature for mild October observations', () => {
    const observation = {
      observedAt: '2026-10-01T09:40:00+09:00',
      rainDetected: false,
      temperature: 19,
      humidity: 25,
      windSpeed: 3.5,
      provider: 'KMA_APIHUB_GRID_OBSERVATION' as const,
    };
    const current = currentFromUltraShortObservation(
      snapshot(10),
      { status: 'AVAILABLE', updatedAt: observation.observedAt, value: observation },
      new Date('2026-10-01T09:49:00+09:00'),
    );

    expect(current.apparentTemperature).toBe(14.4);
    expect(current.kmaApparentTemperature).toBeUndefined();
    expect(current.apparentTemperatureSource)
      .toBe('APP_STEADMAN_FROM_OBSERVATION');
  });

  it('강수 실황만 결측이면 기온은 쓰되 비 여부는 예보를 유지한다', () => {
    const observation = {
      observedAt: '2026-10-01T09:40:00+09:00',
      rainDetected: false,
      temperature: 19,
      humidity: 25,
      windSpeed: 3.5,
      provider: 'KMA_APIHUB_GRID_OBSERVATION' as const,
      qualityFlags: ['PRECIPITATION_TYPE_UNAVAILABLE'],
    };
    const current = currentFromUltraShortObservation(
      snapshot(10, { precipitationType: 'RAIN' }),
      { status: 'AVAILABLE', updatedAt: observation.observedAt, value: observation },
      new Date('2026-10-01T09:49:00+09:00'),
    );

    expect(current.temperature).toBe(19);
    expect(current.precipitationType).toBe('RAIN');
  });

  it('selects the earliest forecast strictly after the current time', () => {
    expect(nextForecastSnapshot(
      [snapshot(12), snapshot(11), snapshot(10)],
      new Date('2026-08-20T10:35:00+09:00'),
    )?.forecastAt).toBe('2026-08-20T11:00:00+09:00');
    expect(nextForecastSnapshot(
      [snapshot(11), snapshot(10)],
      new Date('2026-08-20T10:00:00+09:00'),
    )?.forecastAt).toBe('2026-08-20T11:00:00+09:00');
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
    const expandedExpected = recommendationsForDay(
      forecastDay,
      hourly,
      settings,
      true,
    ).filter((r) => r.recommended).slice(0, 3);
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
      expect(await response.json()).toMatchObject({
        generatedAt: '2026-08-20T01:00:00.000Z',
        days: [{
          weatherDataComplete: false, minTemperatureSource: 'HOURLY', maxTemperatureSource: 'DAILY',
          recommendations: expected.map(({ type, recommended }) => ({ type, recommended })),
        }],
      });
      const expandedResponse = await router.request(
        '/weekly?nx=60&ny=121&installationId=test&recommendationCatalog=PREPARATION_15',
        { headers: testAuthHeaders },
        { DB: env.DB, KMA_SERVICE_KEY: 'test-key' },
      );
      const expandedData = await expandedResponse.json<{
        days: Array<{ recommendations: Array<{ type: string; recommended: boolean }> }>;
      }>();
      expect(expandedResponse.status).toBe(200);
      expect(expandedData.days[0].recommendations).toMatchObject(
        expandedExpected.map(({ type, recommended }) => ({ type, recommended })),
      );
    } finally {
      provider.mockRestore();
      savedSettings.mockRestore();
      vi.useRealTimers();
    }
  });

  it('adjusts the number of rain preparations to the severity in the expanded catalog', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-08-20T01:00:00Z'));
    const hourly = [14, 15].map((hour) => snapshot(hour, {
      precipitationProbability: 90,
      precipitationAmount: 10,
      precipitationType: 'RAIN',
    }));
    const forecastDay = {
      ...day(24),
      skyCondition: '비',
      precipitationProbability: 90,
      precipitationAmount: 10,
    };
    try {
      await seedCollectedWeekly(61, 122, {
        forecast: {
          current: hourly[0],
          hourly,
          daily: [forecastDay],
          baseDate: '20260820',
          baseTime: '1100',
          dataSource: '기상청',
        },
        midTermDays: [],
        observedDays: [],
        airQuality: [],
      });
      const legacy = await router.request(
        '/weekly?nx=61&ny=122',
        {},
        { DB: env.DB },
      );
      const expanded = await router.request(
        '/weekly?nx=61&ny=122&recommendationCatalog=PREPARATION_15',
        {},
        { DB: env.DB },
      );
      const legacyData = await legacy.json<{
        days: Array<{
          forecastDate: string;
          recommendations: Array<{ type: string }>;
        }>;
      }>();
      const expandedData = await expanded.json<{
        days: Array<{
          forecastDate: string;
          recommendations: Array<{ type: string }>;
        }>;
      }>();
      const legacyDay = legacyData.days.find(
        (item) => item.forecastDate === '2026-08-20',
      );
      const expandedDay = expandedData.days.find(
        (item) => item.forecastDate === '2026-08-20',
      );

      expect(legacyDay?.recommendations.map((item) => item.type))
        .toEqual(['UMBRELLA']);
      expect(expandedDay?.recommendations.map((item) => item.type))
        .toEqual(['UMBRELLA', 'RAINCOAT']);
    } finally {
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
        '/weekly?nx=58&ny=124',
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
        '/weekly?nx=58&ny=124',
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

describe('/weekly Hangdong mid-term hydration', () => {
  it('uses Seoul codes on the first request and reuses the persistent cache', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-09-21T10:00:00Z'));
    const temperature: Record<string, string | number> = {
      regId: '11B10101',
    };
    const land: Record<string, string | number> = {
      regId: '11B00000',
    };
    for (let offset = 4; offset <= 10; offset += 1) {
      temperature[`taMin${offset}`] = 10 + offset;
      temperature[`taMax${offset}`] = 20 + offset;
      if (offset <= 7) {
        land[`wf${offset}Am`] = '맑음';
        land[`wf${offset}Pm`] = '구름많음';
        land[`rnSt${offset}Am`] = 10;
        land[`rnSt${offset}Pm`] = 20;
      } else {
        land[`wf${offset}`] = '구름많음';
        land[`rnSt${offset}`] = 20;
      }
    }
    const getTemperature = vi.spyOn(
      KmaMidTermProvider.prototype,
      'getTemperature',
    ).mockResolvedValue(temperature);
    const getLandForecast = vi.spyOn(
      KmaMidTermProvider.prototype,
      'getLandForecast',
    ).mockResolvedValue(land);
    try {
      const shortDays = ['20260921', '20260922', '20260923', '20260924', '20260925']
        .map((date) => ({
          ...day(25),
          date,
          weatherDataComplete: true,
          minTemperatureSource: 'DAILY' as const,
          maxTemperatureSource: 'DAILY' as const,
          forecastSource: 'KMA_SHORT_TERM' as const,
        }));
      await seedCollectedWeekly(57, 125, {
        forecast: {
          current: snapshot(14),
          hourly: [],
          daily: shortDays,
          baseDate: '20260921',
          baseTime: '1700',
          dataSource: '기상청 단기예보',
        },
        midTermDays: [],
        observedDays: [],
        airQuality: [],
      });
      await env.DB.prepare(
        `DELETE FROM weather_cache
         WHERE cache_key LIKE 'COLLECTED_MID_TERM_%'
            OR cache_key LIKE 'COLLECTED_FETCH_LEASE_%'`,
      ).run();

      const url = '/weekly?nx=57&ny=125' +
        '&regionCode=1153080000' +
        '&regionName=%EC%84%9C%EC%9A%B8%ED%8A%B9%EB%B3%84%EC%8B%9C%20%EA%B5%AC%EB%A1%9C%EA%B5%AC%20%ED%95%AD%EB%8F%99';
      const bindings = {
        DB: env.DB,
        KMA_SERVICE_KEY: 'test-key',
        KMA_APIHUB_KEY: 'hub-key',
      };
      const first = await router.request(url, {}, bindings);
      const firstData = await first.json<{
        region: {
          adminCode: string;
          midTermTaRegId: string;
          midTermLandRegId: string;
        };
        weeklyCoverage: {
          shortTermUntil: string;
          midTermCacheStatus: string;
        };
        days: Array<{
          forecastDate: string;
          min?: string;
          max?: string;
          weatherLabel: string;
          source: string;
        }>;
      }>();

      expect(first.status).toBe(200);
      expect(firstData.region).toMatchObject({
        adminCode: '1153080000',
        midTermTaRegId: '11B10101',
        midTermLandRegId: '11B00000',
      });
      expect(firstData.weeklyCoverage).toEqual(expect.objectContaining({
        shortTermUntil: '2026-09-25T23:00:00+09:00',
        midTermCacheStatus: 'MISS_REFRESHED',
      }));
      expect(firstData.days.find(({ forecastDate }) =>
        forecastDate === '2026-09-26')).toMatchObject({
          min: '15',
          max: '25',
          weatherLabel: '구름많음',
          source: 'MID_TERM',
        });
      expect(getTemperature).toHaveBeenCalledTimes(1);
      expect(getTemperature).toHaveBeenCalledWith('11B10101', '202609211800');
      expect(getLandForecast).toHaveBeenCalledTimes(1);
      expect(getLandForecast).toHaveBeenCalledWith('11B00000', '202609211800');

      const second = await router.request(url, {}, bindings);
      const secondData = await second.json<{
        weeklyCoverage: { midTermCacheStatus: string };
        days: Array<{ forecastDate: string; weatherLabel: string }>;
      }>();
      expect(second.status).toBe(200);
      expect(secondData.weeklyCoverage.midTermCacheStatus).toBe('HIT');
      expect(secondData.days.find(({ forecastDate }) =>
        forecastDate === '2026-09-26')?.weatherLabel).toBe('구름많음');
      expect(getTemperature).toHaveBeenCalledTimes(1);
      expect(getLandForecast).toHaveBeenCalledTimes(1);

      await seedCollectedWeekly(58, 125, {
        forecast: {
          current: snapshot(14),
          hourly: [],
          daily: shortDays,
          baseDate: '20260921',
          baseTime: '1700',
          dataSource: '기상청 단기예보',
        },
        midTermDays: [],
        observedDays: [],
        airQuality: [],
      });
      const sharedRegionResponse = await router.request(
        url.replace('nx=57', 'nx=58'),
        {},
        bindings,
      );
      const sharedRegionData = await sharedRegionResponse.json<{
        weeklyCoverage: { midTermCacheStatus: string };
      }>();
      expect(sharedRegionResponse.status).toBe(200);
      expect(sharedRegionData.weeklyCoverage.midTermCacheStatus).toBe('HIT');
      expect(getTemperature).toHaveBeenCalledTimes(1);
      expect(getLandForecast).toHaveBeenCalledTimes(1);
    } finally {
      getTemperature.mockRestore();
      getLandForecast.mockRestore();
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
  it('fills a cached October forecast calculated before the formula update', () => {
    const cached = snapshot(10, {
      observedAt: '2026-10-01T10:00:00+09:00',
      forecastAt: '2026-10-01T10:00:00+09:00',
      temperature: 19,
      humidity: 25,
      windSpeed: 3.5,
      apparentTemperature: undefined,
    });
    const forecast = forecastForCurrentHour({
      current: cached,
      hourly: [cached],
      daily: [],
      baseDate: '20261001',
      baseTime: '0800',
      dataSource: '기상청 단기예보',
    }, new Date('2026-10-01T09:49:00+09:00'));

    expect(forecast.current.apparentTemperature).toBe(14.4);
    expect(forecast.current.kmaApparentTemperature).toBeUndefined();
    expect(forecast.current.apparentTemperatureSource)
      .toBe('APP_STEADMAN_FROM_FORECAST');
  });

  it('keeps an estimated forecast separate from the KMA apparent-temperature field', () => {
    const estimated = snapshot(10, {
      apparentTemperature: 14.4,
      kmaApparentTemperature: undefined,
      apparentTemperatureSource: 'APP_STEADMAN_FROM_FORECAST',
    });
    const forecast = forecastForCurrentHour({
      current: estimated,
      hourly: [estimated],
      daily: [],
      baseDate: '20260820',
      baseTime: '0800',
      dataSource: '기상청 단기예보',
    }, new Date('2026-08-20T00:49:00Z'));

    expect(forecast.current.apparentTemperature).toBe(14.4);
    expect(forecast.current.kmaApparentTemperature).toBeUndefined();
  });

  it('uses retained early hours while keeping the detail forecast current-first', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-08-20T09:30:00+09:00'));
    const cachedHourly = [snapshot(8), snapshot(9), snapshot(12)];
    const timelineHourly = [3, 6, 9, 12, 15, 18, 21, 24].map((hour) =>
      snapshot(hour),
    );
    const provider = vi.spyOn(
      KmaWeatherProvider.prototype,
      'getForecastByRegion',
    ).mockResolvedValue({
      current: cachedHourly[0],
      hourly: cachedHourly,
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
        current: cachedHourly[0],
        hourly: cachedHourly,
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
        current: WeatherSnapshot;
        hourly: WeatherSnapshot[];
        nextForecast: WeatherSnapshot;
        timeline: ReturnType<typeof buildTimeline>;
      }>();

      expect(response.status).toBe(200);
      expect(data.current.forecastAt).toBe('2026-08-20T09:00:00+09:00');
      expect(data.hourly.map((item) => item.observedAt.slice(11, 13))).toEqual([
        '09',
        '12',
      ]);
      expect(data.nextForecast.forecastAt).toBe('2026-08-20T12:00:00+09:00');
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
  it('labels retryable environmental failures by detail item', () => {
    expect(buildEnvironmentalDataStatusMessages({
      uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNAVAILABLE' },
      airQuality: {
        provider: 'AIRKOREA',
        state: 'STALE',
        observedAt: '2026-09-17T12:00:00+09:00',
      },
    })).toEqual([
      {
        role: 'DATA_STATUS',
        itemTitle: '자외선지수',
        text: '자료를 받아오지 못해 자외선지수를 확인하기 어려워요',
        source: 'KMA_LIVING_INDEX_V5',
      },
      {
        role: 'DATA_STATUS',
        itemTitle: '대기질',
        text: '마지막으로 확인한 대기질은 오후 12시 자료예요 · 이후 달라졌을 수 있어요',
        source: 'AIRKOREA',
      },
    ]);
  });

  it('does not offer a reload for an unsupported region', () => {
    expect(buildEnvironmentalDataStatusMessages({
      uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNSUPPORTED_REGION' },
      airQuality: { provider: 'AIRKOREA', state: 'AVAILABLE' },
    })).toEqual([
      {
        role: 'DATA_STATUS',
        itemTitle: '자외선지수',
        text: '선택한 지역에서는 자외선지수 자료를 지원하지 않아 확인하기 어려워요',
        source: 'KMA_LIVING_INDEX_V5',
        retryable: false,
      },
    ]);
  });

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
        itemTitle: '현재 강수',
        text: '자료를 받아오지 못해 현재 강수 상태를 확인하기 어려워요',
        source: '기상청 관측분석자료·기상청 레이더',
      },
      {
        role: 'DATA_STATUS',
        itemTitle: '도로 통제',
        text: '자료를 받아오지 못해 현재 도로 통제 상태를 확인하기 어려워요',
        source: '국가교통정보센터 돌발상황정보',
      },
    ]);
  });

  it('hides successful no-event results for current rain and road controls', () => {
    expect(buildCurrentOptionalDataStatusMessages({
      coordinatesAvailable: true,
      precipitationRecord: {
        status: 'AVAILABLE',
        updatedAt: '2026-09-22T07:17:00Z',
        value: {
          observedAt: '2026-09-22T07:00:00Z',
          latitude: 37.4877,
          longitude: 126.8939,
          analysisRainDetected: false,
          radarRainDetected: false,
          state: 'DRY',
          provider: 'KMA_ANALYSIS_RADAR',
        },
      },
      roadControlRecord: {
        status: 'AVAILABLE',
        updatedAt: '2026-09-22T07:20:00Z',
        value: null,
      },
    })).toEqual([]);
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
