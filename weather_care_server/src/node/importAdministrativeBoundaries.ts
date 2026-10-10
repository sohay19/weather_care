import { createNodeRuntime } from './runtime';
import { importAdministrativeBoundaries } from './administrativeBoundaryImport';

async function main() {
  const path = process.argv[2];
  if (!path || process.argv.length !== 3) throw new Error('BOUNDARY_IMPORT_PATH_REQUIRED');
  const runtime = createNodeRuntime();
  try {
    const result = await importAdministrativeBoundaries(runtime.database, path);
    console.log(JSON.stringify({ event: 'administrative_boundaries_imported', ...result }));
  } finally { runtime.close(); }
}
main().catch((error) => {
  const reason = /^BOUNDARY_[A-Z_]+$/.test(error?.message) ? error.message : 'BOUNDARY_IMPORT_FAILED';
  console.error(JSON.stringify({ event: 'administrative_boundaries_import_failed', reason }));
  process.exitCode = 1;
});
