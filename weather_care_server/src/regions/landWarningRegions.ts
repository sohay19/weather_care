import boundaries from './kmaWarningBoundaries.json';
import gridCoverage from './kmaWarningGridCoverage.json';
import { decodeBoundaryGeometry } from './administrativeBoundaries';
import { kmaGridBounds, type GeographicBounds } from './kmaGridCoordinates';
import { kmaGridFromCoordinates } from './kmaGridFromCoordinates';
import type { RegionTarget } from '../notification/notificationRegions';

const decoded = new Map<string, Uint8Array>();
const administrativeRegions: Record<string, string[]> = boundaries.administrativeRegions;
const regionsByGrid: Record<string, string[]> = gridCoverage.sourceSha256 === boundaries.sourceSha256 &&
  gridCoverage.minimumCoverage === 0.65 ? gridCoverage.regionsByGrid : {};
export const landWarningRegionIds = boundaries.zones.map(zone => zone.id);

// 외곽선·구멍의 경계는 인접한 어느 한 구역으로 추정하지 않는다.
function strictlyInside(raw: Uint8Array, longitude: number, latitude: number, bounds?: GeographicBounds): boolean {
  const view = new DataView(raw.buffer, raw.byteOffset, raw.byteLength);
  let offset = 4, inside = false;
  for (let ring = 0; ring < view.getUint32(0, true); ring++) {
    const count = view.getUint32(offset, true); offset += 4;
    let ax = view.getFloat64(offset, true), ay = view.getFloat64(offset + 8, true);
    for (let i = 1; i < count; i++) {
      const bx = view.getFloat64(offset + i * 16, true), by = view.getFloat64(offset + i * 16 + 8, true);
      const dx = bx - ax, dy = by - ay, length = Math.hypot(dx, dy);
      if (bounds && boundaryTouchesBounds(ax, ay, bx, by, bounds)) return false;
      if (length && Math.abs((longitude - ax) * dy - (latitude - ay) * dx) <= length * 1e-10 &&
          longitude >= Math.min(ax, bx) - 1e-10 && longitude <= Math.max(ax, bx) + 1e-10 &&
          latitude >= Math.min(ay, by) - 1e-10 && latitude <= Math.max(ay, by) + 1e-10) return false;
      if ((ay > latitude) !== (by > latitude) && longitude < dx * (latitude - ay) / dy + ax) inside = !inside;
      ax = bx; ay = by;
    }
    offset += count * 16;
  }
  return inside;
}

function boundaryTouchesBounds(ax: number, ay: number, bx: number, by: number, bounds: GeographicBounds): boolean {
  const [west, south, east, north] = bounds;
  if (Math.max(ax, bx) < west || Math.min(ax, bx) > east || Math.max(ay, by) < south || Math.min(ay, by) > north) return false;

  // 경계 선분과 사각형의 x·y 범위가 겹친다. 선분의 법선으로도 분리되는지 확인한다.
  const dx = bx - ax, dy = by - ay;
  const cross = ((west + east) / 2 - ax) * dy - ((south + north) / 2 - ay) * dx;
  const extent = (east - west) / 2 * Math.abs(dy) + (north - south) / 2 * Math.abs(dx);
  return Math.abs(cross) <= extent + 1e-10 * (Math.abs(dx) + Math.abs(dy));
}

export function landWarningRegionsAtPoint(latitude: number, longitude: number): string[] {
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || latitude < 30 || latitude > 44 || longitude < 120 || longitude > 135) return [];
  return matchingZones(latitude, longitude);
}

export function landWarningRegionsForGrid(nx: number, ny: number): string[] {
  return regionsByGrid[`${nx}:${ny}`] ?? [];
}

function landWarningRegionsContainingGrid(nx: number, ny: number): string[] {
  const bounds = kmaGridBounds(nx, ny);
  if (!bounds) return [];
  const [west, south, east, north] = bounds;
  // 중심이 내부이고 어떤 외곽선이나 구멍도 사각형에 닿지 않으면 격자 전체가 내부다.
  return matchingZones((south + north) / 2, (west + east) / 2, bounds);
}

function matchingZones(latitude: number, longitude: number, bounds?: GeographicBounds): string[] {
  return boundaries.zones.filter(zone => {
    const [minX, minY, maxX, maxY] = zone.bounds;
    if (bounds) {
      if (bounds[0] <= minX || bounds[1] <= minY || bounds[2] >= maxX || bounds[3] >= maxY) return false;
    } else if (longitude < minX || longitude > maxX || latitude < minY || latitude > maxY) return false;
    let raw = decoded.get(zone.id);
    if (!raw) { raw = decodeBoundaryGeometry(zone.geometry); decoded.set(zone.id, raw); }
    return strictlyInside(raw, longitude, latitude, bounds);
  }).sort((a,b) => (a.bounds[2]-a.bounds[0])*(a.bounds[3]-a.bounds[1]) -
    (b.bounds[2]-b.bounds[0])*(b.bounds[3]-b.bounds[1])).map(zone => zone.id);
}

export function landWarningRegionsForTarget(target: RegionTarget): string[] {
  const gps = target.scopeId ? target.regionKey === 'GPS' : target.locationMode === 'GPS';
  const position = target.subscriptionCoordinates ?? target;
  const hasCoordinates = position.latitude != null || position.longitude != null;
  if (gps && hasCoordinates) {
    if (position.latitude == null || position.longitude == null) return [];
    const grid = kmaGridFromCoordinates(position.latitude, position.longitude);
    if (grid.nx !== target.nx || grid.ny !== target.ny) return [];
    return landWarningRegionsAtPoint(position.latitude, position.longitude);
  }
  // 직접 선택한 동은 공식 행정구역 설명에서 검증된 코드만 사용한다.
  const selectedCode = target.regionKey?.split('|')[0];
  if (selectedCode && /^\d{10}$/.test(selectedCode)) return administrativeRegions[selectedCode] ?? [];
  if (target.adminCode && /^\d{10}$/.test(target.adminCode) && !target.adminCode.endsWith('00000')) {
    return administrativeRegions[target.adminCode] ?? [];
  }
  if (gps || target.regionKey === 'LEGACY' || (!target.scopeId && target.locationMode === 'MANUAL')) {
    // 좌표가 남아 있는 이전 수동 등록에는 기존 격자 전체 포함 판정을 유지한다.
    if (hasCoordinates) return landWarningRegionsContainingGrid(target.nx, target.ny);
    return landWarningRegionsForGrid(target.nx, target.ny);
  }
  return [];
}

export function landWarningRegionName(id: string): string | undefined {
  return boundaries.zones.find(zone => zone.id === id)?.name;
}
