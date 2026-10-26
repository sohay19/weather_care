import { getCollectedCache, saveCollectedCache } from '../database/collectedWeatherRepository';
import { snowStationIsFresh, type SnowSnapshot, type SnowStation } from '../providers/weather/kmaSnowObservationProvider';
import { coordinatesForLocation, type NationwideLocation } from '../regions/nationwideLocation';
import { greatCircleDistanceKm } from './nearbyGridObservation';
import type { SnowDepthObservation } from '../types';

const PREFIX = 'COLLECTED_SNOW_HISTORY_';
const kstHour = (time: string) => new Date(Date.parse(time) + 9 * 3_600_000).toISOString().replace(/[-:T]/g, '').slice(0, 10);
const validStation = (station: SnowStation | undefined | null): station is SnowStation =>
  !!station && typeof station.stationId === 'string' && station.stationId.length > 0 &&
  Number.isFinite(Date.parse(station.observedAt)) && snowStationIsFresh(station, new Date(station.observedAt));

/** 기존 수집 결과만 보관한다. 시각별 최신 관측을 남기며 추가 제공처 호출은 없다. */
export async function archiveSnowDepth(db: D1Database, snapshot: SnowSnapshot, now: Date): Promise<void> {
  const groups = new Map<string, SnowStation[]>();
  for (const station of snapshot.stations) {
    if (!snowStationIsFresh(station, now)) continue;
    const key = PREFIX + kstHour(station.observedAt);
    const rows = groups.get(key) ?? [];
    rows.push(station);
    groups.set(key, rows);
  }
  for (const [key, stations] of groups) {
    const previous = await getCollectedCache<Record<string, SnowStation>>(db, key);
    const byStation = new Map<string, SnowStation>();
    for (const station of [...Object.values(previous?.value ?? {}), ...stations]) {
      if (!validStation(station)) continue;
      if (!byStation.has(station.stationId) ||
          Date.parse(station.observedAt) > Date.parse(byStation.get(station.stationId)!.observedAt)) {
        byStation.set(station.stationId, station);
      }
    }
    await saveCollectedCache(db, { key, type: 'COLLECTED_SNOW_HISTORY',
      value: Object.fromEntries(byStation), updatedAt: now });
  }
  await db.prepare('DELETE FROM weather_cache WHERE cache_key >= ? AND cache_key < ?')
    .bind(PREFIX, PREFIX + kstHour(new Date(now.getTime() - 48 * 3_600_000).toISOString())).run();
}

export function selectSnowDepthHistory(stations: SnowStation[], location: NationwideLocation,
  now: Date): SnowDepthObservation[] {
  const coordinates = coordinatesForLocation(location);
  if (!coordinates) return [];
  const today = kstHour(now.toISOString()).slice(0, 8);
  const valid = stations.filter((station) => validStation(station) &&
    Date.parse(station.observedAt) <= now.getTime() && kstHour(station.observedAt).startsWith(today));
  const nearest = [...valid].sort((a, b) => greatCircleDistanceKm(coordinates, a) -
    greatCircleDistanceKm(coordinates, b) || a.stationId.localeCompare(b.stationId))[0];
  if (!nearest) return [];
  const hours = new Map<string, SnowStation>();
  for (const station of valid.filter((row) => row.stationId === nearest.stationId)) {
    const hour = kstHour(station.observedAt);
    if (!hours.has(hour) || Date.parse(station.observedAt) > Date.parse(hours.get(hour)!.observedAt)) hours.set(hour, station);
  }
  const distanceKm = Math.round(greatCircleDistanceKm(coordinates, nearest) * 10) / 10;
  return [...hours.values()].sort((a, b) => Date.parse(a.observedAt) - Date.parse(b.observedAt))
    .map((station) => ({ observedAt: station.observedAt, depthCm: station.depthCm!,
      stationId: station.stationId, stationName: station.stationName, distanceKm }));
}

export async function readSnowDepthHistory(db: D1Database | undefined, location: NationwideLocation,
  now: Date): Promise<SnowDepthObservation[]> {
  if (!db) return [];
  const coordinates = coordinatesForLocation(location);
  if (!coordinates) return [];
  const latest = await getCollectedCache<SnowSnapshot>(db, 'COLLECTED_NATIONWIDE_SNOW_TOTAL');
  if (latest?.status !== 'AVAILABLE' || !Array.isArray(latest.value?.stations)) return [];
  const valid = latest.value.stations.filter((station) =>
    validStation(station) && Date.parse(station.observedAt) <= now.getTime() &&
    kstHour(station.observedAt).slice(0, 8) === kstHour(now.toISOString()).slice(0, 8));
  const fresh = valid.filter((station) => snowStationIsFresh(station, now));
  const nearest = (fresh.length ? fresh : valid).sort((a, b) =>
    greatCircleDistanceKm(coordinates, a) - greatCircleDistanceKm(coordinates, b))[0];
  if (!nearest) return [];
  const today = kstHour(now.toISOString()).slice(0, 8);
  // 관측소 하나의 24시간 자료만 꺼내 전국 원본을 요청마다 앱 경로로 복사하지 않는다.
  const { results } = await db.prepare("SELECT json_extract(payload, ?) AS station FROM weather_cache WHERE cache_key >= ? AND cache_key < ? AND status='AVAILABLE'")
    .bind(`$."${nearest.stationId}"`, PREFIX + today, PREFIX + today + '~').all<{ station: string | null }>();
  const stations: SnowStation[] = [nearest];
  for (const row of results) {
    try { if (row.station) stations.push(JSON.parse(row.station)); }
    catch { /* 깨진 캐시를 관측값으로 만들지 않는다. */ }
  }
  return selectSnowDepthHistory(stations, location, now);
}
