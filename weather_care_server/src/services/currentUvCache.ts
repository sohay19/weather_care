import { formatWeatherNumber } from '../utils/weatherNumber';
import { getCollectedCache, saveCollectedCache } from '../database/collectedWeatherRepository';
import { KmaUvObservationProvider, UV_OBSERVATION_MAX_BYTES,
  type UvObservation, type UvObservationStation } from '../providers/uv/kmaUvObservationProvider';
import { coordinatesForLocation, type NationwideLocation } from '../regions/nationwideLocation';
import { providerErrorDiagnostic } from '../observability/providerErrorDiagnostics';
import type { WeatherSnapshot } from '../types';
import { apiHubBudgetedFetch } from './apiHubFetch';
import { greatCircleDistanceKm } from './nearbyGridObservation';

export const UV_STATIONS_KEY = 'COLLECTED_UV_OBSERVATION_STATIONS';
export const UV_OBSERVATIONS_KEY = 'COLLECTED_UV_OBSERVATIONS';
const MAX_AGE_MS = 30 * 60_000;

export async function collectCurrentUv(db: D1Database, key: string, now: Date): Promise<void> {
  if (!key.trim()) return;
  const day = new Date(now.getTime() + 9 * 3_600_000).toISOString().slice(0, 10);
  const tasks = [
    { name: 'UV_STATIONS', slot: day, cacheKey: UV_STATIONS_KEY },
    { name: 'UV_OBSERVATION', slot: new Date(Math.floor(now.getTime() / 600_000) * 600_000).toISOString(),
      cacheKey: UV_OBSERVATIONS_KEY },
  ];
  for (const task of tasks) {
    const attemptKey = `CURRENT_${task.name}_ATTEMPT`;
    const previous = await getCollectedCache<{ slot: string; blocked?: boolean }>(db, attemptKey);
    if (previous?.value.blocked) continue;
    const acquired = await db.prepare(`INSERT INTO weather_cache
      (cache_key,region_id,nx,ny,cache_type,payload,status,updated_at)
      VALUES(?,?,0,0,'CURRENT_UV_ATTEMPT',?,'AVAILABLE',?) ON CONFLICT(cache_key) DO UPDATE SET
      payload=excluded.payload,updated_at=excluded.updated_at WHERE json_extract(weather_cache.payload,'$.slot')<>?`)
      .bind(attemptKey, attemptKey, JSON.stringify({ slot: task.slot }), now.toISOString(), task.slot).run();
    if (!acquired.meta.changes) continue;
    try {
      const provider = new KmaUvObservationProvider(key, apiHubBudgetedFetch({ db, provider: task.name,
        now, clock: () => new Date(), sourceVersion: task.slot, maxBytes: UV_OBSERVATION_MAX_BYTES }));
      let value: UvObservationStation[] | UvObservation[];
      if (task.name === 'UV_STATIONS') value = await provider.getStations();
      else {
        const incoming = await provider.getObservations(now);
        const cached = await getCollectedCache<UvObservation[]>(db, UV_OBSERVATIONS_KEY);
        // 지점별 게시 시차가 있어 새 회차 응답에 아직 없는 지점은 직전 실측을 보존한다.
        const byStation = new Map((cached?.value ?? []).filter(item => {
          const age = now.getTime() - Date.parse(item.observedAt);
          return Number.isFinite(age) && age >= 0 && age <= MAX_AGE_MS;
        }).map(item => [item.stationId, item]));
        for (const item of incoming) {
          const old = byStation.get(item.stationId);
          if (!old || (item.uvIndex !== undefined && Date.parse(item.observedAt) >= Date.parse(old.observedAt))) {
            byStation.set(item.stationId, item);
          }
        }
        value = [...byStation.values()];
      }
      await saveCollectedCache(db, { key: task.cacheKey, type: task.cacheKey, value, updatedAt: now });
      console.log(JSON.stringify({ event: 'current_uv_collected', source: task.name, count: value.length }));
    } catch (error) {
      const diagnostic = providerErrorDiagnostic(error);
      if (['NOT_CONFIGURED', 'AUTHORIZATION_FAILED'].includes(diagnostic.failureReason)) {
        await saveCollectedCache(db, { key: attemptKey, type: 'CURRENT_UV_ATTEMPT',
          value: { slot: task.slot, blocked: true }, updatedAt: now });
      }
      console.error(JSON.stringify({ event: 'current_uv_collection_failed', source: task.name, ...diagnostic }));
    }
  }
}

export async function currentUvFields(db: D1Database | undefined, location: NationwideLocation,
  now: Date): Promise<Partial<WeatherSnapshot>> {
  const unavailable = { uvIndex: undefined, uvStatus: 'UNAVAILABLE' as const,
    uvProvider: 'KMA_APIHUB_UV' as const };
  const coordinates = coordinatesForLocation(location);
  if (!coordinates) return unavailable;
  const [catalog, observed] = await Promise.all([
    getCollectedCache<UvObservationStation[]>(db, UV_STATIONS_KEY),
    getCollectedCache<UvObservation[]>(db, UV_OBSERVATIONS_KEY),
  ]);
  // 지점정보 갱신 실패 때 기존 목록은 최대 7일 재사용한다.
  if (catalog?.status !== 'AVAILABLE' || observed?.status !== 'AVAILABLE' ||
      now.getTime() - Date.parse(catalog.updatedAt) > 7 * 86_400_000) return unavailable;
  const observations = new Map(observed.value.filter(item => {
    const age = now.getTime() - Date.parse(item.observedAt);
    return Number.isFinite(age) && age >= 0 && age <= MAX_AGE_MS &&
      item.uvIndex !== undefined && Number.isFinite(item.uvIndex) && item.uvIndex >= 0 && item.uvIndex <= 30;
  }).map(item => [item.stationId, item]));
  const nearest = catalog.value.filter(station => observations.has(station.stationId))
    .map(station => ({ station, distance: greatCircleDistanceKm(coordinates, station) }))
    .sort((a, b) => a.distance - b.distance)[0];
  if (!nearest) return unavailable;
  const observation = observations.get(nearest.station.stationId)!;
  return { uvStatus: 'AVAILABLE', uvProvider: 'KMA_APIHUB_UV', uvIndex: observation.uvIndex,
    uvObservedAt: observation.observedAt, uvStationId: nearest.station.stationId,
    uvStationName: nearest.station.stationName, uvStationDistanceKm: Number(formatWeatherNumber(nearest.distance)) };
}
