import { createNodeRuntime } from './runtime';
import { runSqliteMigrations } from './sqliteD1';

function main(): void {
  const runtime = createNodeRuntime({ migrate: false });
  try {
    const applied = runSqliteMigrations(runtime.database);
    console.log(JSON.stringify({ event: 'sqlite_migrations_completed', applied }));
  } finally {
    runtime.close();
  }
}

try {
  main();
} catch (error) {
  console.error(JSON.stringify({
    event: 'sqlite_migrations_failed',
    error: error instanceof Error ? error.message.split(':')[0] : 'UNKNOWN_ERROR',
  }));
  process.exitCode = 1;
}
