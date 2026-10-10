import { observationsFromGridSnapshot, type GridObservationSnapshot } from '../providers/weather/kmaGridObservationProvider';
import type { UltraShortObservation } from '../providers/weather/kmaUltraShortObservationProvider';
import { kmaGridCoordinates } from '../regions/kmaGridCoordinates';
import { KMA_NATIVE_FORECAST_GRIDS } from '../regions/nationwideForecastGridCatalog';

interface Coordinates { latitude: number; longitude: number }
interface Candidate extends Coordinates { value: UltraShortObservation }
// 원본 객체별로 한 번만 색인한다. 원본 캐시에서 제거되면 함께 회수된다.
const candidates = new WeakMap<GridObservationSnapshot, { complete: Candidate[]; core: Candidate[] }>();
export const DISTANT_OBSERVATION_KM = 20;

export function nearestGridObservation(
  snapshot: GridObservationSnapshot, nx: number, ny: number, gps?: Coordinates,
): UltraShortObservation | undefined {
  const origin = gps ?? kmaGridCoordinates(nx, ny);
  if (!origin || !Number.isFinite(origin.latitude) || !Number.isFinite(origin.longitude)) return undefined;
  let indexed = candidates.get(snapshot);
  if (!indexed) {
    const core = [...observationsFromGridSnapshot(snapshot, KMA_NATIVE_FORECAST_GRIDS).values()]
      .map((value) => ({ value, ...kmaGridCoordinates(value.sourceLocation!.nx!, value.sourceLocation!.ny!)! }));
    indexed = { core, complete: core.filter(({ value }) => value.windDirection !== undefined && value.precipitationTypeCode !== undefined && value.precipitationAmount !== undefined) };
    candidates.set(snapshot, indexed);
  }
  let nearest: Candidate | undefined;
  let distanceKm = Infinity;
  // 회차 전체에서 선택 항목 파일이 빠졌어도 정상인 핵심 실황을 모두 버리지 않는다.
  for (const candidate of indexed.complete.length ? indexed.complete : indexed.core) {
    const distance = greatCircleDistanceKm(origin, candidate);
    if (distance < distanceKm) { nearest = candidate; distanceKm = distance; }
  }
  if (!nearest) return undefined;
  return { ...nearest.value,
    sourceLocation: { ...nearest.value.sourceLocation!, locationMatch: 'NEAREST_GRID', distanceKm,
      distanceBasis: gps ? 'GPS' : 'GRID_CENTER' },
    qualityFlags: [...(nearest.value.qualityFlags ?? []), 'NEARBY_GRID_OBSERVATION',
      ...(nearest.value.windDirection === undefined ? ['WIND_DIRECTION_UNAVAILABLE'] : []),
      ...(nearest.value.precipitationAmount === undefined ? ['PRECIPITATION_AMOUNT_UNAVAILABLE'] : []),
      ...(distanceKm > DISTANT_OBSERVATION_KM ? ['DISTANT_GRID_OBSERVATION'] : [])],
  };
}

export function greatCircleDistanceKm(a: Coordinates, b: Coordinates): number {
  const radians = Math.PI / 180;
  const lat = (b.latitude - a.latitude) * radians;
  const lon = (b.longitude - a.longitude) * radians;
  const h = Math.sin(lat / 2) ** 2 + Math.cos(a.latitude * radians) * Math.cos(b.latitude * radians) * Math.sin(lon / 2) ** 2;
  return 6371.00877 * 2 * Math.asin(Math.sqrt(Math.min(1, h)));
}
