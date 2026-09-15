import { env } from 'cloudflare:test';
import { beforeAll, describe, expect, it } from 'vitest';
import migration from '../migrations/0010_weekly_forecast_records.sql?raw';
import {
  currentKoreanCalendarWeek,
  getWeeklyForecastRecords,
  saveWeeklyForecastRecords,
} from '../src/database/weeklyForecastRepository';
import type { DailyWeatherForecast } from '../src/providers/weather/weatherProvider';

const apply = (sql: string) => env.DB.exec(
  sql.replace(/--[^\n]*/g, '').replace(/\r?\n/g, ' '),
);

beforeAll(async () => {
  await apply(migration);
  await env.DB.prepare("DELETE FROM weekly_forecast_records WHERE region_id LIKE 'test_week_%'").run();
});

describe('weekly forecast history', () => {
  it('keeps a passed date unchanged and updates only dates that are current or future', async () => {
    const regionId = 'test_week_preserve';
    await saveWeeklyForecastRecords(env.DB, regionId, [day('20260915', 25)],
      new Date('2026-09-15T03:00:00Z'));
    await saveWeeklyForecastRecords(env.DB, regionId, [
      day('20260915', 99),
      day('20260916', 26),
    ], new Date('2026-09-16T03:00:00Z'));

    const saved = await getWeeklyForecastRecords(
      env.DB,
      regionId,
      '2026-09-14',
      '2026-09-20',
    );
    expect(saved.map((item) => [item.date, item.maxTemperature])).toEqual([
      ['20260915', 25],
      ['20260916', 26],
    ]);
    expect(saved.every((item) => item.recordedAt != null)).toBe(true);
  });

  it('calculates a Sunday-through-Saturday week in Korean time', () => {
    expect(currentKoreanCalendarWeek(new Date('2026-09-15T00:00:00Z'))).toEqual({
      startDate: '2026-09-13',
      endDate: '2026-09-19',
      dates: [
        '2026-09-13', '2026-09-14', '2026-09-15', '2026-09-16',
        '2026-09-17', '2026-09-18', '2026-09-19',
      ],
    });
  });
});

function day(date: string, maximum: number): DailyWeatherForecast {
  return {
    date,
    forecastSource: 'KMA_SHORT_TERM',
    issuedAt: `${date.slice(0, 4)}-${date.slice(4, 6)}-${date.slice(6, 8)}T06:00:00+09:00`,
    minTemperature: 15,
    maxTemperature: maximum,
    skyCondition: '맑음',
    precipitationProbability: 0,
    precipitationAmount: 0,
    snowProbability: 0,
    snowfallAmount: 0,
  };
}
