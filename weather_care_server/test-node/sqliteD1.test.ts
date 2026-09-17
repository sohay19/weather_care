import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { app } from '../src/index';
import { nodeServerEnv } from '../src/node/runtime';
import { asD1Database, runSqliteMigrations, SqliteD1Database } from '../src/node/sqliteD1';

const cleanup: Array<() => void> = [];

afterEach(() => {
  while (cleanup.length > 0) cleanup.pop()?.();
});

function temporaryDatabase(): SqliteD1Database {
  const directory = mkdtempSync(join(tmpdir(), 'weather-care-node-'));
  const database = new SqliteD1Database(join(directory, 'weather-care.sqlite'));
  cleanup.push(() => {
    database.close();
    rmSync(directory, { recursive: true, force: true });
  });
  return database;
}

describe('SQLite D1 호환 계층', () => {
  it('기존 D1 마이그레이션을 순서대로 한 번만 적용한다', async () => {
    const database = temporaryDatabase();

    expect(runSqliteMigrations(database)).toHaveLength(11);
    expect(runSqliteMigrations(database)).toEqual([]);

    const row = await asD1Database(database)
      .prepare('SELECT COUNT(*) AS count FROM d1_migrations')
      .first<{ count: number }>();
    expect(row?.count).toBe(11);
  });

  it('prepare, bind, first, all, run, batch 결과를 D1 형태로 반환한다', async () => {
    const database = temporaryDatabase();
    const db = asD1Database(database);
    await db.exec('CREATE TABLE sample (id INTEGER PRIMARY KEY, value TEXT NOT NULL)');

    const inserted = await db.prepare('INSERT INTO sample (value) VALUES (?)').bind('첫째').run();
    expect(inserted.meta.changes).toBe(1);
    const batched = await db.batch([
      db.prepare('INSERT INTO sample (value) VALUES (?)').bind('둘째'),
      db.prepare('SELECT value FROM sample ORDER BY id'),
    ]);
    expect(batched[0].meta.changes).toBe(1);
    expect(batched[1].results).toEqual([{ value: '첫째' }, { value: '둘째' }]);
    expect(await db.prepare('SELECT value FROM sample WHERE id = ?').bind(2).first('value'))
      .toBe('둘째');
  });

  it('같은 Hono API가 로컬 SQLite 바인딩을 사용한다', async () => {
    const database = temporaryDatabase();
    runSqliteMigrations(database);
    const response = await app.fetch(
      new Request('http://localhost/api/v1/weather/main?nx=60&ny=121'),
      nodeServerEnv(database, {}),
    );

    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: 'WEATHER_CACHE_NOT_READY' });
  });
});
