import { DailyWeatherForecast } from '../providers/weather/weatherProvider';

interface WeeklyForecastRow {
  forecast_date: string;
  forecast_payload: string;
  recorded_at: string;
}

export async function saveWeeklyForecastRecords(
  db: D1Database,
  regionId: string,
  days: DailyWeatherForecast[],
  now = new Date(),
): Promise<void> {
  const today = koreanCalendarDate(now);
  const recordedAt = now.toISOString();
  const statements = days
    .filter((day) => compactToCalendarDate(day.date) >= today)
    .map((day) => db.prepare(
      `INSERT INTO weekly_forecast_records
       (region_id, forecast_date, forecast_payload, source, issued_at, recorded_at)
       VALUES (?, ?, ?, ?, ?, ?)
       ON CONFLICT(region_id, forecast_date) DO UPDATE SET
         forecast_payload=excluded.forecast_payload,
         source=excluded.source,
         issued_at=excluded.issued_at,
         recorded_at=excluded.recorded_at`,
    ).bind(
      regionId,
      compactToCalendarDate(day.date),
      JSON.stringify(day),
      day.forecastSource ?? 'KMA_SHORT_TERM',
      day.issuedAt ?? null,
      recordedAt,
    ));
  if (statements.length > 0) await db.batch(statements);
}

export async function getWeeklyForecastRecords(
  db: D1Database,
  regionId: string,
  startDate: string,
  endDate: string,
): Promise<DailyWeatherForecast[]> {
  const result = await db.prepare(
    `SELECT forecast_date, forecast_payload, recorded_at
     FROM weekly_forecast_records
     WHERE region_id = ? AND forecast_date BETWEEN ? AND ?
     ORDER BY forecast_date`,
  ).bind(regionId, startDate, endDate).all<WeeklyForecastRow>();

  return result.results.flatMap((row) => {
    try {
      const parsed = JSON.parse(row.forecast_payload) as unknown;
      if (!isDailyWeatherForecast(parsed) || compactToCalendarDate(parsed.date) !== row.forecast_date) {
        return [];
      }
      return [{ ...parsed, recordedAt: row.recorded_at }];
    } catch {
      return [];
    }
  });
}

export function koreanCalendarDate(now: Date): string {
  return new Date(now.getTime() + 9 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
}

export function currentKoreanCalendarWeek(now: Date): {
  startDate: string;
  endDate: string;
  dates: string[];
} {
  const today = koreanCalendarDate(now);
  const parsed = new Date(`${today}T00:00:00Z`);
  const sunday = new Date(parsed.getTime() - parsed.getUTCDay() * 86_400_000);
  const dates = Array.from({ length: 7 }, (_, index) =>
    new Date(sunday.getTime() + index * 86_400_000).toISOString().slice(0, 10),
  );
  return { startDate: dates[0], endDate: dates[6], dates };
}

function compactToCalendarDate(value: string): string {
  return /^\d{8}$/.test(value)
    ? `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`
    : value;
}

function isDailyWeatherForecast(value: unknown): value is DailyWeatherForecast {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false;
  const day = value as Record<string, unknown>;
  return typeof day.date === 'string' && /^\d{8}$/.test(day.date) &&
    typeof day.skyCondition === 'string' &&
    typeof day.precipitationProbability === 'number' &&
    typeof day.precipitationAmount === 'number' &&
    typeof day.snowProbability === 'number' &&
    typeof day.snowfallAmount === 'number';
}
