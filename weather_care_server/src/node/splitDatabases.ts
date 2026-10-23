import { existsSync, openSync, closeSync, linkSync, unlinkSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { assertDistinctDatabasePaths, nodeMigrationDirectory } from './runtime';
import { runSqliteMigrations, SqliteD1Database } from './sqliteD1';

export interface SplitDatabasePaths {
  productionSource: string;
  testSource: string;
  weather: string;
  productionUsers: string;
  testUsers: string;
}

type TableColumn = { name: string; pk: number };

function tableNames(db: SqliteD1Database): string[] {
  return (db.sqlite.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'd1_migrations'")
    .all() as Array<{ name: string }>).map(row => row.name);
}

function copyRows(source: SqliteD1Database, target: SqliteD1Database, merge: boolean, only?: string[]): void {
  const available = new Set(tableNames(source));
  for (const table of tableNames(target)) {
    if (only && !only.includes(table)) continue;
    if (merge && table.startsWith('administrative_boundary_')) continue;
    if (!available.has(table)) continue; // 구버전에 없던 새 테이블은 빈 상태로 시작한다.
    const columns = target.sqlite.prepare(`PRAGMA table_info("${table}")`).all() as TableColumn[];
    const sourceColumns = new Set((source.sqlite.prepare(`PRAGMA table_info("${table}")`).all() as TableColumn[])
      .map(column => column.name));
    if ([...sourceColumns].some(name => !columns.some(column => column.name === name))) {
      throw new Error(`DATABASE_SPLIT_UNKNOWN_COLUMN:${table}`);
    }
    const names = columns.filter(column => sourceColumns.has(column.name)).map(column => column.name);
    const quoted = names.map(name => `"${name}"`).join(',');
    const primary = columns.filter(column => column.pk).sort((a, b) => a.pk - b.pk).map(column => column.name);
    const updates = names.filter(name => !primary.includes(name));
    const stamp = ['updated_at', 'recorded_at', 'collected_at', 'attempted_at'].find(name => names.includes(name));
    let conflict = '';
    if (merge) {
      conflict = ` ON CONFLICT (${primary.map(name => `"${name}"`).join(',')}) DO NOTHING`;
      if (table === 'api_usage_daily') {
        // 기존 카운터의 중복 여부를 복원할 수 없으므로 합산해 한도를 보수적으로 유지한다.
        conflict = ` ON CONFLICT(usage_date,provider) DO UPDATE SET
          request_count=api_usage_daily.request_count+excluded.request_count,
          response_bytes=api_usage_daily.response_bytes+excluded.response_bytes,
          updated_at=MAX(api_usage_daily.updated_at,excluded.updated_at)`;
      } else if (stamp) {
        conflict = ` ON CONFLICT (${primary.map(name => `"${name}"`).join(',')}) DO UPDATE SET ` +
          updates.map(name => `"${name}"=excluded."${name}"`).join(',') +
          ` WHERE julianday(excluded."${stamp}") > julianday("${table}"."${stamp}")`;
      }
    }
    const insert = target.sqlite.prepare(`INSERT INTO "${table}" (${quoted}) VALUES (${names.map(() => '?').join(',')})${conflict}`);
    const filter = table === 'grid_extra_snapshots' ? " WHERE source != 'KMA_LIGHTNING_TEST'" : '';
    for (const row of source.sqlite.prepare(`SELECT ${quoted} FROM "${table}"${filter}`).iterate() as Iterable<Record<string, unknown>>) {
      insert.run(...names.map(name => row[name]));
    }
  }
}

function mergeBoundaries(source: SqliteD1Database, target: SqliteD1Database): void {
  if (!tableNames(source).includes('administrative_boundary_dataset')) return;
  const sourceVersion = source.sqlite.prepare('SELECT imported_at FROM administrative_boundary_dataset WHERE singleton=1')
    .get() as { imported_at: string } | undefined;
  const targetVersion = target.sqlite.prepare('SELECT imported_at FROM administrative_boundary_dataset WHERE singleton=1')
    .get() as { imported_at: string } | undefined;
  if (!sourceVersion || (targetVersion && Date.parse(sourceVersion.imported_at) <= Date.parse(targetVersion.imported_at))) return;
  // 서로 다른 버전의 경계/격자 매핑을 섞지 않고 데이터셋 전체를 교체한다.
  const tables = tableNames(target).filter(name => name.startsWith('administrative_boundary_'));
  for (const table of tables) target.sqlite.exec(`DELETE FROM "${table}"`);
  copyRows(source, target, false, tables);
}

function copyUsers(source: SqliteD1Database, target: SqliteD1Database): void {
  const triggers = target.sqlite.prepare("SELECT name,sql FROM sqlite_master WHERE type='trigger'")
    .all() as Array<{ name: string; sql: string }>;
  target.sqlite.transaction(() => {
    for (const trigger of triggers) target.sqlite.exec(`DROP TRIGGER "${trigger.name}"`);
    copyRows(source, target, false);
    for (const trigger of triggers) target.sqlite.exec(trigger.sql);
  })();
}

/** 원본은 읽기 전용으로 열고, 검증된 새 파일 3개만 생성한다. 전환 중 서비스는 중지해야 한다. */
export function splitLegacyDatabases(paths: SplitDatabasePaths): void {
  const sources = [paths.productionSource, paths.testSource].map(path => resolve(path));
  const outputs = [paths.weather, paths.productionUsers, paths.testUsers].map(path => resolve(path));
  const pending = outputs.map(path => `${path}.splitting`);
  assertDistinctDatabasePaths([...sources, ...outputs, ...pending]);
  if (sources.some(path => !existsSync(path))) throw new Error('DATABASE_SPLIT_SOURCE_MISSING');
  if ([...outputs, ...pending].some(path => existsSync(path))) throw new Error('DATABASE_SPLIT_OUTPUT_EXISTS');
  const opened: SqliteD1Database[] = [];
  try {
    const [production, test] = sources.map(path => {
      const db = new SqliteD1Database(path, { readonly: true });
      opened.push(db);
      if (!tableNames(db).includes('installations') || !tableNames(db).includes('weather_cache')) {
        throw new Error('DATABASE_SPLIT_SOURCE_NOT_LEGACY');
      }
      return db;
    });
    const [weather, productionUsers, testUsers] = pending.map((path, index) => {
      // wx는 기존 파일의 덮어쓰기를 막는다. 상위 폴더는 운영자가 준비한다.
      closeSync(openSync(path, 'wx', 0o600));
      const db = new SqliteD1Database(path);
      opened.push(db);
      runSqliteMigrations(db, nodeMigrationDirectory(index === 0 ? 'weather' : 'users'));
      return db;
    });
    const supported = new Set([...tableNames(weather), ...tableNames(productionUsers), 'test_cache_sync_state']);
    for (const source of [production, test]) {
      if (tableNames(source).some(table => !supported.has(table))) throw new Error('DATABASE_SPLIT_UNKNOWN_TABLE');
    }
    production.sqlite.transaction(() => {
      copyUsers(production, productionUsers);
      weather.sqlite.transaction(() => copyRows(production, weather, false))();
    })();
    test.sqlite.transaction(() => {
      copyUsers(test, testUsers);
      weather.sqlite.transaction(() => {
        copyRows(test, weather, true);
        mergeBoundaries(test, weather);
      })();
    })();
    for (const db of [weather, productionUsers, testUsers]) {
      const check = db.sqlite.pragma('quick_check', { simple: true });
      if (check !== 'ok' || (db.sqlite.pragma('foreign_key_check') as unknown[]).length) {
        throw new Error('DATABASE_SPLIT_VALIDATION_FAILED');
      }
      db.sqlite.pragma('wal_checkpoint(TRUNCATE)');
    }
    for (const db of opened.reverse()) db.close();
    opened.length = 0;
    for (let index = 0; index < outputs.length; index++) {
      // 긴 복사 도중 다른 작업이 최종 경로를 생성해도 기존 파일을 덮어쓰지 않는다.
      linkSync(pending[index], outputs[index]);
      unlinkSync(pending[index]);
    }
  } finally {
    for (const db of opened.reverse()) db.close();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const args = process.argv.slice(2);
    if (args.length !== 5) throw new Error('DATABASE_SPLIT_REQUIRES_5_PATHS');
    splitLegacyDatabases({ productionSource: args[0], testSource: args[1], weather: args[2],
      productionUsers: args[3], testUsers: args[4] });
    console.log(JSON.stringify({ event: 'database_split_completed' }));
  } catch (error) {
    console.error(JSON.stringify({ event: 'database_split_failed',
      error: error instanceof Error ? error.message.split(':')[0] : 'UNKNOWN_ERROR' }));
    process.exitCode = 1;
  }
}
