import { gunzipSync } from 'fflate';
import { KMA_ADMINISTRATIVE_AREAS } from './kmaAdministrativeAreas';
import type { NationwideLocation } from './nationwideLocation';

export type AdministrativeArea = typeof KMA_ADMINISTRATIVE_AREAS[number];
export interface BoundaryResolution {
  version: string;
  area?: AdministrativeArea;
  precision: 'DONG' | 'PARENT' | 'OUTSIDE' | 'UNMAPPED' | 'GRID_PARENT';
}
interface BoundaryRow { version: string; sgisCode: string; kmaCode: string | null; precision: string; geometry: string }
// 해안 다각형도 요청에 필요한 후보만 풀고, 프로세스 캐시는 32MiB로 제한한다.
const geometries = new Map<string, Uint8Array>();
let geometryBytes = 0;
const MAX_GEOMETRY_BYTES = 32 * 1024 * 1024;
const areasByCode = new Map(KMA_ADMINISTRATIVE_AREAS.map((area) => [area[0], area]));

export function decodeBoundaryGeometry(payload: string): Uint8Array {
  if (typeof payload !== 'string' || payload.length > 32 * 1024 * 1024) throw new Error('BOUNDARY_GEOMETRY_TOO_LARGE');
  const compressed = Uint8Array.from(atob(payload), (c) => c.charCodeAt(0));
  if (compressed.length < 18) throw new Error('BOUNDARY_GEOMETRY_INVALID');
  const size = new DataView(compressed.buffer, compressed.byteOffset, compressed.byteLength).getUint32(compressed.length - 4, true);
  // gzip에 저장된 출력 크기를 먼저 검사해 손상된 자료의 과도한 메모리 할당을 차단한다.
  if (size > 128 * 1024 * 1024) throw new Error('BOUNDARY_GEOMETRY_TOO_LARGE');
  const raw = gunzipSync(compressed);
  if (raw.length !== size) throw new Error('BOUNDARY_GEOMETRY_INVALID');
  const view = new DataView(raw.buffer, raw.byteOffset, raw.byteLength);
  if (raw.length < 4) throw new Error('BOUNDARY_GEOMETRY_INVALID');
  const count = view.getUint32(0, true);
  if (count < 1 || count > 100_000) throw new Error('BOUNDARY_GEOMETRY_INVALID');
  let offset = 4;
  for (let ring = 0; ring < count; ring++) {
    if (offset + 4 > raw.length) throw new Error('BOUNDARY_GEOMETRY_INVALID');
    const points = view.getUint32(offset, true); offset += 4;
    if (points < 4 || offset + points * 16 > raw.length) throw new Error('BOUNDARY_GEOMETRY_INVALID');
    let firstX = 0, firstY = 0;
    for (let i = 0; i < points; i++, offset += 16) {
      const x = view.getFloat64(offset, true), y = view.getFloat64(offset + 8, true);
      if (!Number.isFinite(x) || !Number.isFinite(y) || Math.abs(x) > 180 || Math.abs(y) > 90) {
        throw new Error('BOUNDARY_GEOMETRY_INVALID');
      }
      if (i === 0) { firstX = x; firstY = y; }
      if (i === points - 1 && (x !== firstX || y !== firstY)) throw new Error('BOUNDARY_GEOMETRY_NOT_CLOSED');
    }
  }
  if (offset !== raw.length) throw new Error('BOUNDARY_GEOMETRY_INVALID');
  return raw;
}

// 모든 링의 홀짝 포함 판정: 구멍과 서로 떨어진 섬을 모두 보존한다.
export function boundaryContainsPoint(raw: Uint8Array, longitude: number, latitude: number): boolean {
  const view = new DataView(raw.buffer, raw.byteOffset, raw.byteLength);
  const rings = view.getUint32(0, true);
  let offset = 4, inside = false;
  for (let ring = 0; ring < rings; ring++) {
    const count = view.getUint32(offset, true); offset += 4;
    let ax = view.getFloat64(offset, true), ay = view.getFloat64(offset + 8, true);
    for (let i = 1; i < count; i++) {
      const bx = view.getFloat64(offset + i * 16, true), by = view.getFloat64(offset + i * 16 + 8, true);
      const dx = bx - ax, dy = by - ay;
      const length = Math.hypot(dx, dy);
      const onSegment = length > 0 && Math.abs((longitude - ax) * dy - (latitude - ay) * dx) <= length * 1e-10 &&
        longitude >= Math.min(ax, bx) - 1e-10 && longitude <= Math.max(ax, bx) + 1e-10 &&
        latitude >= Math.min(ay, by) - 1e-10 && latitude <= Math.max(ay, by) + 1e-10;
      if (onSegment) return true;
      if ((ay > latitude) !== (by > latitude) && longitude < (bx - ax) * (latitude - ay) / (by - ay) + ax) inside = !inside;
      ax = bx; ay = by;
    }
    offset += count * 16;
  }
  return inside;
}

function commonParent(areas: AdministrativeArea[]): AdministrativeArea | undefined {
  return KMA_ADMINISTRATIVE_AREAS.filter((parent) => parent[0].endsWith('00000') && areas.every((area) =>
    // 코드보다 현재 공식 이름 계층을 사용: 일반구·통합 특별시를 포함한다.
    area[1].replace(/\s/g, '').startsWith(parent[1].replace(/\s/g, ''))))
    .sort((a, b) => b[1].length - a[1].length)[0];
}

export async function administrativeBoundaryVersion(db: D1Database): Promise<string | undefined> {
  return (await db.prepare('SELECT version FROM administrative_boundary_dataset WHERE singleton=1').first<{ version: string }>())?.version;
}

export async function resolveAdministrativeBoundary(db: D1Database | undefined, location: NationwideLocation): Promise<BoundaryResolution | undefined> {
  if (!db) return undefined;
  if (!location.coordinates) {
    const reference = await db.prepare(`SELECT d.version,g.kma_code AS code FROM administrative_boundary_dataset d
      LEFT JOIN administrative_boundary_grid_regions g ON g.nx=? AND g.ny=? WHERE d.singleton=1`)
      .bind(location.nx, location.ny).first<{ version: string; code: string }>();
    return reference ? { version: reference.version, area: areasByCode.get(reference.code), precision: reference.code ? 'GRID_PARENT' : 'UNMAPPED' } : undefined;
  }
  const { latitude, longitude } = location.coordinates;
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
    const version = await administrativeBoundaryVersion(db);
    return version ? { version, precision: 'OUTSIDE' } : undefined;
  }
  // 버전과 후보를 같은 SQL 스냅샷으로 읽어 자료 교체 도중 서로 섞지 않는다.
  const rows = await db.prepare(`SELECT d.version,f.sgis_code AS sgisCode,f.kma_code AS kmaCode,f.precision,f.geometry
    FROM administrative_boundary_dataset d LEFT JOIN administrative_boundary_features f
    ON f.min_lon<=? AND f.max_lon>=? AND f.min_lat<=? AND f.max_lat>=? WHERE d.singleton=1`)
    .bind(longitude + 1e-10, longitude - 1e-10, latitude + 1e-10, latitude - 1e-10).all<BoundaryRow>();
  const containing: BoundaryRow[] = [];
  const version = rows.results[0]?.version;
  if (!version) return undefined;
  for (const row of rows.results) {
    if (!row.sgisCode) continue;
    const key = `${version}:${row.sgisCode}`;
    let raw = geometries.get(key);
    if (!raw) {
      raw = decodeBoundaryGeometry(row.geometry);
      while (geometryBytes + raw.length > MAX_GEOMETRY_BYTES && geometries.size) {
        const oldest = geometries.keys().next().value;
        geometryBytes -= geometries.get(oldest).length; geometries.delete(oldest);
      }
      if (raw.length <= MAX_GEOMETRY_BYTES) { geometries.set(key, raw); geometryBytes += raw.length; }
    } else { geometries.delete(key); geometries.set(key, raw); }
    if (boundaryContainsPoint(raw, longitude, latitude)) containing.push(row);
  }
  if (!containing.length) return { version, precision: 'OUTSIDE' };
  const mapped = containing.map((row) => areasByCode.get(row.kmaCode));
  if (mapped.some((area) => !area)) return { version, precision: 'UNMAPPED' };
  const distinct = [...new Map(mapped.map((area) => [area[0], area])).values()];
  const area = distinct.length === 1 ? distinct[0] : commonParent(distinct);
  return { version, area, precision: !area ? 'UNMAPPED' : distinct.length === 1 && containing.every((r) => r.precision === 'DONG') ? 'DONG' : 'PARENT' };
}
