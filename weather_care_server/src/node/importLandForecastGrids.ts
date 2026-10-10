import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import { createNodeRuntime } from './runtime';
import { saveCollectedCache } from '../database/collectedWeatherRepository';

export const NATIONAL_LAND_GRIDS_KEY = 'COLLECTED_NATIONWIDE_LAND_GRIDS';

export async function importLandForecastGrids(db: D1Database, path: string, now = new Date()): Promise<number> {
  const bytes = await readFile(path);
  if (bytes.length > 1_000_000) throw new Error('LAND_GRID_IMPORT_TOO_LARGE');
  const value = JSON.parse(new TextDecoder('utf8').decode(bytes));
  const dataset = await db.prepare('SELECT version,manifest FROM administrative_boundary_dataset WHERE singleton=1')
    .first<{ version: string; manifest: string }>();
  if (!dataset || value.boundaryVersion !== dataset.version || value.sourceSha256 !== JSON.parse(dataset.manifest).sourceSha256.boundaries) {
    throw new Error('LAND_GRID_BOUNDARY_VERSION_MISMATCH');
  }
  if (!Array.isArray(value.grids) || value.count !== value.grids.length || value.count < 1 || value.count > 37697 ||
      value.grids.some(({ nx, ny }) => !Number.isInteger(nx) || nx < 1 || nx > 149 || !Number.isInteger(ny) || ny < 1 || ny > 253) ||
      new Set(value.grids.map(({ nx, ny }) => `${nx}:${ny}`)).size !== value.count) throw new Error('LAND_GRID_IMPORT_INVALID');
  await saveCollectedCache(db, { key: NATIONAL_LAND_GRIDS_KEY, type: 'COLLECTED_NATIONWIDE_LAND_GRIDS', value, updatedAt: now });
  return value.count;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const runtime = createNodeRuntime();
  void importLandForecastGrids(runtime.env.DB, process.argv[2]).then((count) => {
    console.log(JSON.stringify({ event: 'national_land_grids_imported', count }));
  }).catch(() => { console.error(JSON.stringify({ event: 'national_land_grids_import_failed' })); process.exitCode = 1; })
    .finally(() => runtime.close());
}
