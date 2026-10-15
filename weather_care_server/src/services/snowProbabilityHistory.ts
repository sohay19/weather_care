import { readNationwideForecast } from '../database/nationwideForecastRepository';
import { saveWeeklyForecastRecords } from '../database/weeklyForecastRepository';
import { readCachedMidTermForecast } from './midTermForecastCache';
import { readPointForecast } from './pointForecastCache';
import type { NationwideLocation } from '../regions/nationwideLocation';

/** 이미 수집한 예보를 보관한다. 외부 API는 호출하지 않는다. */
export async function archiveSnowProbabilityForecasts(
  db: D1Database, now: Date, locations: readonly NationwideLocation[] = [],
): Promise<void> {
  const saved = await db.prepare('SELECT DISTINCT region_id AS regionId FROM weekly_forecast_records')
    .all<{ regionId: string }>();
  const previousLocations = saved.results.flatMap(({ regionId }) => {
    const match = /^(\d+)_(\d+)$/.exec(regionId);
    return match ? [{ nx: Number(match[1]), ny: Number(match[2]) }] : [];
  });
  const unique = new Map([...previousLocations, ...locations].map(location =>
    [`${location.nx}_${location.ny}`, location]));
  for (const [regionId, location] of unique) {
    const [point, nationwide, mid] = await Promise.all([
      readPointForecast(db, location.nx, location.ny, now),
      readNationwideForecast(db, location.nx, location.ny, now),
      readCachedMidTermForecast({ db, location, now }),
    ]);
    const days = new Map(mid.days.map(day => [day.date, day]));
    for (const day of (point ?? nationwide)?.daily ?? []) days.set(day.date, day);
    await saveWeeklyForecastRecords(db, regionId, [...days.values()]
      .filter(day => day.snowProbabilitySource === 'KMA_PRECIPITATION_FORECAST'), now);
  }
}
