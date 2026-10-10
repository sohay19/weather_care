import { getCollectedCache, collectedCacheKey, saveCollectedCache, cacheRecordIsFresh } from '../database/collectedWeatherRepository';
import { readNationwideForecast } from '../database/nationwideForecastRepository';
import { enrichForecastWithEnvironmentalData, readCollectedEnvironmentalData, type EnvironmentalDataBundle } from '../providers/environmental/environmentalDataService';
import { coordinatesForLocation, type NationwideLocation } from '../regions/nationwideLocation';
import { resolveSavedLocation } from '../regions/resolvedLocation';
import { KmaUvProvider, latestUvPublicationTimes } from '../providers/uv/kmaUvProvider';
import type { UvForecast } from '../providers/uv/uvProvider';
import { nearestVisibilityObservations, type KmaHourlyObservationSnapshot } from '../providers/weather/kmaHourlyObservationProvider';
import { enrichForecastWithVisibility, usableVisibilityObservation } from '../providers/weather/visibility';
import type { CollectedRegionBundle, CollectedWeeklyBundle } from '../collection/collectionTypes';
import { dailyObservationsAtLocations, type NationwideDailySnapshot } from '../providers/weather/kmaDailyObservationProvider';
import { readCachedMidTermForecast } from './midTermForecastCache';
import { readCollectedAirForecast } from '../providers/air/airKoreaForecastProvider';
import { readPointForecast } from './pointForecastCache';

export const NATIONAL_UV_KEY = 'COLLECTED_NATIONWIDE_UV';
export const NATIONAL_VISIBILITY_KEY = 'COLLECTED_NATIONWIDE_VISIBILITY';
export const NATIONAL_DAILY_KEY = 'COLLECTED_NATIONWIDE_DAILY';
export interface NationwideUvSnapshot { forecasts: Record<string, UvForecast>; issue: string }

export function emptyEnvironmentalData(): EnvironmentalDataBundle {
  return { sources: { uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNAVAILABLE', reason: 'PROVIDER_UNAVAILABLE' },
    airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE', reason: 'PROVIDER_UNAVAILABLE' } } };
}
export async function collectNationwideUv(db: D1Database, key: string, now: Date): Promise<void> {
  const issue = latestUvPublicationTimes(now, 1)[0];
  const cached = await getCollectedCache<NationwideUvSnapshot>(db, NATIONAL_UV_KEY);
  if (cached?.status === 'AVAILABLE' && cached.value.issue === issue) return;
  const forecasts = await new KmaUvProvider({ serviceKey: key, now: () => now }).getNationwide();
  await saveCollectedCache(db, { key: NATIONAL_UV_KEY, type: 'COLLECTED_NATIONWIDE_UV', value: { forecasts, issue }, updatedAt: now });
}
export async function readNationwideVisibility(db: D1Database | undefined, location: NationwideLocation, now: Date) {
  const source = await getCollectedCache<KmaHourlyObservationSnapshot>(db, NATIONAL_VISIBILITY_KEY);
  const coordinates = coordinatesForLocation(location);
  if (source?.status === 'AVAILABLE' && coordinates && cacheRecordIsFresh(source, 3 * 3_600_000, now)) {
    const observation = nearestVisibilityObservations(source.value, [coordinates])[0];
    if (usableVisibilityObservation(observation, now)) return observation;
  }
  const legacy = await getCollectedCache<import('../types').CurrentVisibilityObservation>(db, collectedCacheKey.visibility(location.nx, location.ny));
  return legacy?.status === 'AVAILABLE' && usableVisibilityObservation(legacy.value, now) ? legacy.value : undefined;
}
export async function readNationwideRegion(db: D1Database | undefined, location: NationwideLocation, now: Date) {
  location = await resolveSavedLocation(db, location, now);
  const [forecast, legacy, point] = await Promise.all([
    readNationwideForecast(db, location.nx, location.ny, now),
    getCollectedCache<CollectedRegionBundle>(db, `COLLECTED_REGION_${location.nx}_${location.ny}`),
    readPointForecast(db, location.nx, location.ny, now),
  ]);
  // 이전 배포 캐시는 마이그레이션 중에만 사용한다. 새 수집기는 지역별 사본을 만들지 않는다.
  let raw = point ?? forecast ?? (legacy?.status === 'AVAILABLE' ? legacy.value.forecast : undefined);
  if (!raw && db) {
    let source = await db.prepare('SELECT issue_time AS issue,updated_at AS updatedAt FROM nationwide_forecast_fields ORDER BY issue_time DESC LIMIT 1')
      .first<{ issue: string; updatedAt: string }>();
    if (!source) {
      const observation = await db.prepare('SELECT observed_at AS observedAt,updated_at AS updatedAt FROM grid_observation_snapshots WHERE observed_at BETWEEN ? AND ? ORDER BY observed_at DESC LIMIT 1')
        .bind(new Date(now.getTime() - 30 * 60_000).toISOString(), now.toISOString())
        .first<{ observedAt: string; updatedAt: string }>();
      if (observation) source = { issue: new Date(Date.parse(observation.observedAt) + 9 * 3_600_000).toISOString().replace(/[-:T]/g, '').slice(0, 10), updatedAt: observation.updatedAt };
    }
    if (source) raw = { current: { observedAt: now.toISOString(), fetchedAt: source.updatedAt,
      qualityFlags: ['FORECAST_SOURCE_CELL_MISSING'] }, hourly: [], timelineHourly: [], daily: [],
      baseDate: source.issue.slice(0, 8), baseTime: source.issue.slice(8) + '00', dataSource: '기상청 전국 격자 단기예보' };
  }
  if (!raw) return null;
  const environmental = await readCollectedEnvironmentalData(db, location.nx, location.ny,
    legacy?.value.environmental ?? emptyEnvironmentalData(), now, coordinatesForLocation(location), location);
  const visibility = await readNationwideVisibility(db, location, now);
  return { value: { forecast: enrichForecastWithVisibility(enrichForecastWithEnvironmentalData(raw, environmental), visibility, now), environmental },
    native: !!point || !!forecast || !legacy, status: 'AVAILABLE' as const,
    updatedAt: raw.current.fetchedAt ?? legacy?.updatedAt ?? now.toISOString() };
}
export async function readNationwideWeekly(db: D1Database | undefined, location: NationwideLocation, now: Date) {
  location = await resolveSavedLocation(db, location, now);
  const [region, legacy, daily, mid] = await Promise.all([
    readNationwideRegion(db, location, now), getCollectedCache<CollectedWeeklyBundle>(db, collectedCacheKey.weekly(location.nx, location.ny)),
    getCollectedCache<NationwideDailySnapshot>(db, NATIONAL_DAILY_KEY), readCachedMidTermForecast({ db, location, now }),
  ]);
  if (!region && !legacy && mid.days.length === 0) return null;
  const coordinates = coordinatesForLocation(location);
  const end = new Date(now.getTime() + 9 * 3_600_000 - 86_400_000).toISOString().slice(0, 10);
  const start = new Date(now.getTime() + 9 * 3_600_000 - 7 * 86_400_000).toISOString().slice(0, 10);
  const observedDays = daily?.status === 'AVAILABLE' && coordinates
    ? dailyObservationsAtLocations(daily.value, [coordinates], start, end)[0] : legacy?.value.observedDays ?? [];
  const airQuality = await readCollectedAirForecast(db, location.nx, location.ny, legacy?.value.airQuality ?? [], now, location.adminCode, location.regionName);
  const value: CollectedWeeklyBundle = { forecast: region?.native ? region.value.forecast : legacy ? legacy.value.forecast : region?.value.forecast,
    midTermDays: mid.days.length ? mid.days : legacy?.value.midTermDays ?? [], observedDays,
    uv: region?.value.environmental.uv, airQuality, collectedAt: now.toISOString(),
    midTermTaRegId: mid.region.temperatureRegionId, midTermLandRegId: mid.region.landRegionId };
  return { value, status: 'AVAILABLE' as const, updatedAt: region?.updatedAt ?? legacy?.updatedAt ?? now.toISOString() };
}
