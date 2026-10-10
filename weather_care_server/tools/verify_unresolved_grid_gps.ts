import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { SqliteD1Database, runSqliteMigrations, asD1Database } from '../src/node/sqliteD1';
import { importAdministrativeBoundaries } from '../src/node/administrativeBoundaryImport';
import { KMA_ADMINISTRATIVE_AREAS } from '../src/regions/kmaAdministrativeAreas';
import { resolveSavedLocation } from '../src/regions/resolvedLocation';
import { resolveAdministrativeBoundary } from '../src/regions/administrativeBoundaries';
import { saveGridObservationSnapshot } from '../src/database/gridObservationRepository';
import { saveCollectedCache } from '../src/database/collectedWeatherRepository';
import { NATIONAL_UV_KEY, readNationwideWeekly } from '../src/services/nationwideWeatherCache';
import { observationSnapshot } from '../test-node/gridObservationFixture';
import weatherRouter from '../src/api/weather';

async function main() {
  const [artifact, auditPath, output] = process.argv.slice(2);
  if (!artifact || !auditPath || !output) throw new Error('경계.gz 감사.json 결과.json 경로가 필요합니다.');
  const audit = JSON.parse(readFileSync(auditPath, 'utf8'));
  if (createHash('sha256').update(readFileSync(artifact)).digest('hex') !== audit.artifactSha256) throw new Error('BOUNDARY_ARTIFACT_MISMATCH');
  const database = new SqliteD1Database(':memory:');
  const originalFetch = globalThis.fetch, originalWarn = console.warn;
  let externalCalls = 0;
  const diagnosticCounts: Record<string, number> = {};
  globalThis.fetch = async () => { externalCalls++; throw new Error('외부 API 호출 금지'); };
  // 합성 자료에 시드하지 않은 부가 캐시 경고는 집계해 검증 출력의 중복을 줄인다.
  console.warn = (line) => {
    try { const event = JSON.parse(String(line)); diagnosticCounts[event.event] = (diagnosticCounts[event.event] ?? 0) + 1; }
    catch { originalWarn(line); }
  };
  try {
    runSqliteMigrations(database);
    await importAdministrativeBoundaries(database, artifact);
    const db = asD1Database(database);
    const known = new Set(audit.unresolvedGridReferences.map((row) => `${row.nx}:${row.ny}`));
    const missing = audit.centers.filter((row) => !known.has(`${row.nx}:${row.ny}`));
    const wanted = new Set(missing.map((row) => `${row.nx}:${row.ny}`));
    const byCode = new Map(KMA_ADMINISTRATIVE_AREAS.map((area) => [area[0], area]));
    const parents = KMA_ADMINISTRATIVE_AREAS.filter((area) => area[0].endsWith('00000'));
    const grouped = new Map<string, any[]>();
    for (const sample of audit.landSamples) {
      const key = `${sample.nx}:${sample.ny}`;
      if (wanted.has(key)) grouped.set(key, [...(grouped.get(key) ?? []), sample]);
    }
    const now = new Date();
    const observed = new Date(Math.floor(now.getTime() / 600_000) * 600_000 - 600_000).toISOString();
    await saveGridObservationSnapshot(db, observationSnapshot(observed, 23.8), now);
    const codes = [...new Set<string>(audit.features.map((sample) => sample.kmaCode))];
    const forecasts = Object.fromEntries(codes.map((code, i) => [code, { areaNo: code, issuedAt: now.toISOString(),
      points: [{ forecastAt: now.toISOString(), uvIndex: i % 13 }], provider: 'KMA_LIVING_INDEX_V5' }]));
    await saveCollectedCache(db, { key: NATIONAL_UV_KEY, type: 'COLLECTED_NATIONWIDE_UV', value: { forecasts }, updatedAt: now });
    const failures: object[] = [], grids: object[] = [];
    let gpsSamples = 0, routeRequests = 0, provinceSamples = 0, explicitNameRequests = 0, coordinateRequiredRequests = 0;
    const causes = { COAST_OR_COVERAGE_GAP: 0, MULTI_PROVINCE: 0 };
    for (const grid of missing) {
      const samples = grouped.get(`${grid.nx}:${grid.ny}`) ?? [];
      if (!samples.length) { failures.push({ reason: 'LAND_SAMPLE_MISSING', ...grid }); continue; }
      const names = samples.map((s) => byCode.get(s.kmaCode)[1].replace(/\s/g, ''));
      const common = parents.some((p) => names.every((n) => n.startsWith(p[1].replace(/\s/g, ''))));
      const cause = common ? 'COAST_OR_COVERAGE_GAP' : 'MULTI_PROVINCE'; causes[cause]++;
      const withoutCoordinates = await resolveAdministrativeBoundary(db, grid);
      if (withoutCoordinates?.area) failures.push({ reason: 'UNPROVEN_GRID_IDENTITY', nx: grid.nx, ny: grid.ny });
      for (const sample of samples) {
        const actual = await resolveSavedLocation(db, { nx: grid.nx, ny: grid.ny, coordinates: sample.sample }, now);
        if (actual.adminCode !== sample.kmaCode || actual.nx !== grid.nx || actual.ny !== grid.ny) {
          failures.push({ reason: 'GPS_IDENTITY_MISMATCH', nx: grid.nx, ny: grid.ny, expected: sample.kmaCode, actual: actual.adminCode });
        } else gpsSamples++;
      }
      // 같은 격자의 여러 시도에 대해 이름 없는 GPS의 API 응답을 각각 검사한다.
      const selected = [...new Map(samples.map((sample) => [byCode.get(sample.kmaCode)[1].split(' ')[0], sample])).values()];
      provinceSamples += selected.length;
      for (const sample of selected) {
        const expected = byCode.get(sample.kmaCode);
        const location = { nx: grid.nx, ny: grid.ny, coordinates: sample.sample };
        const weekly = await readNationwideWeekly(db, location, now);
        if (weekly?.value.uv?.areaNo !== expected[0]) failures.push({ reason: 'WEEKLY_UV_MISMATCH', nx: grid.nx, ny: grid.ny, expected: expected[0] });
        for (const route of ['main', 'today', 'weekly']) {
          const response = await weatherRouter.request(`/${route}?nx=${grid.nx}&ny=${grid.ny}&latitude=${sample.sample.latitude}&longitude=${sample.sample.longitude}`, {}, { DB: db });
          const data = await response.json() as Record<string, any>;
          routeRequests++;
          if (response.status !== 200 || data.region?.name !== expected[1] || data.region?.nx !== grid.nx || data.region?.ny !== grid.ny ||
              (route === 'weekly' ? data.region.adminCode !== expected[0] : data.current.uvIndex !== forecasts[expected[0]].points[0].uvIndex)) {
            failures.push({ reason: 'ROUTE_MISMATCH', nx: grid.nx, ny: grid.ny, route, status: response.status, expected: expected[0], actualRegion: data.region });
          }
        }
      }
      const sample = samples[0], expected = byCode.get(sample.kmaCode);
      const withName = await resolveSavedLocation(db, { nx: grid.nx, ny: grid.ny, regionName: expected[1] }, now);
      if (withName.adminCode === expected[0]) explicitNameRequests++; else failures.push({ reason: 'NAME_MISMATCH', nx: grid.nx, ny: grid.ny });
      const noGps = await weatherRouter.request(`/main?nx=${grid.nx}&ny=${grid.ny}`, {}, { DB: db });
      const noGpsData = await noGps.json() as Record<string, any>;
      if (noGps.status === 200 && noGpsData.environmentalSources?.uv?.reason === 'LOCATION_COORDINATES_REQUIRED' && noGpsData.current.uvIndex == null) {
        coordinateRequiredRequests++;
      } else failures.push({ reason: 'MISSING_GPS_DIAGNOSTIC_MISMATCH', nx: grid.nx, ny: grid.ny, status: noGps.status });
      grids.push({ nx: grid.nx, ny: grid.ny, cause, landSamples: samples.length, testedProvinces: selected.length,
        codes: [...new Set(samples.map((s) => s.kmaCode))], missingCoordinates: 'LOCATION_COORDINATES_REQUIRED' });
    }
    const report = { sourceVersion: audit.manifest.version, grids: missing.length, causes, gpsSamples, provinceSamples, routeRequests,
      explicitNameRequests, coordinateRequiredRequests, externalCalls, failures, details: grids, diagnosticCounts,
      verificationData: 'SGIS 실제 경계·합성 전국 실황/UV, 외부 API 호출 금지',
      representativeCacheRows: database.sqlite.prepare("SELECT COUNT(*) AS n FROM weather_cache WHERE cache_type='COLLECTED_REGION'").get() };
    writeFileSync(output, JSON.stringify(report, null, 2) + '\n', 'utf8');
    console.log(JSON.stringify({ ...report, details: undefined, failures: failures.length }));
    if (failures.length || externalCalls) process.exitCode = 1;
  } finally { globalThis.fetch = originalFetch; console.warn = originalWarn; database.close(); }
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
