import { afterEach, describe, expect, it, vi } from 'vitest';
import { app } from '../src/index';
import { nodeServerEnv } from '../src/node/runtime';
import { saveCollectedCache } from '../src/database/collectedWeatherRepository';
import { drynessLevel, drynessPreparation } from '../src/rules/dryness';
import { preparationsForSnapshots, preparationsForWindow } from '../src/recommendations/preparationPolicy';
import { enabledRecommendationTypes, runRecommendationEngine } from '../src/recommendations/recommendationEngine';
import { buildDrynessMessages } from '../src/presentation/drynessMessage';
import { buildWeatherBriefResult } from '../src/presentation/weatherBrief';
import { buildNotification } from '../src/notification/notificationBuilder';
import { getNotificationSettings, upsertNotificationSettings, defaultNotificationSettings } from '../src/database/notificationSettingsRepository';
import { runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import type { WeatherSnapshot } from '../src/types';

const now = new Date('2026-10-30T09:00:00+09:00');
const sample = (hour: number, humidity?: number): WeatherSnapshot => ({
  observedAt: `2026-10-30T${String(hour).padStart(2, '0')}:00:00+09:00`,
  forecastAt: `2026-10-30T${String(hour).padStart(2, '0')}:00:00+09:00`,
  dataRole: 'FORECAST', humidity,
});
const forecast = (hourly: WeatherSnapshot[]): WeatherForecast => ({
  current: hourly[0], hourly, daily: [], baseDate: '20261030', baseTime: '0800', dataSource: '기상청',
});

describe('건조도와 단계별 준비물', () => {
  it.each([
    [40.1, 0, undefined], [40, 1, 'LIP_BALM'], [30.1, 1, 'LIP_BALM'],
    [30, 2, 'HAND_CREAM'], [20.1, 2, 'HAND_CREAM'], [20, 3, 'PORTABLE_HUMIDIFIER'],
    [0, 3, 'PORTABLE_HUMIDIFIER'], [100, 0, undefined],
  ] as const)('습도 %s의 경계와 교체를 유지한다', (humidity, level, type) => {
    expect(drynessLevel(humidity)).toBe(level);
    expect(drynessPreparation(humidity)).toBe(type);
    expect(preparationsForSnapshots([sample(10, humidity)], { drynessPreparations: true })
      .map((item) => item.type)).toEqual(type ? [type] : []);
  });

  it.each([undefined, NaN, Infinity, -1, 101])('잘못된 습도 %s로 추천하지 않는다', (humidity) => {
    expect(drynessLevel(humidity)).toBeUndefined();
    expect(preparationsForSnapshots([sample(10, humidity)], { drynessPreparations: true })).toEqual([]);
  });

  it('당일 최고 단계 하나만 고르고 낮은 단계의 근거를 섞지 않는다', () => {
    const items = preparationsForWindow(forecast([sample(10, 40), sample(12, 30), sample(15, 20)]), now,
      { drynessPreparations: true });
    expect(items.map((item) => item.type)).toEqual(['PORTABLE_HUMIDIFIER']);
    expect(items[0].evidence.map((part) => part.text).join(' ')).toContain('습도 20%');
    expect(items[0].validFrom).toBe('2026-10-30T06:00:00.000Z');
  });

  it('종료된 매우 건조 구간 뒤에는 남은 시간의 단계로 내린다', () => {
    const input = forecast([sample(9, 20), sample(10, 30), sample(11, 40)]);
    expect(preparationsForWindow(input, new Date('2026-10-30T10:00:00+09:00'), { drynessPreparations: true })
      .map((item) => item.type)).toEqual(['HAND_CREAM']);
  });

  it('구버전과 설정 OFF에는 새 준비물을 노출하지 않는다', () => {
    const snapshots = [sample(10, 20)];
    expect(runRecommendationEngine([], undefined, { tieredPreparations: true, snapshots })).toEqual([]);
    expect(enabledRecommendationTypes()).not.toContain('PORTABLE_HUMIDIFIER');
    const allowedRecommendedItems = enabledRecommendationTypes({ drynessEnabled: false }, true);
    expect(preparationsForWindow(forecast(snapshots), now,
      { drynessPreparations: true, allowedRecommendedItems })).toEqual([]);
  });

  it('새 브리핑과 요약 알림은 준비물을 연결하고 실내 사용 조건을 밝힌다', () => {
    const input = forecast([sample(9, 20)]);
    const context = { tieredPreparations: true, drynessPreparations: true,
      allowedRecommendedItems: enabledRecommendationTypes(undefined, true) };
    const brief = buildWeatherBriefResult(input, { ...context, now });
    expect(brief.intent.topic).toBe('건조도');
    expect(brief.intent.recommendedItems).toEqual(['PORTABLE_HUMIDIFIER']);
    const payloads = buildNotification([], now, input, context);
    expect(payloads[0].body).toContain('휴대용 가습기');
    expect(payloads[0].body).toContain('실내 습도가 낮을 때');
    const message = buildDrynessMessages(input, now)[0];
    expect(message.title).toBe('건조도 · 매우 건조');
    expect(message.parts.some((part) => part.source?.includes('실내 관리 안내') && part.text.includes('실내 습도도 확인'))).toBe(true);
    expect(buildDrynessMessages(forecast([sample(9, 60)]), now)).toEqual([]);
  });
});

describe('건조 대비 설정 저장·구버전 호환', () => {
  let database: SqliteD1Database | undefined;
  afterEach(() => database?.close());
  it('실제 Node 사용자 DB 마이그레이션 후 OFF를 저장하고 구버전 갱신에도 보존한다', async () => {
    database = new SqliteD1Database(':memory:');
    runSqliteMigrations(database, 'node-migrations/users');
    const settings = defaultNotificationSettings('dryness-device');
    database.sqlite.prepare('INSERT INTO installation_credentials VALUES(?,?,?)')
      .run(settings.installationId, 'synthetic-owner', now.toISOString());
    await upsertNotificationSettings(database, settings);
    expect((await getNotificationSettings(database, settings.installationId)).drynessEnabled).toBeUndefined();
    await upsertNotificationSettings(database, { ...settings, drynessEnabled: false });
    await upsertNotificationSettings(database, settings);
    expect((await getNotificationSettings(database, settings.installationId)).drynessEnabled).toBe(false);
    expect(runSqliteMigrations(database, 'node-migrations/users')).toEqual([]);
  });
});

describe('건조 준비물 API 호환성', () => {
  let database: SqliteD1Database | undefined;
  afterEach(() => { database?.close(); vi.restoreAllMocks(); vi.useRealTimers(); });
  it('Today·위젯은 21종 앱에만 새 준비물을 전달한다', async () => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(now);
    vi.spyOn(globalThis, 'fetch').mockRejectedValue(new Error('외부 호출 금지'));
    database = new SqliteD1Database(':memory:');
    runSqliteMigrations(database);
    const input = forecast([sample(9, 20), sample(10, 30), sample(11, 40)]);
    await saveCollectedCache(database, {
      key: 'COLLECTED_REGION_60_127', type: 'COLLECTED_REGION', nx: 60, ny: 127, updatedAt: now,
      value: { forecast: input, environmental: { sources: {
        uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNAVAILABLE' },
        airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' },
      } } },
    });
    const environment = nodeServerEnv(database, {});
    for (const catalog of ['', 'PREPARATION_15', 'PREPARATION_18', 'PREPARATION_21']) {
      const response = await app.fetch(new Request(`http://localhost/api/v1/weather/today?nx=60&ny=127&includeExtras=true&recommendationCatalog=${catalog}`), environment);
      expect(response.status).toBe(200);
      const body = await response.json() as any;
      const types = body.recommendations.map((item: any) => item.type);
      if (catalog === 'PREPARATION_21') {
        expect(types).toEqual(['PORTABLE_HUMIDIFIER']);
        expect(body.briefing.recommendedItems).toEqual(types);
        expect(body.lifestyleMessages.some((item: any) => item.type === 'DRYNESS_GUIDANCE')).toBe(true);
      } else {
        expect(types).not.toContain('LIP_BALM');
        expect(types).not.toContain('HAND_CREAM');
        expect(types).not.toContain('PORTABLE_HUMIDIFIER');
      }
    }
    const widget = await app.fetch(new Request('http://localhost/api/v1/weather/widget?nx=60&ny=127&recommendationCatalog=PREPARATION_21'), environment);
    expect(widget.status).toBe(200);
    expect(JSON.stringify(await widget.json())).toContain('휴대용 가습기');
  });
});
