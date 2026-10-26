import { describe, expect, it } from 'vitest';
import { withLivingIndexAdvice, ventilationAdvice, pollenEvidence } from '../src/services/livingIndexAdvice';
import { runRecommendationEngine } from '../src/recommendations/recommendationEngine';
import { runLifestyleWeatherEngine } from '../src/lifestyle/lifestyleWeatherEngine';
import { runWeatherRuleEngineForHourly } from '../src/rules/weatherRuleEngine';
import { buildWeatherBriefResult } from '../src/presentation/weatherBrief';
import type { TodayLivingIndices, WeatherSnapshot } from '../src/types';
import type { WeatherForecast } from '../src/providers/weather/weatherProvider';

const now = new Date('2026-10-26T10:00:00+09:00');
const index: TodayLivingIndices = { pollenStatus: 'AVAILABLE',
  pollen: [{ species: '잡초류', level: '높음', issuedAt: '2026-10-26T06:00:00+09:00' }],
  airStagnation: { level: '높음', issuedAt: '2026-10-26T06:00:00+09:00', forecastAt: '2026-10-26T09:00:00+09:00' } };
const snapshot: WeatherSnapshot = { observedAt: now.toISOString(), temperature: 20,
  pm10: 20, pm25: 10, airQualityObservedAt: now.toISOString() };
const forecast: WeatherForecast = { current: snapshot, hourly: [snapshot], daily: [],
  baseDate: '20261026', baseTime: '0800', dataSource: '기상청' };

describe('꽃가루 추천과 대기정체 환기 안내', () => {
  it('대기질이 좋아도 꽃가루 높음은 기존 마스크 하나를 추천하고 근거를 남긴다', () => {
    const enriched = withLivingIndexAdvice(forecast, index, now);
    for (const tieredPreparations of [true, false]) {
      const facts = runWeatherRuleEngineForHourly(enriched.hourly);
      const insights = runLifestyleWeatherEngine(facts, enriched.hourly, now);
      const recs = runRecommendationEngine(insights, undefined,
        { tieredPreparations, expandedPreparations: true, snapshots: enriched.hourly, facts });
      const masks = recs.filter((rec) => rec.type === 'MASK');
      expect(masks).toHaveLength(1);
      expect(masks[0].recommended).toBe(true);
      expect(masks[0].reasons.join()).toContain('꽃가루');
      expect(masks[0].evidence?.some((part) => part.source === '기상청 꽃가루농도위험지수')).toBe(true);
    }
    const brief = buildWeatherBriefResult(enriched, { now, tieredPreparations: true });
    expect(brief.intent.recommendedItems).toContain('MASK');
    expect(runRecommendationEngine([], { maskEnabled: false },
      { tieredPreparations: true, snapshots: enriched.hourly }).find((rec) => rec.type === 'MASK')?.recommended).toBe(false);
  });

  it('두 원인이 동시에 있어도 마스크는 하나이고 양쪽 공식 근거가 있다', () => {
    const enriched = withLivingIndexAdvice({ ...forecast,
      hourly: [{ ...snapshot, pm10: 120, pm25: 50 }] }, index, now);
    const recs = runRecommendationEngine([], undefined, { tieredPreparations: true, snapshots: enriched.hourly });
    const mask = recs.filter((rec) => rec.type === 'MASK');
    expect(mask).toHaveLength(1);
    expect(mask[0].reasons).toContain('미세먼지·꽃가루 대비');
    expect(mask[0].evidence?.map((part) => part.source)).toEqual(expect.arrayContaining(['에어코리아', '기상청 꽃가루농도위험지수']));
  });

  it('보통·비제공 계절·결측·오래된 발표·미래 발표는 마스크 원인으로 쓰지 않는다', () => {
    for (const value of [
      { ...index, pollen: [{ ...index.pollen[0], level: '보통' }] },
      { ...index, pollenStatus: 'OUT_OF_SEASON' as const },
      { ...index, pollenStatus: 'UNAVAILABLE' as const },
      { ...index, pollen: [{ ...index.pollen[0], issuedAt: '2026-10-24T06:00:00+09:00' }] },
      { ...index, pollen: [{ ...index.pollen[0], issuedAt: '2026-10-27T06:00:00+09:00' }] },
    ]) {
      expect(pollenEvidence(withLivingIndexAdvice(forecast, value, now).current)).toEqual([]);
    }
    const tomorrow = { ...snapshot, observedAt: '2026-10-27T00:00:00+09:00' };
    expect(withLivingIndexAdvice({ ...forecast, hourly: [tomorrow] }, index, now).hourly[0].pollenForecast).toBeUndefined();
  });

  it('정체 높음 자체를 나쁜 대기질로 해석하지 않고 농도와 결측·유효시각을 구분한다', () => {
    const good = ventilationAdvice(snapshot, index, now)[0];
    expect(good.title).toContain('다시 확인');
    expect(good.title).not.toContain('환기는 짧게');
    const poor = ventilationAdvice({ ...snapshot, pm25: 50 }, index, now)[0];
    expect(poor.title).toContain('짧게 나누세요');
    expect(poor.parts.some((part) => part.source === '에어코리아')).toBe(true);
    expect(ventilationAdvice({ ...snapshot, pm25: undefined }, index, now)[0].parts.some((part) => part.role === 'DATA_STATUS')).toBe(true);
    expect(ventilationAdvice({ ...snapshot, airQualityObservedAt: '2026-10-26T01:00:00+09:00' }, index, now)[0].title).toContain('최신');
    expect(ventilationAdvice(snapshot, { ...index, airStagnation: undefined }, now)).toEqual([]);
    expect(ventilationAdvice(snapshot, index, new Date('2026-10-26T20:00:00+09:00'))).toEqual([]);
    const ozone = ventilationAdvice({ ...snapshot, ozone: 0.15 }, index, now)[0];
    expect(ozone.title).toContain('짧게 나누세요');
    expect(ozone.parts.some((part) => part.text.includes('오존 0.15ppm'))).toBe(true);
    expect(ventilationAdvice(snapshot, { ...index, airStagnation: {
      ...index.airStagnation!, issuedAt: '2026-10-26T11:00:00+09:00',
    } }, now)).toEqual([]);
  });
});
