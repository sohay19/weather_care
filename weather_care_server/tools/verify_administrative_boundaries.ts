import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { SqliteD1Database, asD1Database, runSqliteMigrations } from '../src/node/sqliteD1';
import { importAdministrativeBoundaries } from '../src/node/administrativeBoundaryImport';
import { resolveAdministrativeBoundary } from '../src/regions/administrativeBoundaries';
import { kmaGridCoordinates } from '../src/regions/kmaGridCoordinates';
import { KMA_ADMINISTRATIVE_AREAS } from '../src/regions/kmaAdministrativeAreas';
import { saveGridObservationSnapshot } from '../src/database/gridObservationRepository';
import { saveCollectedCache } from '../src/database/collectedWeatherRepository';
import { NATIONAL_UV_KEY } from '../src/services/nationwideWeatherCache';
import { observationSnapshot } from '../test-node/gridObservationFixture';
import weatherRouter from '../src/api/weather';

async function main() {
  const [artifact, auditPath, output] = process.argv.slice(2);
  if (!artifact || !auditPath || !output) throw new Error('사용법: tsx tools/verify_administrative_boundaries.ts 경계.gz 감사.json 결과.json');
  const audit = JSON.parse(readFileSync(auditPath, 'utf8'));
  if (createHash('sha256').update(readFileSync(artifact)).digest('hex') !== audit.artifactSha256) throw new Error('BOUNDARY_ARTIFACT_MISMATCH');
  const database = new SqliteD1Database(':memory:');
  const previousFetch = globalThis.fetch;
  let externalCalls = 0;
  globalThis.fetch = async () => { externalCalls++; throw new Error('검증 중 외부 호출 금지'); };
  try {
    runSqliteMigrations(database);
    const imported = await importAdministrativeBoundaries(database, artifact);
    const db = asD1Database(database);
    const failures: object[] = [];
    const results = { features: 0, landSamples: 0, centers: { DONG: 0, PARENT: 0, OUTSIDE: 0, UNMAPPED: 0 }, gridReferences: 0 };
    for (const [category, samples] of [['features', audit.features], ['landSamples', audit.landSamples]] as const) {
      for (const sample of samples) {
        const actual = await resolveAdministrativeBoundary(db, { nx: sample.nx ?? 1, ny: sample.ny ?? 1, coordinates: sample.sample });
        if (actual?.area?.[0] !== sample.kmaCode) failures.push({ category, sgisCode: sample.sgisCode, nx: sample.nx, ny: sample.ny, expected: sample.kmaCode, actual: actual?.area?.[0], precision: actual?.precision });
        else results[category]++;
      }
    }
    const centers = [];
    for (const sample of audit.centers) {
      const actual = await resolveAdministrativeBoundary(db, { nx: sample.nx, ny: sample.ny, coordinates: kmaGridCoordinates(sample.nx, sample.ny) });
      results.centers[actual.precision]++;
      centers.push({ nx: sample.nx, ny: sample.ny, precision: actual.precision, code: actual.area?.[0] });
    }
    const grids = database.sqlite.prepare('SELECT nx,ny,kma_code AS code FROM administrative_boundary_grid_regions').all() as { nx: number; ny: number; code: string }[];
    for (const grid of grids) {
      const actual = await resolveAdministrativeBoundary(db, grid);
      if (actual?.area?.[0] === grid.code && actual.precision === 'GRID_PARENT') results.gridReferences++;
      else failures.push({ category: 'gridReferences', ...grid, actual: actual?.area?.[0] });
    }
    // 실제 경계 + 합성 날씨로 대표 캐시 없는 여행지 응답 계약을 확인한다.
    const now = new Date();
    const observed = new Date(Math.floor(now.getTime() / 600_000) * 600_000 - 600_000).toISOString();
    await saveGridObservationSnapshot(db, observationSnapshot(observed, 23.8), now);
    const forecasts = {};
    for (const code of ['5172037000', '4139054000']) forecasts[code] = { areaNo: code, issuedAt: now.toISOString(),
      points: [{ forecastAt: now.toISOString(), uvIndex: 4 }], provider: 'KMA_LIVING_INDEX_V5' };
    await saveCollectedCache(db, { key: NATIONAL_UV_KEY, type: 'COLLECTED_NATIONWIDE_UV', value: { forecasts }, updatedAt: now });
    const requests = [];
    for (const point of [{ name: '여행지', nx: 71, ny: 130, latitude: 37.697249, longitude: 127.660949, code: '5172037000' },
                        { name: '은행동', nx: 57, ny: 124, latitude: 37.434, longitude: 126.803, code: '4139054000' }]) {
      const expectedName = KMA_ADMINISTRATIVE_AREAS.find((area) => area[0] === point.code)[1];
      for (const route of ['main', 'today', 'weekly']) {
        const response = await weatherRouter.request(`/${route}?nx=${point.nx}&ny=${point.ny}&latitude=${point.latitude}&longitude=${point.longitude}`, {}, { DB: db });
        const data = await response.json() as Record<string, any>;
        const valid = response.status === 200 && data.region.nx === point.nx && data.region.ny === point.ny && data.region.name === expectedName &&
          (route === 'weekly' || (data.current.temperature === 23.8 && data.current.uvIndex === 4));
        requests.push({ point: point.name, route, status: response.status, region: data.region, uvIndex: data.current?.uvIndex, valid });
        if (!valid) failures.push({ category: 'route', point: point.name, route, status: response.status, region: data.region, current: data.current });
      }
    }
    const report = { source: audit.manifest, artifactSha256: audit.artifactSha256, imported, results, centers,
      landSampleGrids: new Set(audit.landSamples.map((s) => `${s.nx}:${s.ny}`)).size,
      ambiguousGridWholeCellReferences: audit.unresolvedGridReferences.length,
      upperOnlyBoundaries: audit.features.filter((f) => f.precision === 'PARENT'),
      requests, externalCalls, failures,
      representativeCacheRows: database.sqlite.prepare("SELECT COUNT(*) AS n FROM weather_cache WHERE cache_type='COLLECTED_REGION'").get() };
    writeFileSync(output, JSON.stringify(report, null, 2) + '\n', 'utf8');
    console.log(JSON.stringify({ imported, results, landSampleGrids: report.landSampleGrids,
      ambiguousGridWholeCellReferences: report.ambiguousGridWholeCellReferences, requests, externalCalls, failures: failures.length }));
    if (failures.length || externalCalls) process.exitCode = 1;
  } finally { globalThis.fetch = previousFetch; database.close(); }
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
