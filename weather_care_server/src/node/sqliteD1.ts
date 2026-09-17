import Database from 'better-sqlite3';
import { mkdirSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

type SqlValue = string | number | bigint | Buffer | null;

function sqliteValue(value: unknown): SqlValue {
  if (value === undefined) return null;
  if (typeof value === 'boolean') return value ? 1 : 0;
  return value as SqlValue;
}

function d1Meta(options: {
  duration: number;
  changes?: number;
  lastRowId?: number | bigint;
  rowsRead?: number;
}): D1Meta & Record<string, unknown> {
  const changes = options.changes ?? 0;
  return {
    duration: options.duration,
    size_after: 0,
    rows_read: options.rowsRead ?? 0,
    rows_written: changes,
    last_row_id: Number(options.lastRowId ?? 0),
    changed_db: changes > 0,
    changes,
  };
}

class SqliteD1PreparedStatement {
  constructor(
    private readonly owner: SqliteD1Database,
    private readonly query: string,
    private readonly values: unknown[] = [],
  ) {}

  bind(...values: unknown[]): D1PreparedStatement {
    return new SqliteD1PreparedStatement(this.owner, this.query, values) as unknown as D1PreparedStatement;
  }

  async first<T = Record<string, unknown>>(colName?: string): Promise<T | null> {
    const statement = this.statement();
    const row = statement.get(...this.parameters()) as Record<string, unknown> | undefined;
    if (!row) return null;
    return (colName === undefined ? row : row[colName]) as T ?? null;
  }

  async run<T = Record<string, unknown>>(): Promise<D1Result<T>> {
    return this.execute<T>();
  }

  async all<T = Record<string, unknown>>(): Promise<D1Result<T>> {
    return this.execute<T>();
  }

  async raw<T = unknown[]>(options?: { columnNames?: boolean }): Promise<T[] | [string[], ...T[]]> {
    const statement = this.statement();
    if (!statement.reader) return options?.columnNames ? [[]] : [];
    const rows = statement.raw(true).all(...this.parameters()) as T[];
    if (!options?.columnNames) return rows;
    return [statement.columns().map((column) => column.name), ...rows];
  }

  execute<T = Record<string, unknown>>(): D1Result<T> {
    const startedAt = performance.now();
    const statement = this.statement();
    if (statement.reader) {
      const results = statement.all(...this.parameters()) as T[];
      return {
        success: true,
        results,
        meta: d1Meta({ duration: performance.now() - startedAt, rowsRead: results.length }),
      };
    }

    const result = statement.run(...this.parameters());
    return {
      success: true,
      results: [],
      meta: d1Meta({
        duration: performance.now() - startedAt,
        changes: result.changes,
        lastRowId: result.lastInsertRowid,
      }),
    };
  }

  belongsTo(database: SqliteD1Database): boolean {
    return this.owner === database;
  }

  private statement() {
    return this.owner.sqlite.prepare(this.query);
  }

  private parameters(): SqlValue[] {
    return this.values.map(sqliteValue);
  }
}

export class SqliteD1Database {
  readonly sqlite: Database.Database;

  constructor(databasePath: string) {
    const resolvedPath = databasePath === ':memory:' ? databasePath : resolve(databasePath);
    if (resolvedPath !== ':memory:') mkdirSync(dirname(resolvedPath), { recursive: true });
    this.sqlite = new Database(resolvedPath, { timeout: 5_000 });
    this.sqlite.pragma('foreign_keys = ON');
    this.sqlite.pragma('busy_timeout = 5000');
    this.sqlite.pragma('journal_mode = WAL');
    this.sqlite.pragma('synchronous = NORMAL');
  }

  prepare(query: string): D1PreparedStatement {
    return new SqliteD1PreparedStatement(this, query) as unknown as D1PreparedStatement;
  }

  async batch<T = unknown>(statements: D1PreparedStatement[]): Promise<D1Result<T>[]> {
    const prepared = statements.map((statement) => statement as unknown as SqliteD1PreparedStatement);
    if (prepared.some((statement) => !statement.belongsTo(this))) {
      throw new Error('SQLITE_D1_BATCH_DATABASE_MISMATCH');
    }
    return this.sqlite.transaction(() => prepared.map((statement) => statement.execute<T>()))();
  }

  async exec(query: string): Promise<D1ExecResult> {
    const startedAt = performance.now();
    this.sqlite.exec(query);
    return { count: 1, duration: performance.now() - startedAt };
  }

  withSession(): D1DatabaseSession {
    return {
      prepare: (query: string) => this.prepare(query),
      batch: <T = unknown>(statements: D1PreparedStatement[]) => this.batch<T>(statements),
      getBookmark: () => null,
    } as D1DatabaseSession;
  }

  async dump(): Promise<ArrayBuffer> {
    const serialized = this.sqlite.serialize();
    return serialized.buffer.slice(
      serialized.byteOffset,
      serialized.byteOffset + serialized.byteLength,
    ) as ArrayBuffer;
  }

  close(): void {
    this.sqlite.close();
  }

  backup(destinationPath: string): Promise<Database.BackupMetadata> {
    mkdirSync(dirname(resolve(destinationPath)), { recursive: true });
    return this.sqlite.backup(resolve(destinationPath));
  }
}

export function asD1Database(database: SqliteD1Database): D1Database {
  return database as unknown as D1Database;
}

export function migrationDirectory(): string {
  return resolve(process.cwd(), 'migrations');
}

export function runSqliteMigrations(
  database: SqliteD1Database,
  directory = migrationDirectory(),
): string[] {
  database.sqlite.exec(`CREATE TABLE IF NOT EXISTS d1_migrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
  )`);
  const applied = new Set(
    database.sqlite.prepare('SELECT name FROM d1_migrations').all()
      .map((row) => String((row as { name: unknown }).name)),
  );
  const pending = readdirSync(directory)
    .filter((name) => /^\d+_.+\.sql$/.test(name) && !applied.has(name))
    .sort((left, right) => left.localeCompare(right));

  for (const name of pending) {
    const sql = readFileSync(resolve(directory, name), 'utf8');
    database.sqlite.transaction(() => {
      database.sqlite.exec(sql);
      database.sqlite.prepare('INSERT INTO d1_migrations (name) VALUES (?)').run(name);
    })();
  }
  return pending;
}

export function databaseSize(databasePath: string): number {
  try {
    return statSync(resolve(databasePath)).size;
  } catch {
    return 0;
  }
}
