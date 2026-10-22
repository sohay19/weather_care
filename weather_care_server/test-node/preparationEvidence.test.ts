import { describe, expect, it, vi } from 'vitest';
import { app } from '../src/index';
import { nodeServerEnv } from '../src/node/runtime';
import { runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';
import { saveCollectedCache } from '../src/database/collectedWeatherRepository';
import { preparationsForSnapshots } from '../src/recommendations/preparationPolicy';
import { runRecommendationEngine } from '../src/recommendations/recommendationEngine';
import { buildWeatherBriefResult } from '../src/presentation/weatherBrief';
import type { TodayWeatherResponse, WeatherSnapshot } from '../src/types';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';
import '../test/preparationPolicy.test';
import '../test/weatherBrief.test';

const snapshot = (changes: Partial<WeatherSnapshot>): WeatherSnapshot => ({
  observedAt: '2026-10-22T09:00:00+09:00', dataRole: 'FORECAST',
  provider: '기상청 단기예보', ...changes,
});
const forecast = (current: WeatherSnapshot, hourly: WeatherSnapshot[] = []): WeatherForecast => ({
  current, hourly, daily: [], baseDate: '20261022', baseTime: '0800', dataSource: '기상청',
});

describe('모든 준비물에 실제 판단 근거를 함께 보낸다', () => {
  it('Main·Today HTTP 응답에도 각 준비물의 실제 근거가 빠지지 않는다', async () => {
    const now = new Date('2026-10-22T09:10:00+09:00');
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(now);
    const database = new SqliteD1Database(':memory:');
    try {
      runSqliteMigrations(database);
      const env = nodeServerEnv(database, {});
      const current = snapshot({ temperature: 8, forecastAt: '2026-10-22T09:00:00+09:00', validTo: '2026-10-22T10:00:00+09:00' });
      await saveCollectedCache(env.DB, {
        key: 'COLLECTED_REGION_60_127', type: 'COLLECTED_REGION', nx: 60, ny: 127, updatedAt: now,
        value: { forecast: forecast(current, [current]), environmental: { sources: {
          uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNAVAILABLE' },
          airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' },
        } } },
      });
      for (const endpoint of ['main', 'today']) {
        const response = await app.fetch(new Request(
          `http://localhost/api/v1/weather/${endpoint}?nx=60&ny=127&recommendationCatalog=PREPARATION_18`), env);
        expect(response.status).toBe(200);
        const body = await response.json() as TodayWeatherResponse;
        expect(body.briefing?.recommendedItems).toContain('OUTERWEAR');
        for (const item of body.briefing!.recommendedItems) {
          expect(body.briefing!.preparationEvidence?.[item]?.length).toBeGreaterThan(0);
        }
        expect(body.briefing!.preparationEvidence?.OUTERWEAR?.[0].text).toContain('기온 8℃');
        if (endpoint === 'today') {
          const outerwear = body.recommendations.find((item) => item.type === 'OUTERWEAR')!;
          expect(outerwear.recommended).toBe(true);
          expect(outerwear.evidence?.[0].text).toContain('기온 8℃');
          expect(outerwear.evidence?.[1].text).toContain('기온 10℃ 이하');
        }
      }
    } finally {
      database.close();
      vi.useRealTimers();
    }
  });

  it('18종 전체에 실제 값·시각·출처와 적용 기준이 있다', () => {
    const cases = [
      { temperature: -1 }, { temperature: 17 }, { temperature: 34 },
      { precipitationType: 'RAIN' as const, precipitationAmount: 15 },
      { precipitationType: 'SNOW' as const, snowfallAmount: 5 },
      { precipitationType: 'SNOW' as const },
      { uvIndex: 8 }, { uvIndex: 7 }, { pm25: 40 },
    ];
    const seen = new Set<string>();
    for (const values of cases) {
      for (const item of preparationsForSnapshots([snapshot(values)])) {
        seen.add(item.type);
        expect(item.evidence).toHaveLength(2);
        expect(item.evidence[0].text).toContain('10월 22일 9시');
        expect(item.evidence[0].source).toBeTruthy();
        expect(item.evidence[0].validFrom).toBe('2026-10-22T09:00:00+09:00');
        expect(item.evidence[1].text).toContain('적용한 준비물 판단 기준:');
        expect(item.evidence[1].source).toBe('날씨챙겨 준비물 판단');
      }
    }
    expect(seen.size).toBe(18);
  });

  it('상위 겉옷은 실제로 10℃ 이하가 된 시간 자료를 보존한다', () => {
    const items = preparationsForSnapshots([
      snapshot({ temperature: 8, observedAt: '2026-10-22T12:00:00+09:00' }),
      snapshot({ temperature: 16 }),
    ]);
    const outerwear = items.find((item) => item.type === 'OUTERWEAR')!;
    expect(outerwear.evidence[0].text).toContain('12시 예보: 기온 8℃');
    expect(outerwear.evidence[1].text).toContain('기온 10℃ 이하');
    expect(outerwear.validFrom).toBe('2026-10-22T03:00:00.000Z');
  });

  it('체감 계산값을 공식 관측값으로 표시하지 않는다', () => {
    const item = preparationsForSnapshots([snapshot({
      temperature: 15, apparentTemperature: 8,
      apparentTemperatureSource: 'APP_KMA_METHOD_FROM_FORECAST',
    })])[0];
    expect(item.type).toBe('OUTERWEAR');
    expect(item.evidence[0]).toMatchObject({ role: 'CALCULATED_FACT', source: '날씨챙겨 체감온도 계산' });
    expect(item.evidence[0].text).toContain('체감온도 8℃');
    expect(item.evidence[1].text).toContain('체감온도 10℃ 이하');
  });

  it('추천 응답은 정책이 선택한 근거를 그대로 포함한다', () => {
    const snapshots = [snapshot({ temperature: 8, uvIndex: 7 })];
    const candidates = preparationsForSnapshots(snapshots);
    const recommendations = runRecommendationEngine([], undefined, { tieredPreparations: true, snapshots });
    for (const item of recommendations) {
      expect(item.evidence).toEqual(candidates.find((candidate) => candidate.type === item.type)!.evidence);
    }
  });

  it('대표 브리핑 주제와 무관하게 모든 준비물의 근거를 전달한다', () => {
    const input = forecast(snapshot({ temperature: 8, uvIndex: 7, precipitationType: 'SNOW', snowfallAmount: 1 }));
    const result = buildWeatherBriefResult(input, { now: new Date('2026-10-22T09:00:00+09:00'), tieredPreparations: true });
    expect(result.intent.sceneId).toBe('SNOW');
    expect(result.intent.recommendedItems).toContain('OUTERWEAR');
    expect(result.intent.recommendedItems).toContain('SUNSCREEN');
    for (const item of result.intent.recommendedItems) {
      expect(result.intent.preparationEvidence?.[item]?.length).toBeGreaterThan(0);
      expect(result.timeline[0].preparationEvidence?.[item]).toEqual(result.intent.preparationEvidence?.[item]);
    }
    expect(result.intent.preparationEvidence?.OUTERWEAR?.[0].text).toContain('기온 8℃');
    expect(result.intent.preparationEvidence?.SUNSCREEN?.[0].text).toContain('자외선지수 7');
  });

  it('유효한 시각과 자료가 없으면 근거 없는 준비물을 만들지 않는다', () => {
    expect(preparationsForSnapshots([snapshot({ observedAt: 'invalid', temperature: 8 })])).toEqual([]);
    expect(preparationsForSnapshots([snapshot({})])).toEqual([]);
  });
});
