import { createHash } from 'node:crypto';
import { createReadStream } from 'node:fs';
import { createGunzip } from 'node:zlib';
import { StringDecoder } from 'node:string_decoder';
import type { SqliteD1Database } from './sqliteD1';
import { KMA_ADMINISTRATIVE_AREAS } from '../regions/kmaAdministrativeAreas';
import { decodeBoundaryGeometry } from '../regions/administrativeBoundaries';

export function administrativeCatalogHash(): string {
  return createHash('sha256').update(JSON.stringify(KMA_ADMINISTRATIVE_AREAS)).digest('hex');
}
const areas = new Map(KMA_ADMINISTRATIVE_AREAS.map((area) => [area[0], area]));
const hashPattern = /^[a-f0-9]{64}$/;
const invalid = () => { throw new Error('BOUNDARY_IMPORT_INVALID'); };

// 모든 자료를 검증한 뒤 게시한다. 손상·코드 변경 시 이전 경계를 유지한다.
export async function importAdministrativeBoundaries(database: SqliteD1Database, path: string) {
  const input = createReadStream(path);
  const unzip = createGunzip();
  // 원본 스트림 오류도 압축 해제 스트림으로 전달하고 finally에서 닫는다.
  input.on('error', (error) => unzip.destroy(error));
  input.pipe(unzip);
  async function* lines() {
    const decoder = new StringDecoder('utf8');
    let pending = '', bytes = 0;
    for await (const chunk of unzip) {
      bytes += chunk.length;
      if (bytes > 512 * 1024 * 1024) throw new Error('BOUNDARY_IMPORT_TOO_LARGE');
      pending += decoder.write(chunk);
      let end: number;
      while ((end = pending.indexOf('\n')) !== -1) {
        if (end > 32 * 1024 * 1024) throw new Error('BOUNDARY_IMPORT_TOO_LARGE');
        yield pending.slice(0, end);
        pending = pending.slice(end + 1);
      }
      if (pending.length > 32 * 1024 * 1024) throw new Error('BOUNDARY_IMPORT_TOO_LARGE');
    }
    pending += decoder.end();
    if (pending.length) throw new Error('BOUNDARY_IMPORT_INCOMPLETE');
  }
  const digest = createHash('sha256');
  let manifest: Record<string, any> | undefined;
  let contentSha256: string | undefined;
  let complete = false, features = 0, grids = 0;
  const precisionCounts = { DONG: 0, PARENT: 0, UNMAPPED: 0 };
  let transaction = false;
  try {
    const feature = database.sqlite.prepare(`INSERT INTO administrative_boundary_features
      (sgis_code,source_name,kma_code,precision,min_lon,min_lat,max_lon,max_lat,geometry) VALUES (?,?,?,?,?,?,?,?,?)`);
    const grid = database.sqlite.prepare('INSERT INTO administrative_boundary_grid_regions (nx,ny,kma_code) VALUES (?,?,?)');
    database.sqlite.exec('BEGIN IMMEDIATE'); transaction = true;
    const previous = database.sqlite.prepare('SELECT version,manifest FROM administrative_boundary_dataset WHERE singleton=1')
      .get() as { version: string; manifest: string } | undefined;
    for await (const line of lines()) {
      if (!line || line.length > 32 * 1024 * 1024 || complete) invalid();
      const row = JSON.parse(line);
      if (!manifest) {
        if (row.type !== 'manifest' || row.format !== 1 || typeof row.version !== 'string' || !hashPattern.test(row.version) ||
            typeof row.sourceDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(row.sourceDate) || typeof row.source !== 'string' || !row.source.trim() ||
            !Number.isInteger(row.featureCount) || row.featureCount < 1 || row.featureCount > 50_000 ||
            !Number.isInteger(row.gridCount) || row.gridCount < 0 || row.gridCount > 37_697 ||
            !row.sourceSha256 || !Object.values(row.sourceSha256).every((v: string) => typeof v === 'string' && hashPattern.test(v))) invalid();
        if (row.catalogSha256 !== administrativeCatalogHash()) throw new Error('BOUNDARY_CATALOG_MISMATCH');
        manifest = row;
        database.sqlite.exec('DELETE FROM administrative_boundary_features; DELETE FROM administrative_boundary_grid_regions');
        continue;
      }
      if (row.type === 'complete') {
        if (!hashPattern.test(row.sha256) || row.sha256 !== digest.digest('hex')) throw new Error('BOUNDARY_CHECKSUM_MISMATCH');
        contentSha256 = row.sha256;
        if (previous?.version === manifest.version && JSON.parse(previous.manifest).contentSha256 !== contentSha256) {
          throw new Error('BOUNDARY_VERSION_CONFLICT');
        }
        complete = true; continue;
      }
      digest.update(line + '\n');
      if (row.type === 'feature') {
        const area = areas.get(row.kmaCode);
        if (typeof row.sgisCode !== 'string' || !/^\d{8}$/.test(row.sgisCode) || typeof row.sourceName !== 'string' || row.sourceName.length > 200 || !row.sourceName.trim() ||
            !['DONG', 'PARENT', 'UNMAPPED'].includes(row.precision) ||
            (row.precision === 'UNMAPPED' ? row.kmaCode !== null : !area) ||
            (row.precision === 'DONG' && area[0].endsWith('00000')) ||
            (row.precision === 'PARENT' && !area[0].endsWith('00000')) ||
            !Array.isArray(row.bbox) || row.bbox.length !== 4 || !row.bbox.every(Number.isFinite) ||
            row.bbox[0] < -180 || row.bbox[2] > 180 || row.bbox[1] < -90 || row.bbox[3] > 90 ||
            row.bbox[0] > row.bbox[2] || row.bbox[1] > row.bbox[3]) invalid();
        const raw = decodeBoundaryGeometry(row.geometry);
        const view = new DataView(raw.buffer, raw.byteOffset, raw.byteLength);
        let offset = 4;
        const bbox = [Infinity, Infinity, -Infinity, -Infinity];
        for (let ring = 0; ring < view.getUint32(0, true); ring++) {
          const count = view.getUint32(offset, true); offset += 4;
          for (let i = 0; i < count; i++, offset += 16) {
            const x = view.getFloat64(offset, true), y = view.getFloat64(offset + 8, true);
            bbox[0] = Math.min(bbox[0], x); bbox[1] = Math.min(bbox[1], y);
            bbox[2] = Math.max(bbox[2], x); bbox[3] = Math.max(bbox[3], y);
          }
        }
        if (bbox.some((v, i) => Math.abs(v - row.bbox[i]) > 1e-10)) throw new Error('BOUNDARY_BBOX_MISMATCH');
        feature.run(row.sgisCode, row.sourceName, row.kmaCode, row.precision, ...row.bbox, row.geometry);
        features++; precisionCounts[row.precision]++;
      } else if (row.type === 'grid') {
        if (!Number.isInteger(row.nx) || row.nx < 1 || row.nx > 149 || !Number.isInteger(row.ny) || row.ny < 1 || row.ny > 253 ||
            !areas.has(row.kmaCode) || !row.kmaCode.endsWith('00000')) invalid();
        grid.run(row.nx, row.ny, row.kmaCode); grids++;
      } else invalid();
      if (features > manifest.featureCount || grids > manifest.gridCount) invalid();
    }
    if (!manifest || !complete || features !== manifest.featureCount || grids !== manifest.gridCount ||
        Object.keys(precisionCounts).some((key) => precisionCounts[key] !== manifest.precisionCounts?.[key])) invalid();
    database.sqlite.prepare(`INSERT INTO administrative_boundary_dataset (singleton,version,manifest,imported_at) VALUES (1,?,?,?)
      ON CONFLICT(singleton) DO UPDATE SET version=excluded.version,manifest=excluded.manifest,imported_at=excluded.imported_at`)
      .run(manifest.version, JSON.stringify({ ...manifest, contentSha256 }), new Date().toISOString());
    database.sqlite.exec('COMMIT'); transaction = false;
    return { version: manifest.version, features, grids, precisionCounts };
  } finally {
    if (transaction) database.sqlite.exec('ROLLBACK');
    input.destroy(); unzip.destroy();
  }
}
