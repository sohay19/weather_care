import { getCollectedCache, saveCollectedCache } from '../database/collectedWeatherRepository';
import { AIRKOREA_PROVINCES, nearestAirStations, type AirStationCatalog } from '../providers/air/airKoreaAirQualityProvider';
import type { AirQualitySnapshot } from '../providers/air/airQualityProvider';

const historyKey = (date: string, province: string) => `AIR_HISTORY_${date}_${province}`;

export interface DailyAirQualityObservation {
  stationName: string;
  observedHours: number;
  pm10?: number;
  pm25?: number;
  ozone?: number;
}

export async function saveAirQualityHistory(
  db: D1Database, province: string, observations: AirQualitySnapshot[], now: Date,
): Promise<void> {
  const byDate = new Map<string, AirQualitySnapshot[]>();
  for (const item of observations) {
    const date = new Date(Date.parse(item.observedAt) + 9 * 3_600_000).toISOString().slice(0, 10);
    byDate.set(date, [...byDate.get(date) ?? [], item]);
  }
  for (const [date, incoming] of byDate) {
    const key = historyKey(date, province);
    const existing = await getCollectedCache<AirQualitySnapshot[]>(db, key);
    const records = new Map((existing?.value ?? []).map(item => [`${item.stationName}:${item.observedAt}`, item]));
    for (const item of incoming) records.set(`${item.stationName}:${item.observedAt}`, item);
    await saveCollectedCache(db, { key, type: 'AIR_HISTORY', value: [...records.values()], updatedAt: now });
  }
  const cutoff = new Date(now.getTime() + 9 * 3_600_000 - 8 * 86_400_000).toISOString().slice(0, 10);
  await db.prepare("DELETE FROM weather_cache WHERE cache_type='AIR_HISTORY' AND cache_key < ?")
    .bind(`AIR_HISTORY_${cutoff}_`).run();
}

export async function readDailyAirQualityObservation(
  db: D1Database, date: string, catalog: AirStationCatalog,
  coordinates: { latitude: number; longitude: number },
): Promise<DailyAirQualityObservation | undefined> {
  const archives = await Promise.all([...AIRKOREA_PROVINCES, '전국'].map(province =>
    getCollectedCache<AirQualitySnapshot[]>(db, historyKey(date, province))));
  const byStation = new Map<string, Map<string, AirQualitySnapshot>>();
  for (const archive of archives) for (const item of archive?.value ?? []) {
    const records = byStation.get(item.stationName) ?? new Map<string, AirQualitySnapshot>();
    records.set(item.observedAt, item);
    byStation.set(item.stationName, records);
  }
  const station = nearestAirStations(catalog, coordinates.latitude, coordinates.longitude)
    .find(item => byStation.has(item.stationName));
  if (!station) return undefined;
  const records = [...byStation.get(station.stationName)!.values()];
  const mean = (values: (number | undefined)[]) => {
    const valid = values.filter((value): value is number => value !== undefined && Number.isFinite(value));
    return valid.length ? valid.reduce((sum, value) => sum + value, 0) / valid.length : undefined;
  };
  return {
    stationName: station.stationName,
    observedHours: new Set(records.map(item => item.observedAt.slice(0, 13))).size,
    pm10: mean(records.map(item => item.pm10)),
    pm25: mean(records.map(item => item.pm25)),
    ozone: mean(records.map(item => item.ozone)),
  };
}
