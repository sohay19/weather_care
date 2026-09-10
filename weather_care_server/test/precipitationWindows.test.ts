import { describe, expect, it } from 'vitest';
import { buildForecastFromItems, KmaForecastItem } from '../src/providers/weather/kmaWeatherProvider';
import { runWeatherRuleEngine, runWeatherRuleEngineForHourly } from '../src/rules/weatherRuleEngine';
import { precipitationDecisionSnapshot, precipitationPeriod, periodLabel } from '../src/rules/precipitationWindows';
import { enrichTimeSeriesInsights } from '../src/lifestyle/timeSeriesLifestyleBuilder';
import { runLifestyleWeatherEngine } from '../src/lifestyle/lifestyleWeatherEngine';
import { buildLifestyleMessages } from '../src/presentation/lifestyleMessages';
import { buildWeatherBriefResult } from '../src/presentation/weatherBrief';
import { runRecommendationEngine } from '../src/recommendations/recommendationEngine';
import { buildNotification } from '../src/notification/notificationBuilder';
import { buildTimeline, recommendationsForDay } from '../src/api/weather';
import { WeatherSnapshot, WeatherRuleFactType as Fact, LifestyleInsightType as Insight } from '../src/types';

const base = { baseDate: '20260910', baseTime: '1100' };
const now = new Date('2026-09-10T13:10:00+09:00');
function items(date: string, time: string, overrides: Record<string, string> = {}): KmaForecastItem[] {
  return Object.entries({ TMP: '22', REH: '50', WSD: '2', PTY: '0', SKY: '1', POP: '0', PCP: '강수없음', SNO: '적설없음', ...overrides })
    .map(([category, fcstValue]) => ({ ...base, fcstDate: date, fcstTime: time, category, fcstValue, nx: 60, ny: 121 }));
}
function slot(hour: number, overrides: Partial<WeatherSnapshot> = {}): WeatherSnapshot {
  return { ...buildForecastFromItems(items('20260910', `${hour}00`), now, base).current,
    apparentTemperature: 22, uvIndex: 2, airQualityGrade: 'Good', ozoneGrade: 'Good', ...overrides };
}
function rain(hour: number, amount = 15): WeatherSnapshot {
  return slot(hour, { precipitationType: 'RAIN', precipitationProbability: 80, precipitationAmount: amount,
    precipitationAmountRange: { type: 'VALUE', min: amount, max: amount, unit: 'MM', rawValue: `${amount}mm` } });
}
const findFact = (hourly: WeatherSnapshot[], type: Fact, reference?: Date) =>
  runWeatherRuleEngineForHourly(hourly, undefined, reference).find((item) => item.type === type);

describe('element-specific precipitation windows', () => {
  it('adds the previous-hour window without moving point temperature or wind', () => {
    const sample = slot(15, { windSpeed: 15 });
    expect(sample.forecastAt).toBe('2026-09-10T15:00:00+09:00');
    expect(sample.validFrom).toBe(sample.forecastAt);
    expect(sample.precipitationPeriod).toEqual({ start: '2026-09-10T05:00:00.000Z', end: sample.forecastAt });
    expect(findFact([sample], Fact.STRONG_WIND)?.validFrom).toBe(sample.forecastAt);
  });

  it('uses the same interval for single-slot and series rain and snow rules', () => {
    const sample = rain(15);
    const single = runWeatherRuleEngine(sample).find((item) => item.type === Fact.HEAVY_RAIN);
    expect(single).toEqual(findFact([sample], Fact.HEAVY_RAIN));
    expect(single).toMatchObject({ validFrom: '2026-09-10T05:00:00.000Z', validUntil: '2026-09-10T05:59:59.999Z' });
    const snowy = slot(15, { precipitationType: 'SNOW', snowfallAmount: 5,
      snowfallAmountRange: { type: 'VALUE', min: 5, max: 5, unit: 'CM', rawValue: '5cm' } });
    expect(findFact([snowy], Fact.HEAVY_SNOW)?.validFrom).toBe(single?.validFrom);
  });

  it('does not let elapsed stronger rain hide weaker future rain or trigger notifications', () => {
    const hourly = [rain(14, 50), rain(16, 15)];
    const reference = new Date('2026-09-10T15:00:00+09:00');
    const facts = runWeatherRuleEngineForHourly(hourly, undefined, reference);
    expect(facts.find((item) => item.type === Fact.HEAVY_RAIN)?.validFrom).toBe(hourly[1].precipitationPeriod?.start);
    const recommendations = runRecommendationEngine(runLifestyleWeatherEngine(facts, hourly, reference));
    expect(buildNotification(recommendations, reference)[0].body).toContain('오후 3시~4시');
    expect(buildNotification(recommendations, new Date('2026-09-10T16:00:00+09:00'))).toEqual([]);
    expect(findFact([rain(14)], Fact.HEAVY_RAIN, new Date('2026-09-10T14:00:00+09:00'))).toBeUndefined();
  });

  it('preserves raw expired values for display and leaves instant values available', () => {
    const sample = rain(14);
    const decision = precipitationDecisionSnapshot(sample, new Date('2026-09-10T14:01:00+09:00'));
    expect(decision.precipitationProbability).toBeUndefined();
    expect(decision.temperature).toBe(22);
    expect(sample.precipitationProbability).toBe(80);
  });

  it('matches grounding to the rain interval, not the adjacent point timestamp', () => {
    const hourly = [rain(14, 5), rain(15, 30)];
    const facts = runWeatherRuleEngineForHourly(hourly);
    const messages = buildLifestyleMessages(runLifestyleWeatherEngine(facts, hourly), facts, hourly, '수원');
    const message = messages.find((item) => item.type === Insight.RAIN_GEAR_USEFUL)!;
    expect(message.parts.find((item) => item.role === 'OFFICIAL_FACT')).toMatchObject({
      text: '기상청은 수원에 오후 2시~3시 시간당 30mm의 비를 예보했어요',
      validFrom: hourly[1].precipitationPeriod?.start,
    });
    expect(message.description).toContain('오후 2시~3시');
  });

  it('brief and today timeline label rain separately from the 15:00 temperature', () => {
    const sample = rain(15);
    const forecast = { current: sample, hourly: [sample], daily: [], ...base, dataSource: '기상청' };
    expect(buildWeatherBriefResult(forecast).slots.eventTime).toBe('오후 2시~3시');
    const timeline = buildTimeline([sample])[0];
    expect(timeline.timeLabel).toBe('15');
    expect(timeline.detail).toContain('예상기온 22.0℃');
    expect(timeline.detail).toContain('오후 2시~3시 강수 예보');
    expect(timeline.stateLabel).toContain('오후 2시~3시');
    expect(buildTimeline([slot(15, { precipitationProbability: undefined })])[0].detail).toContain('강수확률 자료 없음');
  });

  it('uses the precipitation start for laundry deadlines and replaces past deadlines with now', () => {
    const future = enrichTimeSeriesInsights([slot(14), rain(16)], now)
      .find((item) => item.type === Insight.LAUNDRY_PICKUP_DUE)!;
    expect(future.context).toMatchObject({ actionDeadline: '오후 2시 30분', actionNow: false, validFrom: '2026-09-10T06:00:00.000Z' });
    const imminent = runLifestyleWeatherEngine([], [rain(14)], now);
    expect(buildLifestyleMessages(imminent, [], [rain(14)])[0].title).toContain('지금 실내로');
    expect(enrichTimeSeriesInsights([rain(14)], new Date('2026-09-10T14:00:00+09:00'))
      .some((item) => item.type === Insight.LAUNDRY_PICKUP_DUE)).toBe(false);
  });

  it('uses ISO validity and the true dry period in rain-break messages', () => {
    const insight = enrichTimeSeriesInsights([rain(14), slot(15), slot(16), rain(17)])
      .find((item) => item.type === Insight.RAIN_BREAK_WINDOW)!;
    expect(insight.context).toMatchObject({ validFrom: '2026-09-10T05:00:00.000Z',
      validUntil: '2026-09-10T06:59:59.999Z', timeLabel: '오후 2시~4시' });
    expect(buildLifestyleMessages([insight])[0].description).toBe('오후 2시~4시에는 비가 잠시 그칠 수 있어요.');
  });

  it('does not recommend walking using dry weather from the preceding hour', () => {
    // 14:00 is dry for 13–14, but 14–15 has rain. There are not two safe hours.
    const unsafe = enrichTimeSeriesInsights([slot(14), rain(15), slot(16)]);
    expect(unsafe.some((item) => item.type === Insight.PET_WALK_WINDOW)).toBe(false);
    const safe = enrichTimeSeriesInsights([slot(14), slot(15), slot(16), rain(17)])
      .find((item) => item.type === Insight.PET_WALK_WINDOW);
    expect(safe?.context?.timeLabel).toBe('오후 2시~4시');
    expect(enrichTimeSeriesInsights([slot(14), slot(15)]).some((item) => item.type === Insight.PET_WALK_WINDOW)).toBe(false);
  });

  it('does not bridge a missing hour in an active precipitation run', () => {
    const fact = findFact([rain(14, 1), rain(15, 1), rain(18, 1)], Fact.RAIN_LIKELY);
    expect(fact?.validUntil).toBe('2026-09-10T05:59:59.999Z');
  });

  it('marks extended 3-hour qualitative data as unsupported for hourly decisions', () => {
    const forecast = buildForecastFromItems([
      ...items('20260913', '0300', { PCP: '3', SNO: '3', POP: '100', PTY: '3' }),
    ], new Date('2026-09-13T01:00:00+09:00'), base);
    expect(forecast.current.precipitationPeriod).toBeNull();
    expect(runWeatherRuleEngineForHourly(forecast.hourly).some((item) => [Fact.HEAVY_RAIN, Fact.RAIN_LIKELY, Fact.SNOW_LIKELY, Fact.HEAVY_SNOW].includes(item.type))).toBe(false);
  });

  it('handles midnight across year boundaries', () => {
    const forecast = buildForecastFromItems(items('20270101', '0000'), new Date('2026-12-31T23:10:00+09:00'), { baseDate: '20261231', baseTime: '2000' });
    expect(forecast.current.precipitationPeriod?.start).toBe('2026-12-31T14:00:00.000Z');
    expect(periodLabel(forecast.current.precipitationPeriod!.start, forecast.current.forecastAt!)).toBe('오후 11시~다음 날 오전 12시');
  });

  it('assigns midnight rain to the previous daily recommendations but not midnight wind', () => {
    const forecast = buildForecastFromItems(items('20260911', '0000', { PCP: '30mm', POP: '90', PTY: '1', WSD: '15' }), now, base);
    const before = recommendationsForDay({ date: '20260910', skyCondition: '비', precipitationProbability: 0, precipitationAmount: 0, snowProbability: 0, snowfallAmount: 0 }, forecast.hourly);
    const after = recommendationsForDay(forecast.daily[0], forecast.hourly);
    expect(before.map((item) => item.type)).toContain('UMBRELLA');
    expect(after.map((item) => item.type)).not.toContain('UMBRELLA');
  });

  it('includes the date when the future rain belongs to another day', () => {
    const forecast = buildForecastFromItems(items('20260911', '0100', { PCP: '30mm', POP: '90', PTY: '1' }), now, base);
    expect(buildWeatherBriefResult(forecast).slots.eventTime).toBe('9월 11일 오전 12시~1시');
    const facts = runWeatherRuleEngineForHourly(forecast.hourly);
    const recs = runRecommendationEngine(runLifestyleWeatherEngine(facts, forecast.hourly));
    expect(buildNotification(recs, now)[0].body).toContain('9월 11일 오전 12시~1시');
  });

  it('rejects invalid interval lengths/ends while keeping legacy providers compatible', () => {
    const sample = rain(15);
    for (const period of [null, { start: 'bad', end: sample.forecastAt! },
      { start: '2026-09-10T13:00:00+09:00', end: sample.forecastAt! },
      { start: '2026-09-10T13:00:00+09:00', end: '2026-09-10T14:00:00+09:00' }]) {
      expect(precipitationPeriod({ ...sample, precipitationPeriod: period })).toBeUndefined();
      expect(findFact([{ ...sample, precipitationPeriod: period }], Fact.HEAVY_RAIN)).toBeUndefined();
    }
    expect(findFact([{ ...sample, precipitationPeriod: undefined }], Fact.HEAVY_RAIN)?.validFrom).toBe(sample.forecastAt);
  });
});
