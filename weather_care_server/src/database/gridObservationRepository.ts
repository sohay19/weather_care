import { collectedCacheKey, getCollectedCache, type CollectedCacheRecord } from './collectedWeatherRepository';
import {
  gridObservationKoreanIso, latestGridObservationTime, observationsFromGridSnapshot,
  GRID_OBSERVATION_VARIABLES, type GridObservationSnapshot,
} from '../providers/weather/kmaGridObservationProvider';
import type { UltraShortObservation } from '../providers/weather/kmaUltraShortObservationProvider';
import { nearestGridObservation } from '../services/nearbyGridObservation';

const MAX_AGE_MS = 30 * 60 * 1000;
export const GRID_HISTORY_RETENTION_MS = 72 * 60 * 60 * 1000;
const snapshots = new WeakMap<D1Database, Map<string, CollectedCacheRecord<GridObservationSnapshot>>>();

export async function saveGridObservationSnapshot(
  db: D1Database, snapshot: GridObservationSnapshot, now: Date,
): Promise<void> {
  if (!isValidGridObservationSnapshot(snapshot)) throw new Error('INVALID_GRID_OBSERVATION_SNAPSHOT');
  const at = new Date(snapshot.observedAt).toISOString();
  if (Date.parse(at) < now.getTime() - GRID_HISTORY_RETENTION_MS) {
    throw new Error('GRID_OBSERVATION_OUTSIDE_RETENTION');
  }
  await db.batch([
    db.prepare(`INSERT INTO grid_observation_snapshots (observed_at, payload, updated_at)
      VALUES (?, ?, ?) ON CONFLICT(observed_at) DO UPDATE SET
      payload=excluded.payload, updated_at=excluded.updated_at`)
      .bind(at, JSON.stringify(snapshot), now.toISOString()),
    db.prepare('DELETE FROM grid_observation_snapshots WHERE observed_at < ?')
      .bind(new Date(now.getTime() - GRID_HISTORY_RETENTION_MS).toISOString()),
  ]);
  snapshots.get(db)?.delete(at);
}

export async function getGridObservationSnapshot(
  db: D1Database, observedAt: string,
): Promise<CollectedCacheRecord<GridObservationSnapshot> | null> {
  const instant = Date.parse(observedAt);
  if (!Number.isFinite(instant)) return null;
  const key = new Date(instant).toISOString();
  let cached = snapshots.get(db);
  if (!cached) { cached = new Map(); snapshots.set(db, cached); }
  const version = await db.prepare('SELECT updated_at AS updatedAt FROM grid_observation_snapshots WHERE observed_at = ?')
    .bind(key).first<{ updatedAt: string }>();
  if (!version) { cached.delete(key); return null; }
  if (cached.get(key)?.updatedAt === version.updatedAt) return cached.get(key)!;
  const row = await db.prepare(`SELECT payload, updated_at AS updatedAt
    FROM grid_observation_snapshots WHERE observed_at = ?`)
    .bind(new Date(instant).toISOString()).first<{ payload: string; updatedAt: string }>();
  if (!row) return null;
  try {
    const value: GridObservationSnapshot = JSON.parse(row.payload);
    if (!isValidGridObservationSnapshot(value) || Date.parse(value.observedAt) !== instant) return null;
    const record = { value, status: 'AVAILABLE' as const, updatedAt: row.updatedAt };
    cached.set(key, record);
    if (cached.size > 8) cached.delete(cached.keys().next().value!);
    return record;
  } catch { return null; }
}

// 메인과 비교가 같은 선택 규칙을 쓴다. 신규 회차·AWS 캐시는 채택하지 않는다.
export function currentGridObservationIsUsable(
  record: CollectedCacheRecord<UltraShortObservation> | null, now: Date,
): boolean {
  if (record?.status !== 'AVAILABLE' || record.value?.provider !== 'KMA_APIHUB_GRID_OBSERVATION') return false;
  const at = Date.parse(record.value.observedAt);
  const target = Date.parse(gridObservationKoreanIso(latestGridObservationTime(now)));
  const temperature = record.value.temperature;
  return Number.isFinite(at) && at % (10 * 60 * 1000) === 0 &&
    record.value.sourceLocation?.type !== 'STATION' && at <= target && at >= now.getTime() - MAX_AGE_MS &&
    temperature !== undefined && Number.isFinite(temperature) && temperature >= -80 && temperature <= 60;
}

export async function readCurrentGridObservation(
  db: D1Database, nx: number, ny: number, now: Date,
  coordinates?: { latitude: number; longitude: number },
): Promise<CollectedCacheRecord<UltraShortObservation> | null> {
  const target = Date.parse(gridObservationKoreanIso(latestGridObservationTime(now)));
  let selected: CollectedCacheRecord<UltraShortObservation> | null = null;
  const available: CollectedCacheRecord<GridObservationSnapshot>[] = [];
  // 30분 유효범위 안에서 정확히 이전 10분 슬롯부터 읽는다.
  for (let at = target; at >= now.getTime() - MAX_AGE_MS; at -= 10 * 60 * 1000) {
    const snapshot = await getGridObservationSnapshot(db, new Date(at).toISOString());
    if (snapshot) available.push(snapshot);
    const value = snapshot && observationsFromGridSnapshot(snapshot.value, [{ nx, ny }]).get(`${nx}:${ny}`);
    if (value) { selected = { value, status: 'AVAILABLE', updatedAt: snapshot!.updatedAt }; break; }
  }
  // 배포 직후 기존 정상 격자 캐시는 원본 이력이 생기기 전까지 재사용한다.
  const legacy = await getCollectedCache<UltraShortObservation>(db, collectedCacheKey.ultraShortObservation(nx, ny));
  const location = legacy?.value?.sourceLocation;
  const exactLocation = !location || (location.type === 'GRID' && location.nx === nx && location.ny === ny);
  if (exactLocation && currentGridObservationIsUsable(legacy, now) &&
      (!selected || Date.parse(legacy!.value.observedAt) > Date.parse(selected.value.observedAt))) return legacy;
  if (selected) return selected;
  for (const snapshot of available) {
    const value = nearestGridObservation(snapshot.value, nx, ny, coordinates);
    if (value) return { value, status: 'AVAILABLE', updatedAt: snapshot.updatedAt };
  }
  return null;
}

export function isValidGridObservationSnapshot(value: GridObservationSnapshot): boolean {
  return !!value && Number.isFinite(Date.parse(value.observedAt)) && !!value.fields &&
    ['T1H', 'REH', 'WSD'].every((field) => field in value.fields) &&
    Object.entries(value.fields).every(([field, grid]) =>
      GRID_OBSERVATION_VARIABLES.includes(field as typeof GRID_OBSERVATION_VARIABLES[number]) &&
      grid?.width === 149 && grid.height === 253 && Array.isArray(grid.values) &&
      grid.values.length === 149 * 253 && grid.values.every(Number.isFinite));
}
