import { getCollectedCache, saveCollectedCache } from '../database/collectedWeatherRepository';

export async function readObservedDailyHumidity(
  db: D1Database, date: string, nx: number, ny: number, now: Date,
): Promise<number | undefined> {
  const key = `OBSERVED_DAILY_HUMIDITY_${date}_${nx}_${ny}`;
  const cached = await getCollectedCache<number>(db, key);
  if (cached) return cached.value;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) ||
      !Number.isInteger(nx) || nx < 1 || nx > 149 ||
      !Number.isInteger(ny) || ny < 1 || ny > 253) return undefined;
  const start = Date.parse(`${date}T00:00:00+09:00`);
  if (!Number.isFinite(start) || start + 86_400_000 > now.getTime()) return undefined;
  const index = (ny - 1) * 149 + nx - 1;
  const rows = await db.prepare(`SELECT observed_at AS observedAt,
      json_extract(payload, '$.fields.REH.values[${index}]') AS humidity
    FROM grid_observation_snapshots WHERE observed_at >= ? AND observed_at < ?
    ORDER BY observed_at`)
    .bind(new Date(start).toISOString(), new Date(start + 86_400_000).toISOString())
    .all<{ observedAt: string; humidity: number | null }>();
  const hourly = new Map<number, number[]>();
  for (const row of rows.results) {
    const hour = Math.floor((Date.parse(row.observedAt) - start) / 3_600_000);
    if (hour < 0 || hour >= 24 || row.humidity === null ||
        !Number.isFinite(row.humidity) || row.humidity < 0 || row.humidity > 100) continue;
    hourly.set(hour, [...hourly.get(hour) ?? [], row.humidity]);
  }
  if (hourly.size !== 24) return undefined;
  const average = [...hourly.values()].reduce((sum, values) =>
    sum + values.reduce((hourSum, value) => hourSum + value, 0) / values.length, 0) / 24;
  await saveCollectedCache(db, { key, type: 'OBSERVED_DAILY_HUMIDITY', value: average, updatedAt: now });
  return average;
}

export async function archiveActiveDailyHumidity(
  db: D1Database, now: Date, grids: readonly { nx: number; ny: number }[],
): Promise<void> {
  if (!grids.length) return;
  const yesterday = new Date(now.getTime() + 9 * 3_600_000 - 86_400_000)
    .toISOString().slice(0, 10);
  const unique = [...new Map(grids.map(grid => [`${grid.nx}:${grid.ny}`, grid])).values()];
  const dayBefore = new Date(Date.parse(`${yesterday}T00:00:00Z`) - 86_400_000)
    .toISOString().slice(0, 10);
  for (const date of [dayBefore, yesterday]) {
    const start = Date.parse(`${date}T00:00:00+09:00`);
    const missing = [];
    for (const grid of unique) {
      const key = `OBSERVED_DAILY_HUMIDITY_${date}_${grid.nx}_${grid.ny}`;
      if (!await getCollectedCache<number>(db, key)) missing.push(grid);
    }
    if (!missing.length) continue;
    const times = await db.prepare(`SELECT observed_at AS observedAt FROM grid_observation_snapshots
      WHERE observed_at >= ? AND observed_at < ? ORDER BY observed_at`)
      .bind(new Date(start).toISOString(), new Date(start + 86_400_000).toISOString())
      .all<{ observedAt: string }>();
    if (new Set(times.results.map(row => Math.floor((Date.parse(row.observedAt) - start) / 3_600_000))).size !== 24) continue;
    const sums = missing.map(() => Array<number>(24).fill(0));
    const counts = missing.map(() => Array<number>(24).fill(0));
    for (const row of times.results) {
      const payload = await db.prepare('SELECT payload FROM grid_observation_snapshots WHERE observed_at=?')
        .bind(row.observedAt).first<{ payload: string }>();
      const values = (JSON.parse(payload!.payload) as { fields?: { REH?: { values?: number[] } } })
        .fields?.REH?.values;
      if (!values) continue;
      const hour = Math.floor((Date.parse(row.observedAt) - start) / 3_600_000);
      missing.forEach((grid, i) => {
        const value = values[(grid.ny - 1) * 149 + grid.nx - 1];
        if (Number.isFinite(value) && value >= 0 && value <= 100) {
          sums[i][hour] += value;
          counts[i][hour]++;
        }
      });
    }
    for (let i = 0; i < missing.length; i++) {
      if (counts[i].some(count => count === 0)) continue;
      const grid = missing[i];
      const average = sums[i].reduce((sum, value, hour) => sum + value / counts[i][hour], 0) / 24;
      await saveCollectedCache(db, {
        key: `OBSERVED_DAILY_HUMIDITY_${date}_${grid.nx}_${grid.ny}`,
        type: 'OBSERVED_DAILY_HUMIDITY', value: average, updatedAt: now,
      });
    }
  }
}
