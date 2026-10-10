import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createHash } from 'node:crypto';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { gzipSync } from 'node:zlib';
import { SqliteD1Database, asD1Database, runSqliteMigrations } from '../src/node/sqliteD1';
import { administrativeCatalogHash, importAdministrativeBoundaries } from '../src/node/administrativeBoundaryImport';
import { boundaryContainsPoint, decodeBoundaryGeometry, resolveAdministrativeBoundary } from '../src/regions/administrativeBoundaries';
import { resolveSavedLocation } from '../src/regions/resolvedLocation';
import { administrativeAreaForLocation } from '../src/regions/nationwideLocation';
import { readCollectedEnvironmentalData } from '../src/providers/environmental/environmentalDataService';

let database: SqliteD1Database, directory: string;
beforeEach(() => { database = new SqliteD1Database(':memory:'); runSqliteMigrations(database); directory = mkdtempSync(join(tmpdir(), 'weather-boundaries-')); });
afterEach(() => { vi.restoreAllMocks(); database.close(); rmSync(directory, { recursive: true, force: true }); });
const square = (x: number, y: number, size = 1): number[][] => [[x, y], [x + size, y], [x + size, y + size], [x, y + size], [x, y]];
function payload(rings: number[][][]) {
  const raw = Buffer.alloc(4 + rings.reduce((sum, ring) => sum + 4 + ring.length * 16, 0));
  raw.writeUInt32LE(rings.length); let offset = 4;
  for (const ring of rings) {
    raw.writeUInt32LE(ring.length, offset); offset += 4;
    for (const [x, y] of ring) { raw.writeDoubleLE(x, offset); raw.writeDoubleLE(y, offset + 8); offset += 16; }
  }
  return gzipSync(raw).toString('base64');
}
function feature(sgisCode: string, kmaCode: string, rings = [square(126, 37)]) {
  const points = rings.flat();
  return { type: 'feature', sgisCode, kmaCode, sourceName: '공식 자료 검증 표본', precision: 'DONG',
    bbox: [Math.min(...points.map((p) => p[0])), Math.min(...points.map((p) => p[1])), Math.max(...points.map((p) => p[0])), Math.max(...points.map((p) => p[1]))], geometry: payload(rings) };
}
function archive(rows: Record<string, any>[], options: { corrupt?: boolean; catalogHash?: string; version?: string } = {}) {
  const data = rows.map((row) => JSON.stringify(row) + '\n').join('');
  const checksum = createHash('sha256').update(data).digest('hex');
  const counts = { DONG: 0, PARENT: 0, UNMAPPED: 0 };
  rows.filter((row) => row.type === 'feature').forEach((row) => counts[row.precision]++);
  const manifest = { type: 'manifest', format: 1, version: options.version ?? checksum, sourceDate: '2025-06-30', source: 'SGIS 테스트 경계',
    sourceSha256: { boundaries: checksum, codebook: checksum }, catalogSha256: options.catalogHash ?? administrativeCatalogHash(),
    featureCount: rows.filter((row) => row.type === 'feature').length, gridCount: rows.filter((row) => row.type === 'grid').length, precisionCounts: counts };
  const path = join(directory, `${checksum}-${options.corrupt ? 'bad' : 'ok'}.gz`);
  writeFileSync(path, gzipSync(JSON.stringify(manifest) + '\n' + data + JSON.stringify({ type: 'complete', sha256: options.corrupt ? '0'.repeat(64) : checksum }) + '\n'));
  return path;
}

describe('전국 행정 경계', () => {
  it('구멍·떨어진 섬을 보존하고 선 위·밖의 점을 구분한다', () => {
    const raw = decodeBoundaryGeometry(payload([square(126, 37), square(126.2, 37.2, 0.1), square(128, 37, 0.2)]));
    expect(boundaryContainsPoint(raw, 126.1, 37.1)).toBe(true);
    expect(boundaryContainsPoint(raw, 126.25, 37.25)).toBe(false);
    expect(boundaryContainsPoint(raw, 128.1, 37.1)).toBe(true);
    expect(boundaryContainsPoint(raw, 127, 37.5)).toBe(true);
    expect(boundaryContainsPoint(raw, 127.5, 37.5)).toBe(false);
    expect(() => decodeBoundaryGeometry(payload([[[126, 37], [127, 37], [127, 38], [126, 38]]]))).toThrow('NOT_CLOSED');
    const oversized = Buffer.from(payload([square(126, 37)]), 'base64');
    oversized.writeUInt32LE(0xffffffff, oversized.length - 4);
    expect(() => decodeBoundaryGeometry(oversized.toString('base64'))).toThrow('TOO_LARGE');
  });

  it('손상·코드표 불일치·중복·압축 오류 시 이전 자료를 원자적으로 유지한다', async () => {
    await importAdministrativeBoundaries(database, archive([feature('31150540', '4139054000')]));
    const version = database.sqlite.prepare('SELECT version FROM administrative_boundary_dataset').get();
    const newer = feature('31150541', '4139052000');
    await expect(importAdministrativeBoundaries(database, archive([newer], { version: (version as { version: string }).version }))).rejects.toThrow('VERSION_CONFLICT');
    await expect(importAdministrativeBoundaries(database, archive([newer], { corrupt: true }))).rejects.toThrow('CHECKSUM');
    await expect(importAdministrativeBoundaries(database, archive([newer], { catalogHash: '0'.repeat(64) }))).rejects.toThrow('CATALOG');
    await expect(importAdministrativeBoundaries(database, archive([newer, newer]))).rejects.toThrow();
    const invalidPath = join(directory, 'truncated.gz'); writeFileSync(invalidPath, gzipSync('x').subarray(0, 12));
    await expect(importAdministrativeBoundaries(database, invalidPath)).rejects.toThrow();
    await expect(importAdministrativeBoundaries(database, join(directory, 'missing.gz'))).rejects.toThrow();
    expect(database.sqlite.prepare('SELECT version FROM administrative_boundary_dataset').get()).toEqual(version);
    expect(database.sqlite.prepare('SELECT sgis_code AS code FROM administrative_boundary_features').all()).toEqual([{ code: '31150540' }]);
  });

  it('같은 격자의 서로 다른 GPS를 각각 연결하고 경계 공유는 공통 상위로 연결한다', async () => {
    await importAdministrativeBoundaries(database, archive([
      feature('31150540', '4139054000', [square(126, 37)]), feature('31150541', '4139052000', [square(127, 37)]),
    ]));
    const db = asD1Database(database);
    const at = (longitude: number) => resolveAdministrativeBoundary(db, { nx: 57, ny: 124, coordinates: { latitude: 37.5, longitude } });
    expect((await at(126.5))?.area?.[0]).toBe('4139054000');
    expect((await at(127.5))?.area?.[0]).toBe('4139052000');
    expect((await at(127))?.area?.[0]).toBe('4139000000');
    expect((await at(130))?.precision).toBe('OUTSIDE');
  });

  it('좌표 없는 요청은 검증된 전체격자 상위 참조만 쓰고 대표 동 추정을 차단한다', async () => {
    await importAdministrativeBoundaries(database, archive([
      feature('31150540', '4139054000'), { type: 'grid', nx: 57, ny: 124, kmaCode: '4139000000' },
    ]));
    const db = asD1Database(database), now = new Date('2026-10-08T04:00:00Z');
    expect((await resolveSavedLocation(db, { nx: 57, ny: 124 }, now)).adminCode).toBe('4139000000');
    const unknown = await resolveSavedLocation(db, { nx: 58, ny: 128 }, now);
    expect(unknown.boundaryChecked).toBe(true);
    expect(administrativeAreaForLocation(unknown)).toBeUndefined();
    expect(administrativeAreaForLocation({ nx: 57, ny: 124, boundaryChecked: true })).toBeUndefined();
  });

  it('경계 버전 변경 시 위치 캐시를 갱신하고 정확한 좌표를 해시한다', async () => {
    const db = asD1Database(database), now = new Date('2026-10-08T04:00:00Z');
    const location = { nx: 71, ny: 130, coordinates: { latitude: 37.697249, longitude: 127.660949 } };
    await importAdministrativeBoundaries(database, archive([feature('32510370', '5172037000', [square(127, 37)])]));
    const first = await resolveSavedLocation(db, location, now);
    expect(first).toMatchObject({ nx: 71, ny: 130, adminCode: '5172037000' });
    expect((await resolveSavedLocation(db, { ...location, coordinates: { ...location.coordinates, longitude: 127.6609491 } }, now)).adminCode).toBe('5172037000');
    expect(database.sqlite.prepare("SELECT count(*) AS n FROM weather_cache WHERE cache_type='COLLECTED_LOCATION_IDENTITY'").get()).toEqual({ n: 2 });
    await importAdministrativeBoundaries(database, archive([feature('32510371', '5172036000', [square(127, 37)])]));
    expect((await resolveSavedLocation(db, location, now)).adminCode).toBe('5172036000');
    expect((await resolveSavedLocation(db, { ...location, adminCode: '5172037000' }, now)).adminCode).toBe('5172037000');
  });

  it('경계 조회가 실패해도 날씨 요청을 막지 않고 고유명사 제를 보존한다', async () => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    database.sqlite.exec('DROP TABLE administrative_boundary_dataset');
    const location = await resolveSavedLocation(asD1Database(database), { nx: 71, ny: 130, coordinates: { latitude: 37.697249, longitude: 127.660949 } }, new Date());
    expect(location.boundaryChecked).toBe(true);
    expect(location.adminCode).toBeUndefined();
    expect(administrativeAreaForLocation({ nx: 0, ny: 0, regionName: '부산 연제구 거제1동' })?.[1]).toContain('거제');
    expect(administrativeAreaForLocation({ nx: 0, ny: 0, regionName: '서울 서대문구 홍제1동' })?.[1]).toContain('홍제');
  });

  it('좌표 없는 사용자의 동 이름을 같은 격자의 다른 사용자에게 공유하지 않는다', async () => {
    await importAdministrativeBoundaries(database, archive([feature('31150540', '4139054000')]));
    const db = asD1Database(database), now = new Date();
    expect((await resolveSavedLocation(db, { nx: 57, ny: 124, regionName: '경기도 시흥시 은행동' }, now)).adminCode).toBe('4139054000');
    expect((await resolveSavedLocation(db, { nx: 57, ny: 124 }, now)).adminCode).toBeUndefined();
    expect(database.sqlite.prepare("SELECT COUNT(*) AS n FROM weather_cache WHERE cache_type='COLLECTED_LOCATION_IDENTITY'").get()).toEqual({ n: 0 });
  });

  it('경계 밖 위치에 예전 대표 격자의 자외선을 붙이지 않는다', async () => {
    await importAdministrativeBoundaries(database, archive([feature('31150540', '4139054000')]));
    const now = new Date();
    const uv = { areaNo: '4139054000', issuedAt: now.toISOString(), provider: 'KMA_LIVING_INDEX_V5' as const,
      points: [{ forecastAt: now.toISOString(), uvIndex: 4 }] };
    const result = await readCollectedEnvironmentalData(asD1Database(database), 57, 124, {
      uv, sources: { uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'AVAILABLE' }, airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' } },
    }, now, { latitude: 37.5, longitude: 130 }, { nx: 57, ny: 124, coordinates: { latitude: 37.5, longitude: 130 } });
    expect(result.uv).toBeUndefined();
  });

  it('격자만으로 지역을 확정할 수 없으면 GPS 필요 사유를 반환하고 이름·GPS로 보완한다', async () => {
    const { saveCollectedCache } = await import('../src/database/collectedWeatherRepository');
    await importAdministrativeBoundaries(database, archive([feature('31150540', '4139054000')]));
    const db = asD1Database(database), now = new Date();
    await saveCollectedCache(db, { key: 'COLLECTED_NATIONWIDE_UV', type: 'COLLECTED_NATIONWIDE_UV', value: {
      forecasts: { '4139054000': { areaNo: '4139054000', issuedAt: now.toISOString(), provider: 'KMA_LIVING_INDEX_V5',
        points: [{ forecastAt: now.toISOString(), uvIndex: 4 }] } },
    }, updatedAt: now });
    const fallback = { sources: { uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'UNAVAILABLE' as const },
      airQuality: { provider: 'AIRKOREA', state: 'UNAVAILABLE' as const } } };
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    const missing = await readCollectedEnvironmentalData(db, 57, 124, fallback, now);
    expect(missing.uv).toBeUndefined();
    expect(missing.sources.uv.reason).toBe('LOCATION_COORDINATES_REQUIRED');
    const named = await readCollectedEnvironmentalData(db, 57, 124, fallback, now, undefined,
      { nx: 57, ny: 124, regionName: '경기도 시흥시 은행동' });
    expect(named.uv?.areaNo).toBe('4139054000');
    const gps = await readCollectedEnvironmentalData(db, 57, 124, fallback, now, { latitude: 37.5, longitude: 126.5 },
      { nx: 57, ny: 124, coordinates: { latitude: 37.5, longitude: 126.5 } });
    expect(gps.uv?.areaNo).toBe('4139054000');
    expect(gps.sources.uv.reason).toBeUndefined();
  });
});
