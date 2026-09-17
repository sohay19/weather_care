import Database from 'better-sqlite3';
import { existsSync, mkdirSync, readFileSync, renameSync, rmSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { databaseSize } from './sqliteD1';
import { nodeDatabasePath } from './runtime';

const sourceArgument = process.argv[2];
if (!sourceArgument) {
  console.error(JSON.stringify({ event: 'd1_import_invalid', error: 'SQL_FILE_REQUIRED' }));
  process.exitCode = 2;
} else {
  const sourcePath = resolve(sourceArgument);
  const targetPath = nodeDatabasePath();
  const temporaryPath = `${targetPath}.importing`;
  if (!existsSync(sourcePath)) throw new Error('D1_EXPORT_NOT_FOUND');
  if (sourcePath === targetPath || sourcePath === temporaryPath) throw new Error('D1_IMPORT_PATH_CONFLICT');
  if (existsSync(targetPath) || databaseSize(targetPath) > 0) {
    throw new Error('NODE_DATABASE_ALREADY_EXISTS');
  }
  if (existsSync(temporaryPath)) throw new Error('D1_IMPORT_ALREADY_RUNNING');

  mkdirSync(dirname(targetPath), { recursive: true });
  const database = new Database(temporaryPath, { timeout: 5_000 });
  try {
    database.exec(readFileSync(sourcePath, 'utf8'));
    const integrity = database.pragma('integrity_check') as Array<{ integrity_check: string }>;
    if (integrity.length !== 1 || integrity[0]?.integrity_check !== 'ok') {
      throw new Error('D1_IMPORT_INTEGRITY_FAILED');
    }
    database.pragma('foreign_keys = ON');
    const foreignKeyErrors = database.pragma('foreign_key_check') as unknown[];
    if (foreignKeyErrors.length > 0) throw new Error('D1_IMPORT_FOREIGN_KEY_FAILED');
  } catch (error) {
    database.close();
    rmSync(temporaryPath, { force: true });
    throw error;
  }
  database.close();
  renameSync(temporaryPath, targetPath);
  console.log(JSON.stringify({ event: 'd1_import_completed', targetPath }));
}
