import { env } from 'cloudflare:test';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  isNotificationTimeDue,
  runRecommendationNotificationJob,
} from '../src/notification/notificationScheduler';
import { FcmPayload } from '../src/notification/fcmClient';
import { WeatherForecast } from '../src/providers/weather/weatherProvider';
import { ServerEnv, WeatherSnapshot } from '../src/types';

describe('notification scheduler', () => {
  beforeEach(async () => {
    await env.DB.batch([
      env.DB.prepare(
        `CREATE TABLE IF NOT EXISTS installations (
          installation_id TEXT PRIMARY KEY, fcm_token TEXT,
          nx INTEGER NOT NULL, ny INTEGER NOT NULL,
          region_topic TEXT NOT NULL, location_mode TEXT NOT NULL,
          platform TEXT, app_version TEXT,
          timezone TEXT NOT NULL DEFAULT 'Asia/Seoul',
          latitude REAL, longitude REAL,
          current_rain_state INTEGER NOT NULL DEFAULT 0,
          current_rain_observed_at TEXT,
          road_ice_level INTEGER NOT NULL DEFAULT 0,
          road_ice_link_id TEXT,
          road_ice_observed_at TEXT,
          road_control_event_key TEXT,
          road_control_kind TEXT,
          road_control_started_at TEXT,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL)`,
      ),
      env.DB.prepare(
        `CREATE TABLE IF NOT EXISTS notification_settings (
          installation_id TEXT PRIMARY KEY,
          notification_enabled INTEGER NOT NULL DEFAULT 1,
          notification_time TEXT NOT NULL DEFAULT '07:00',
          umbrella_enabled INTEGER NOT NULL DEFAULT 1,
          parasol_enabled INTEGER NOT NULL DEFAULT 1,
          heavy_snow_enabled INTEGER NOT NULL DEFAULT 1,
          outerwear_enabled INTEGER NOT NULL DEFAULT 1,
          mask_enabled INTEGER NOT NULL DEFAULT 1,
          water_enabled INTEGER NOT NULL DEFAULT 1,
          sunscreen_enabled INTEGER NOT NULL DEFAULT 1,
          daily_weather_enabled INTEGER NOT NULL DEFAULT 1,
          heavy_rain_enabled INTEGER NOT NULL DEFAULT 1,
          heatwave_enabled INTEGER NOT NULL DEFAULT 1,
          cold_wave_enabled INTEGER NOT NULL DEFAULT 1,
          shower_light_rain_enabled INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL)`,
      ),
      env.DB.prepare(
        `CREATE TABLE IF NOT EXISTS notification_history (
          installation_id TEXT NOT NULL, target_date TEXT NOT NULL,
          notification_key TEXT NOT NULL, sent_at TEXT NOT NULL,
          payload_hash TEXT,
          PRIMARY KEY (installation_id, target_date, notification_key))`,
      ),
      env.DB.prepare(
        `CREATE TABLE IF NOT EXISTS installation_warning_state (
          installation_id TEXT NOT NULL, warning_type TEXT NOT NULL,
          warning_name TEXT NOT NULL, level_code TEXT NOT NULL,
          level_name TEXT NOT NULL, region_name TEXT NOT NULL,
          effective_at TEXT NOT NULL, updated_at TEXT NOT NULL,
          PRIMARY KEY (installation_id, warning_type))`,
      ),
    ]);
    await env.DB.batch([
      env.DB.prepare('DELETE FROM installation_warning_state'),
      env.DB.prepare('DELETE FROM notification_history'),
      env.DB.prepare('DELETE FROM notification_settings'),
      env.DB.prepare('DELETE FROM installations'),
    ]);
  });

  it('sends a due brief once and records only a successful send', async () => {
    await insertInstallation('device-token');
    const sent: FcmPayload[][] = [];
    const sender = vi.fn(async (_env: ServerEnv, payloads: FcmPayload[]) => {
      sent.push(payloads);
      return payloads.map((payload) => ({
        token: payload.token,
        notificationKey: payload.notificationKey,
        success: true,
        unregistered: false,
        status: 200,
      }));
    });
    const dependencies = {
      now: new Date('2026-09-01T22:00:00Z'),
      forecastLoader: async () => rainyForecast(),
      sender,
    };
    const bindings = testBindings();

    await runRecommendationNotificationJob(bindings, dependencies);
    await runRecommendationNotificationJob(bindings, dependencies);

    expect(sent).toHaveLength(1);
    expect(sent[0][0]).toMatchObject({
      token: 'device-token',
      notificationKey: 'MORNING_BRIEF',
      notificationTarget: 'MAIN',
      notificationTopic: 'OVERVIEW',
    });
    const history = await env.DB.prepare(
      'SELECT notification_key FROM notification_history',
    ).all<{ notification_key: string }>();
    expect(history.results).toEqual([
      { notification_key: 'MORNING_BRIEF' },
    ]);
  });

  it('uses scheduler time to suppress already-ended precipitation even with an older fetch time', async () => {
    await insertInstallation('device-token');
    const forecast = rainyForecast();
    forecast.hourly = [6, 7].map((hour) => {
      const item = snapshot(hour);
      return { ...item, fetchedAt: '2026-09-02T05:00:00+09:00',
        precipitationPeriod: { start: new Date(Date.parse(item.forecastAt!) - 3_600_000).toISOString(), end: item.forecastAt! } };
    });
    const sender = vi.fn(async (_env: ServerEnv, payloads: FcmPayload[]) => payloads.map(successResult));
    await runRecommendationNotificationJob(testBindings(), {
      now: new Date('2026-09-02T07:00:00+09:00'), forecastLoader: async () => forecast, sender,
    });
    expect(sender).not.toHaveBeenCalled();
  });

  it('sends the true preceding-hour period in a due rain notification', async () => {
    await insertInstallation('device-token');
    const forecast = rainyForecast();
    forecast.hourly = [8, 9].map((hour) => {
      const item = snapshot(hour);
      return { ...item, precipitationPeriod: {
        start: new Date(Date.parse(item.forecastAt!) - 3_600_000).toISOString(), end: item.forecastAt! } };
    });
    const sent: FcmPayload[] = [];
    await runRecommendationNotificationJob(testBindings(), {
      now: new Date('2026-09-02T07:00:00+09:00'), forecastLoader: async () => forecast,
      sender: collectingSender(sent),
    });
    expect(sent).toHaveLength(1);
    expect(sent[0].body).toContain('오전 7시~9시');
  });

  it('removes an unregistered token without writing send history', async () => {
    await insertInstallation('expired-token');
    const bindings = testBindings();

    await runRecommendationNotificationJob(bindings, {
      now: new Date('2026-09-01T22:00:00Z'),
      forecastLoader: async () => rainyForecast(),
      sender: async (_env, payloads) =>
        payloads.map((payload) => ({
          token: payload.token,
          notificationKey: payload.notificationKey,
          success: false,
          unregistered: true,
          status: 404,
        })),
    });

    const installation = await env.DB.prepare(
      'SELECT fcm_token FROM installations WHERE installation_id = ?',
    )
      .bind('installation-1')
      .first<{ fcm_token: string | null }>();
    const history = await env.DB.prepare(
      'SELECT COUNT(*) AS count FROM notification_history',
    ).first<{ count: number }>();
    expect(installation?.fcm_token).toBeNull();
    expect(history?.count).toBe(0);
  });

  it('sends current rain once per rain episode only after both 500m sources agree', async () => {
    await insertInstallation('device-token', true);
    const sender = vi.fn(async (_env: ServerEnv, payloads: FcmPayload[]) =>
      payloads.map((payload) => ({
        token: payload.token,
        notificationKey: payload.notificationKey,
        success: true,
        unregistered: false,
        status: 200,
      })),
    );
    const dependencies = {
      now: new Date('2026-09-01T12:00:00Z'),
      forecastLoader: async () => rainyForecast(),
      precipitationLoader: async () => ({
        observedAt: '2026-09-01T20:50:00+09:00',
        latitude: 37.2636,
        longitude: 127.0286,
        analysisRainDetected: true,
        radarRainDetected: true,
        state: 'RAIN' as const,
        provider: 'KMA_ANALYSIS_RADAR' as const,
      }),
      warningLoader: async () => [],
      roadIceLoader: async () => undefined,
      sender,
    };
    const bindings = testBindings('test-apihub-key');

    await runRecommendationNotificationJob(bindings, dependencies);
    await runRecommendationNotificationJob(bindings, dependencies);

    const currentRainPayloads = sender.mock.calls
      .flatMap((call) => call[1] as FcmPayload[])
      .filter((payload) => payload.notificationKey === 'CURRENT_RAIN');
    expect(currentRainPayloads).toEqual([
      expect.objectContaining({
        body: '비가 내리고 있을 수 있어요. 지금 외출한다면 우산을 챙기세요',
        notificationTarget: 'WEATHER_DETAILS',
        notificationTopic: 'PRECIPITATION',
      }),
    ]);
    const state = await env.DB.prepare(
      'SELECT current_rain_state AS state FROM installations WHERE installation_id = ?',
    )
      .bind('installation-1')
      .first<{ state: number }>();
    expect(state?.state).toBe(1);
  });

  it('sends an active official warning only once and stores its state', async () => {
    await insertInstallation('device-token');
    const sent: FcmPayload[] = [];
    const dependencies = {
      now: new Date('2026-09-01T12:00:00Z'),
      forecastLoader: async () => rainyForecast(),
      warningLoader: async () => [officialWarning('R', '호우', '2')],
      sender: async (_env: ServerEnv, payloads: FcmPayload[]) => {
        sent.push(...payloads);
        return payloads.map(successResult);
      },
    };
    const bindings = testBindings('test-apihub-key');

    await runRecommendationNotificationJob(bindings, dependencies);
    await runRecommendationNotificationJob(bindings, dependencies);

    expect(sent.filter((item) => item.notificationKey.startsWith('OFFICIAL_WARNING')))
      .toEqual([
        expect.objectContaining({
          body: '호우특보가 발효 중이니, 하천변과 지하차도에 접근하지 마세요 수원에는 호우주의보가 발효 중이에요',
          notificationTarget: 'WEATHER_DETAILS',
          notificationTopic: 'PRECIPITATION',
        }),
      ]);
    const state = await env.DB.prepare(
      `SELECT level_code AS levelCode FROM installation_warning_state
       WHERE installation_id = ? AND warning_type = 'R'`,
    )
      .bind('installation-1')
      .first<{ levelCode: string }>();
    expect(state?.levelCode).toBe('2');
  });

  it('resolves an uncatalogued GPS grid to an official warning region', async () => {
    await insertInstallation('device-token', true);
    await env.DB.prepare(
      `UPDATE installations
       SET nx = 98, ny = 76, latitude = 35.1796, longitude = 129.0756
       WHERE installation_id = 'installation-1'`,
    ).run();
    const warningLoader = vi.fn(async () => [
      {
        ...officialWarning('R', '호우', '2'),
        regionId: 'L1080100',
        regionName: '부산',
      },
    ]);
    const sender = vi.fn(async (_env: ServerEnv, payloads: FcmPayload[]) =>
      payloads.map(successResult),
    );

    await runRecommendationNotificationJob(testBindings('test-apihub-key'), {
      now: new Date('2026-09-01T12:00:00Z'),
      forecastLoader: async () => rainyForecast(),
      warningRegionResolver: async () => ({
        regionId: 'L1080100',
        regionName: '부산',
        stationId: '159',
        stationName: '부산',
        distanceMeters: 2_000,
      }),
      warningLoader,
      sender,
    });

    expect(warningLoader).toHaveBeenCalledWith(
      expect.anything(),
      ['L1080100'],
    );
    const warningPayload = sender.mock.calls
      .flatMap((call) => call[1] as FcmPayload[])
      .find((payload) => payload.notificationKey.startsWith('OFFICIAL_WARNING'));
    expect(warningPayload?.body).toContain('부산에는 호우주의보가 발효 중이에요');
  });

  it('announces an official level change and release', async () => {
    await insertInstallation('device-token');
    await insertWarningState('R', '호우', '2', '주의보');
    const sent: FcmPayload[] = [];
    const bindings = testBindings('test-apihub-key');

    await runRecommendationNotificationJob(bindings, {
      now: new Date('2026-09-01T12:00:00Z'),
      forecastLoader: async () => rainyForecast(),
      warningLoader: async () => [officialWarning('R', '호우', '3')],
      sender: collectingSender(sent),
    });
    expect(sent.find((item) => item.notificationKey.includes('CHANGED'))?.body)
      .toContain('기상청은 수원의 호우주의보를 호우경보로 변경했어요');

    sent.length = 0;
    await runRecommendationNotificationJob(bindings, {
      now: new Date('2026-09-01T12:10:00Z'),
      forecastLoader: async () => rainyForecast(),
      warningLoader: async () => [],
      sender: collectingSender(sent),
    });
    expect(sent.find((item) => item.notificationKey.includes('RELEASED'))?.body)
      .toBe('수원의 호우경보가 해제됐어요');
  });

  it('sends a nearby official road-ice stage once and resets after it clears', async () => {
    await insertInstallation('device-token', true);
    const sent: FcmPayload[] = [];
    const bindings = testBindings('test-apihub-key');
    const dependencies = {
      now: new Date('2026-01-15T01:00:00Z'),
      forecastLoader: async () => rainyForecast(),
      precipitationLoader: async () => ({
        observedAt: '2026-01-15T09:50:00+09:00',
        latitude: 37.2636,
        longitude: 127.0286,
        analysisRainDetected: false,
        radarRainDetected: false,
        state: 'DRY' as const,
        provider: 'KMA_ANALYSIS_RADAR' as const,
      }),
      warningLoader: async () => [],
      roadIceLoader: async () => roadIceRisk(),
      sender: collectingSender(sent),
    };

    await runRecommendationNotificationJob(bindings, dependencies);
    await runRecommendationNotificationJob(bindings, dependencies);

    expect(sent.filter((item) => item.notificationKey.startsWith('ROAD_ICE_')))
      .toEqual([
        expect.objectContaining({
          title: '블랙아이스(도로살얼음)',
          notificationTarget: 'WEATHER_DETAILS',
          notificationTopic: 'ROAD_ICE',
          body: expect.stringContaining(
            '기상청은 오전 10시 영동선 수원 인근 구간의 블랙아이스(도로살얼음) 발생 가능성을 주의 2단계로 안내했어요',
          ),
        }),
      ]);

    await runRecommendationNotificationJob(bindings, {
      ...dependencies,
      now: new Date('2026-01-15T01:10:00Z'),
      roadIceLoader: async () => undefined,
    });
    const state = await env.DB.prepare(
      `SELECT road_ice_level AS level, road_ice_link_id AS linkId
       FROM installations WHERE installation_id = ?`,
    )
      .bind('installation-1')
      .first<{ level: number; linkId: string | null }>();
    expect(state).toEqual({ level: 0, linkId: null });
  });

  it('sends an active official road control once and resets after it ends', async () => {
    await insertInstallation('device-token', true);
    const sent: FcmPayload[] = [];
    const bindings = testBindings(
      '',
      '',
      'https://relay.example.ts.net',
      'relay-token',
    );
    const dependencies = {
      now: new Date('2026-09-01T05:10:00Z'),
      forecastLoader: async () => rainyForecast(),
      roadControlLoader: async () => roadControl(),
      sender: collectingSender(sent),
    };

    await runRecommendationNotificationJob(bindings, dependencies);
    await runRecommendationNotificationJob(bindings, dependencies);

    expect(sent.filter((item) => item.notificationKey.startsWith('ROAD_CONTROL_')))
      .toEqual([
        expect.objectContaining({
          title: '출퇴근 경로',
          notificationTarget: 'WEATHER_DETAILS',
          notificationTopic: 'COMMUTE',
          body: '수원지하차도 전면 통제가 시행 중이니, 출발 전에 다른 경로와 대중교통 운행정보를 확인하세요 국가교통정보센터는 9월 1일 오후 2시부터 수원지하차도 전면 통제가 시행 중이라고 안내했어요',
        }),
      ]);

    await runRecommendationNotificationJob(bindings, {
      ...dependencies,
      now: new Date('2026-09-01T05:20:00Z'),
      roadControlLoader: async () => undefined,
    });
    const state = await env.DB.prepare(
      `SELECT road_control_event_key AS eventKey
       FROM installations WHERE installation_id = ?`,
    )
      .bind('installation-1')
      .first<{ eventKey: string | null }>();
    expect(state?.eventKey).toBeNull();
  });
});

describe('notification time slots', () => {
  it('runs at the next ten-minute cron slot', () => {
    expect(isNotificationTimeDue('07:00', '07:00')).toBe(true);
    expect(isNotificationTimeDue('07:10', '07:05')).toBe(true);
    expect(isNotificationTimeDue('07:00', '07:05')).toBe(false);
    expect(isNotificationTimeDue('00:00', '23:55')).toBe(true);
  });
});

async function insertInstallation(
  token: string,
  withCoordinates = false,
): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO installations
     (installation_id, fcm_token, nx, ny, region_topic, location_mode,
      timezone, latitude, longitude, created_at, updated_at)
     VALUES (?, ?, 60, 121, 'region_60_121', 'GPS', 'Asia/Seoul', ?, ?, ?, ?)`,
  )
    .bind(
      'installation-1',
      token,
      withCoordinates ? 37.2636 : null,
      withCoordinates ? 127.0286 : null,
      '2026-09-01T00:00:00Z',
      '2026-09-01T00:00:00Z',
    )
    .run();
}

function testBindings(
  apiHubKey = '',
  itsApiKey = '',
  itsRelayUrl = '',
  itsRelayToken = '',
): ServerEnv {
  return {
    DB: env.DB,
    APP_ORIGIN: 'http://localhost:8787',
    FCM_PROJECT_ID: 'weather-care-2aaa8',
    KMA_SERVICE_KEY: 'test-key',
    KMA_APIHUB_KEY: apiHubKey,
    ITS_API_KEY: itsApiKey,
    ITS_RELAY_URL: itsRelayUrl,
    ITS_RELAY_TOKEN: itsRelayToken,
    FCM_CLIENT_EMAIL: 'test@example.iam.gserviceaccount.com',
    FCM_PRIVATE_KEY: 'test-private-key',
  };
}

function roadControl() {
  return {
    eventKey: 'link-1|20260901140000|재난|침수',
    startedAt: '2026-09-01T14:00:00+09:00',
    roadName: '수원지하차도',
    controlKind: 'FULL' as const,
    lanesBlocked: '전면 통제',
    eventType: '재난',
    eventDetailType: '침수',
    message: '침수로 전면 통제합니다',
    linkId: 'link-1',
    latitude: 37.264,
    longitude: 127.029,
    distanceMeters: 80,
    provider: '국가교통정보센터 돌발상황정보' as const,
  };
}

function rainyForecast(): WeatherForecast {
  const hourly = [7, 8, 9].map((hour) => snapshot(hour));
  return {
    current: hourly[0],
    hourly,
    daily: [],
    baseDate: '20260902',
    baseTime: '0500',
    dataSource: '기상청 단기예보',
  };
}

function snapshot(hour: number): WeatherSnapshot {
  const time = `2026-09-02T${String(hour).padStart(2, '0')}:00:00+09:00`;
  return {
    observedAt: time,
    forecastAt: time,
    validFrom: time,
    validTo: time,
    temperature: 24,
    humidity: 75,
    windSpeed: 2,
    precipitationType: 'RAIN',
    precipitationProbability: 80,
    precipitationAmount: 3,
    precipitationAmountRange: {
      type: 'VALUE',
      min: 3,
      max: 3,
      unit: 'MM',
      rawValue: '3mm',
    },
    snowfallAmount: 0,
  };
}

function officialWarning(
  typeCode: 'R',
  type: '호우',
  levelCode: '2' | '3',
) {
  return {
    typeCode,
    type,
    levelCode,
    level: levelCode === '2' ? '주의보' as const : '경보' as const,
    commandCode: '1' as const,
    regionId: 'L1011900',
    regionName: '수원',
    announcedAt: '2026-09-01T09:00:00+09:00',
    validFrom: '2026-09-01T10:00:00+09:00',
    provider: '기상청 특보현황' as const,
  };
}

function successResult(payload: FcmPayload) {
  return {
    token: payload.token,
    notificationKey: payload.notificationKey,
    success: true,
    unregistered: false,
    status: 200,
  };
}

function collectingSender(sent: FcmPayload[]) {
  return async (_env: ServerEnv, payloads: FcmPayload[]) => {
    sent.push(...payloads);
    return payloads.map(successResult);
  };
}

async function insertWarningState(
  typeCode: string,
  typeName: string,
  levelCode: string,
  levelName: string,
): Promise<void> {
  await env.DB.prepare(
    `INSERT INTO installation_warning_state
     (installation_id, warning_type, warning_name, level_code, level_name,
      region_name, effective_at, updated_at)
     VALUES ('installation-1', ?, ?, ?, ?, '수원', ?, ?)`,
  )
    .bind(
      typeCode,
      typeName,
      levelCode,
      levelName,
      '2026-09-01T10:00:00+09:00',
      '2026-09-01T01:00:00Z',
    )
    .run();
}

function roadIceRisk() {
  return {
    producedAt: '2026-01-15T01:00:00Z',
    roadNumber: '050',
    roadName: '영동선',
    linkId: 'risk-link',
    level: 2 as const,
    levelLabel: '주의' as const,
    sourceType: 'OBSERVATION' as const,
    fromLatitude: 37.263,
    fromLongitude: 127.03,
    toLatitude: 37.264,
    toLongitude: 127.031,
    distanceMeters: 120,
    provider: '기상청 도로살얼음 발생 가능 정보' as const,
  };
}
