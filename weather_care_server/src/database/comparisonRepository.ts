export async function getDailySnapshot(db: any, nx: number, ny: number, date: string): Promise<any | null> {
  const row = await db
    .prepare(
      `SELECT temperature, apparent_temperature, pm10, pm25, pm25, observed_at
       FROM daily_weather_snapshots WHERE region_id = ? AND observation_date = ?`,
    )
    .bind(`${nx}_${ny}`, date)
    .first();
  return row ?? null;
}

