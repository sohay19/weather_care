import type { WeatherSnapshot } from '../types';

export interface DailyWeatherSnapshot {
  temperature: number | null;
  apparentTemperature: number | null;
  pm10: number | null;
  pm25: number | null;
  skyCondition: string | null;
}

interface DailyWeatherSnapshotRow {
  temperature: number | null;
  apparent_temperature: number | null;
  pm10: number | null;
  pm25: number | null;
  summary: string | null;
}

export async function saveDailyWeatherSnapshot(
  db: D1Database,
  nx: number,
  ny: number,
  snapshot: WeatherSnapshot,
): Promise<void> {
  const observationDate = koreaDate(snapshot.observedAt);
  await db
    .prepare(
      `INSERT INTO daily_weather_snapshots
       (region_id, observation_date, temperature, apparent_temperature, pm10, pm25, summary)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(region_id, observation_date) DO UPDATE SET
         temperature=COALESCE(excluded.temperature, daily_weather_snapshots.temperature),
         apparent_temperature=COALESCE(excluded.apparent_temperature, daily_weather_snapshots.apparent_temperature),
         pm10=COALESCE(excluded.pm10, daily_weather_snapshots.pm10),
         pm25=COALESCE(excluded.pm25, daily_weather_snapshots.pm25),
         summary=COALESCE(excluded.summary, daily_weather_snapshots.summary)`,
    )
    .bind(
      `${nx}_${ny}`,
      observationDate,
      snapshot.temperature ?? null,
      snapshot.apparentTemperature ?? null,
      snapshot.pm10 ?? null,
      snapshot.pm25 ?? null,
      snapshot.skyCondition ?? null,
    )
    .run();
}

export async function getDailySnapshot(
  db: D1Database,
  nx: number,
  ny: number,
  date: string,
): Promise<DailyWeatherSnapshot | null> {
  const row = await db
    .prepare(
      `SELECT temperature, apparent_temperature, pm10, pm25, summary
       FROM daily_weather_snapshots
       WHERE region_id = ? AND observation_date = ?`,
    )
    .bind(`${nx}_${ny}`, date)
    .first<DailyWeatherSnapshotRow>();
  if (!row) return null;
  return {
    temperature: row.temperature,
    apparentTemperature: row.apparent_temperature,
    pm10: row.pm10,
    pm25: row.pm25,
    skyCondition: row.summary,
  };
}

function koreaDate(observedAt: string): string {
  const parsed = new Date(observedAt);
  if (Number.isNaN(parsed.getTime())) return observedAt.slice(0, 10);
  return new Date(parsed.getTime() + 9 * 60 * 60 * 1000)
    .toISOString()
    .slice(0, 10);
}
