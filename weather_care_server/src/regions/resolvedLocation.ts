import { getCollectedCache, saveCollectedCache, cacheRecordIsFresh } from '../database/collectedWeatherRepository';
import { administrativeAreaForLocation, type NationwideLocation } from './nationwideLocation';
import { administrativeBoundaryVersion, resolveAdministrativeBoundary } from './administrativeBoundaries';

interface LocationIdentity {
  adminCode: string; regionName: string;
  source?: 'EXPLICIT' | 'BOUNDARY'; boundaryVersion?: string;
}

// 확정 지역을 위치별로 저장하고 경계 자료의 버전이 바뀌면 다시 판정한다.
export async function resolveSavedLocation(db: D1Database | undefined, location: NationwideLocation, now: Date): Promise<NationwideLocation> {
  if (!db || location.boundaryChecked) return location;
  const coordinateKey = location.coordinates
    ? `GPS:${location.coordinates.latitude}:${location.coordinates.longitude}` : `GRID:${location.nx}:${location.ny}`;
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(coordinateKey));
  const key = 'COLLECTED_LOCATION_IDENTITY_' + Array.from(new Uint8Array(bytes), (b) => b.toString(16).padStart(2, '0')).join('');
  const saved = await getCollectedCache<LocationIdentity>(db, key);
  const explicit = location.adminCode || location.regionName
    ? administrativeAreaForLocation({ ...location, boundaryChecked: true }) : undefined;
  let boundary: Awaited<ReturnType<typeof resolveAdministrativeBoundary>>;
  let version: string | undefined;
  try {
    version = await administrativeBoundaryVersion(db);
    const recent = saved?.status === 'AVAILABLE' && cacheRecordIsFresh(saved, 86_400_000, now) &&
      saved.value.source === 'BOUNDARY' && version && saved.value.boundaryVersion === version
      ? administrativeAreaForLocation({ ...location, ...saved.value, boundaryChecked: true }) : undefined;
    if (recent && !explicit) return { ...location, adminCode: recent[0], regionName: recent[1], boundaryChecked: true };
    if (!explicit || explicit[0].endsWith('00000')) boundary = await resolveAdministrativeBoundary(db, location);
  }
  catch (error) {
    const reason = error instanceof Error && /^BOUNDARY_[A-Z_]+$/.test(error.message) ? error.message : 'BOUNDARY_LOOKUP_FAILED';
    console.warn(JSON.stringify({ event: 'weather_boundary_lookup_failed', reason }));
    // 경계 장애로 날씨 원본까지 막지 않고, 근거 없는 대표 동 배정도 하지 않는다.
    return explicit ? { ...location, adminCode: explicit[0], regionName: explicit[1], boundaryChecked: true }
      : { ...location, adminCode: undefined, regionName: undefined, boundaryChecked: true };
  }
  const savedArea = saved?.status === 'AVAILABLE' && cacheRecordIsFresh(saved, 365 * 86_400_000, now) &&
    (saved.value.source !== 'BOUNDARY' ? Boolean(location.coordinates) : saved.value.boundaryVersion === (boundary?.version ?? version))
    ? administrativeAreaForLocation({ ...location, ...saved.value, boundaryChecked: true }) : undefined;
  // 확정 이름/코드는 유지하되 상위 이름만 있을 때 실제 GPS로 더 정확히 보완한다.
  const area = explicit && !explicit[0].endsWith('00000') ? explicit
    : boundary?.area ?? explicit ?? (saved?.value.source !== 'BOUNDARY' ? savedArea : boundary ? undefined : savedArea);
  if (!area) return { ...location, boundaryChecked: Boolean(version || boundary) };
  const source = area === explicit || (area === savedArea && saved?.value.source !== 'BOUNDARY') ? 'EXPLICIT' : 'BOUNDARY';
  const boundaryVersion = source === 'BOUNDARY' ? boundary?.version : undefined;
  // 좌표 없는 사용자의 지역명은 다른 사용자의 같은 격자에 공유하지 않는다.
  if ((location.coordinates || source === 'BOUNDARY') &&
      (saved?.value.adminCode !== area[0] || saved.value.source !== source || saved.value.boundaryVersion !== boundaryVersion ||
      !cacheRecordIsFresh(saved, 86_400_000, now))) {
    await saveCollectedCache(db, { key, type: 'COLLECTED_LOCATION_IDENTITY',
      value: { adminCode: area[0], regionName: area[1], source, boundaryVersion }, updatedAt: now });
  }
  return { ...location, adminCode: area[0], regionName: area[1], boundaryChecked: Boolean(version || boundary) };
}
