import { getCollectedCache, saveCollectedCache } from '../database/collectedWeatherRepository';
import { KmaSnowObservationProvider, snowRequestTime, snowStationIsFresh,
  SNOW_RESPONSE_MAX_BYTES, type SnowSnapshot } from '../providers/weather/kmaSnowObservationProvider';
import { coordinatesForLocation, type NationwideLocation } from '../regions/nationwideLocation';
import { greatCircleDistanceKm } from './nearbyGridObservation';
import { apiHubBudgetedFetch } from './apiHubFetch';
import { providerErrorDiagnostic } from '../observability/providerErrorDiagnostics';
import type { WeatherSnapshot } from '../types';

export const CURRENT_SNOW_CACHE_KEY = 'COLLECTED_NATIONWIDE_SNOW_TOTAL';
const ATTEMPT_KEY = 'CURRENT_SNOW_COLLECTION_ATTEMPT';
interface Attempt { owner: string; failures: number; nextRetryAt?: string; authorizationBlocked?: boolean }

export async function collectCurrentSnow(db: D1Database, key: string, now: Date): Promise<void> {
  const previous = await getCollectedCache<Attempt>(db, ATTEMPT_KEY);
  if (previous?.value.authorizationBlocked || Date.parse(previous?.value.nextRetryAt ?? '') > now.getTime()) return;
  const owner = crypto.randomUUID();
  const acquired = await db.prepare(`INSERT INTO weather_cache(cache_key,region_id,nx,ny,cache_type,payload,status,updated_at)
    VALUES(?,?,0,0,'CURRENT_SNOW_ATTEMPT',?,'AVAILABLE',?) ON CONFLICT(cache_key) DO UPDATE SET
    payload=excluded.payload,updated_at=excluded.updated_at WHERE weather_cache.updated_at<=?`)
    .bind(ATTEMPT_KEY,ATTEMPT_KEY,JSON.stringify({owner,failures:previous?.value.failures ?? 0}),now.toISOString(),
      new Date(now.getTime()-10*60_000).toISOString()).run();
  if (!acquired.meta.changes) return;
  try {
    const snapshot = await new KmaSnowObservationProvider(key,apiHubBudgetedFetch({db, provider:'SNOW_TOTAL',now,
      clock:()=>new Date(), maxBytes:SNOW_RESPONSE_MAX_BYTES, sourceVersion:snowRequestTime(now)})).getSnapshot(now);
    if (!snapshot.stations.some((s) => snowStationIsFresh(s,now))) throw new Error('KMA snow has no usable fresh data');
    await saveCollectedCache(db,{key:CURRENT_SNOW_CACHE_KEY,type:'COLLECTED_NATIONWIDE_SNOW_TOTAL',value:snapshot,updatedAt:now});
    await db.prepare('UPDATE weather_cache SET payload=? WHERE cache_key=? AND json_extract(payload,\'$.owner\')=?')
      .bind(JSON.stringify({owner,failures:0}),ATTEMPT_KEY,owner).run();
    console.log(JSON.stringify({event:'current_snow_collected',requestedAt:snapshot.requestedAt,
      stations:snapshot.stations.length,invalidCoordinateRows:snapshot.invalidCoordinateRows ?? 0,
      validStations:snapshot.stations.filter((s)=>snowStationIsFresh(s,now)).length}));
  } catch (error) {
    const diagnostic = providerErrorDiagnostic(error);
    const failures = (previous?.value.failures ?? 0)+1;
    const delay = Math.min(3_600_000,120_000 * 2 ** Math.min(failures-1,5));
    const nextRetryAt = new Date(Math.max(now.getTime()+delay,(error as {nextRetryAt?:number})?.nextRetryAt ?? 0)).toISOString();
    const authorizationBlocked = ['NOT_CONFIGURED','AUTHORIZATION_FAILED'].includes(diagnostic.failureReason);
    await db.prepare('UPDATE weather_cache SET payload=?,updated_at=? WHERE cache_key=? AND json_extract(payload,\'$.owner\')=?')
      .bind(JSON.stringify({owner,failures,nextRetryAt,authorizationBlocked}),
        new Date(now.getTime()-10*60_000).toISOString(),ATTEMPT_KEY,owner).run();
    console.error(JSON.stringify({event:'current_snow_collection_failed',...diagnostic,failures,nextRetryAt,authorizationBlocked}));
  }
}

export async function currentSnowFields(db: D1Database | undefined, location: NationwideLocation, now: Date): Promise<Partial<WeatherSnapshot>> {
  const record = await getCollectedCache<SnowSnapshot>(db,CURRENT_SNOW_CACHE_KEY);
  const coordinates = coordinatesForLocation(location);
  const unavailable = {snowDepthStatus:'UNAVAILABLE' as const,snowDepthProvider:'KMA_APIHUB_SNOW_TOTAL' as const};
  if (!coordinates || record?.status !== 'AVAILABLE' || !Array.isArray(record.value?.stations)) return unavailable;
  let nearest: SnowSnapshot['stations'][number] | undefined, distance = Infinity;
  for (const station of record.value.stations) {
    if (!snowStationIsFresh(station,now)) continue;
    const km = greatCircleDistanceKm(coordinates,station);
    if (km < distance) { nearest=station; distance=km; }
  }
  if (!nearest) return unavailable;
  return {snowDepthStatus:'AVAILABLE',snowDepthProvider:'KMA_APIHUB_SNOW_TOTAL',snowDepthCm:nearest.depthCm,
    snowDepthObservedAt:nearest.observedAt,snowDepthStationId:nearest.stationId,
    snowDepthStationName:nearest.stationName,snowDepthStationDistanceKm:Number(distance.toFixed(1))};
}
