import { mkdirSync, readdirSync, rmSync, statSync } from 'node:fs';
import { basename, dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { createNodeRuntime, nodeDatabasePath, nodeWeatherDatabasePath } from './runtime';

export function backupTimestamp(date: Date): string {
  return date.toISOString().replaceAll(':', '').replaceAll('-', '').replace(/\.\d{3}Z$/, 'Z');
}

async function main(): Promise<void> {
  const now = new Date();
  const databasePath = nodeDatabasePath();
  const backupDirectory = resolve(
    process.env.NODE_BACKUP_DIR ?? resolve(dirname(databasePath), 'backups'),
  );
  const retentionDays = Number(process.env.NODE_BACKUP_RETENTION_DAYS ?? '7');
  if (!Number.isInteger(retentionDays) || retentionDays < 1 || retentionDays > 365) {
    throw new Error('NODE_BACKUP_RETENTION_INVALID');
  }
  mkdirSync(backupDirectory, { recursive: true });
  const prefixes = [databasePath, nodeWeatherDatabasePath()].map(path => basename(path, '.sqlite'));
  if (new Set(prefixes).size !== prefixes.length) throw new Error('NODE_BACKUP_FILENAME_CONFLICT');
  const destinations = prefixes.map(prefix => resolve(backupDirectory, `${prefix}-${backupTimestamp(now)}.sqlite`));
  const runtime = createNodeRuntime();
  try {
    await runtime.database.backup(destinations[0]);
    await runtime.weatherDatabase!.backup(destinations[1]);
  } finally {
    runtime.close();
  }

  const cutoff = now.getTime() - retentionDays * 24 * 60 * 60 * 1000;
  for (const name of readdirSync(backupDirectory)) {
    if (!prefixes.some(prefix => name.startsWith(`${prefix}-`) &&
      /^\d{8}T\d{6}Z\.sqlite$/.test(name.slice(prefix.length + 1)))) continue;
    const path = resolve(backupDirectory, name);
    if (statSync(path).mtimeMs < cutoff) rmSync(path);
  }
  console.log(JSON.stringify({ event: 'sqlite_backup_completed', destinations, retentionDays }));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  void main().catch((error) => {
    console.error(JSON.stringify({
      event: 'sqlite_backup_failed',
      error: error instanceof Error ? error.message.split(':')[0] : 'UNKNOWN_ERROR',
    }));
    process.exitCode = 1;
  });
}
