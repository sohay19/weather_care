import { dirname, relative, resolve } from 'node:path';
import { existsSync, realpathSync, statSync } from 'node:fs';
import type { ServerEnv } from '../types';
import { FixedWindowRateLimit } from './rateLimit';
import { asD1Database, runSqliteMigrations, SqliteD1Database } from './sqliteD1';

const REQUIRED_SECRET_NAMES = [
  'KMA_SERVICE_KEY',
  'KMA_APIHUB_KEY',
  'FCM_CLIENT_EMAIL',
  'FCM_PRIVATE_KEY',
  'GA_ADMIN_CLIENT_EMAIL',
  'GA_ADMIN_PRIVATE_KEY',
] as const;

export interface NodeRuntime {
  database: SqliteD1Database;
  weatherDatabase?: SqliteD1Database;
  env: ServerEnv;
  close(): void;
}

export function nodeDatabasePath(environment = process.env): string {
  return resolve(environment.NODE_DATABASE_PATH ?? './data/weather-care-users.sqlite');
}

export function nodeWeatherDatabasePath(environment = process.env): string {
  return resolve(environment.NODE_WEATHER_DATABASE_PATH ??
    resolve(dirname(nodeDatabasePath(environment)), 'weather-care-weather.sqlite'));
}

export function assertDistinctDatabasePaths(paths: string[]): void {
  const normalized = paths.map(path => {
    const absolute = resolve(path);
    let ancestor = absolute;
    while (!existsSync(ancestor)) {
      const parent = dirname(ancestor);
      if (parent === ancestor) throw new Error('NODE_DATABASE_DIRECTORY_MISSING');
      ancestor = parent;
    }
    const value = resolve(realpathSync(ancestor), relative(ancestor, absolute));
    return process.platform === 'win32' ? value.toLowerCase() : value;
  });
  if (new Set(normalized).size !== paths.length) throw new Error('NODE_DATABASE_PATH_CONFLICT');
  const files = paths.filter(path => existsSync(path)).map(path => statSync(path));
  if (files.some((file, i) => files.slice(i + 1).some(other =>
    file.dev === other.dev && file.ino === other.ino))) throw new Error('NODE_DATABASE_PATH_CONFLICT');
}

export function nodeMigrationDirectory(scope: 'users' | 'weather'): string {
  return resolve(process.cwd(), 'node-migrations', scope);
}

export function nodeServerEnv(
  database: SqliteD1Database,
  environment: NodeJS.ProcessEnv = process.env,
  weatherDatabase: SqliteD1Database = database,
): ServerEnv {
  return {
    DB: asD1Database(database),
    WEATHER_DB: asD1Database(weatherDatabase),
    WEATHER_COLLECTION_ENABLED: environment.WEATHER_COLLECTION_ENABLED ?? 'true',
    TEST_DATA_ENABLED: !!environment.TEST_ACCESS_KEY?.trim() &&
      nodeDatabasePath(environment) === resolve('/var/lib/weather-care/weather-care-users-test.sqlite'),
    INSTALLATION_ENROLL_LIMIT: new FixedWindowRateLimit(20, 60_000),
    ANALYTICS_DELETION_LIMIT: new FixedWindowRateLimit(3, 60_000),
    APP_ORIGIN: environment.APP_ORIGIN ?? 'http://127.0.0.1:8787',
    FCM_PROJECT_ID: environment.FCM_PROJECT_ID ?? 'weather-care-2aaa8',
    GA_PROPERTY_ID: environment.GA_PROPERTY_ID ?? '549443110',
    KMA_SERVICE_KEY: environment.KMA_SERVICE_KEY ?? '',
    KMA_APIHUB_KEY: environment.KMA_APIHUB_KEY ?? '',
    KHOA_SERVICE_KEY: environment.KHOA_SERVICE_KEY,
    KWATER_SERVICE_KEY: environment.KWATER_SERVICE_KEY,
    NIFS_API_KEY: environment.NIFS_API_KEY,
    HRFCO_API_KEY: environment.HRFCO_API_KEY,
    ITS_API_KEY: environment.ITS_API_KEY,
    FCM_CLIENT_EMAIL: environment.FCM_CLIENT_EMAIL ?? '',
    FCM_PRIVATE_KEY: environment.FCM_PRIVATE_KEY ?? '',
    GA_ADMIN_CLIENT_EMAIL: environment.GA_ADMIN_CLIENT_EMAIL ?? '',
    GA_ADMIN_PRIVATE_KEY: environment.GA_ADMIN_PRIVATE_KEY ?? '',
    RECOVERY_MODE: environment.RECOVERY_MODE,
    NATIONWIDE_PRECOLLECT_ENABLED:
      environment.NATIONWIDE_PRECOLLECT_ENABLED ?? 'true',
  };
}

export function assertNodeEnvironment(environment: NodeJS.ProcessEnv = process.env): void {
  const missing: string[] = REQUIRED_SECRET_NAMES.filter((name) => !environment[name]?.trim());
  if (!environment.ITS_API_KEY?.trim()) missing.push('ITS_API_KEY');
  if (missing.length > 0) {
    throw new Error(`NODE_ENVIRONMENT_MISSING:${missing.join(',')}`);
  }
}

export function createNodeRuntime(options: {
  environment?: NodeJS.ProcessEnv;
  migrate?: boolean;
} = {}): NodeRuntime {
  const environment = options.environment ?? process.env;
  const userPath = nodeDatabasePath(environment);
  const weatherPath = nodeWeatherDatabasePath(environment);
  const peers: string[] = JSON.parse(environment.NODE_COLLECTION_USER_DATABASE_PATHS ?? '[]');
  if (!Array.isArray(peers) || peers.some(path => typeof path !== 'string' || !path.trim())) {
    throw new Error('NODE_COLLECTION_USER_DATABASE_PATHS_INVALID');
  }
  assertDistinctDatabasePaths([userPath, weatherPath, ...peers]);
  const opened: SqliteD1Database[] = [];
  try {
    const database = new SqliteD1Database(userPath);
    opened.push(database);
    if (database.sqlite.prepare("SELECT 1 FROM sqlite_master WHERE type='table' AND name='weather_cache'").get()) {
      throw new Error('NODE_LEGACY_DATABASE_REQUIRES_SPLIT');
    }
    const weatherDatabase = new SqliteD1Database(weatherPath);
    opened.push(weatherDatabase);
    if (weatherDatabase.sqlite.prepare("SELECT 1 FROM sqlite_master WHERE type='table' AND name='installations'").get()) {
      throw new Error('NODE_WEATHER_DATABASE_CONTAINS_USER_TABLES');
    }
    if (options.migrate !== false) {
      runSqliteMigrations(database, nodeMigrationDirectory('users'));
      runSqliteMigrations(weatherDatabase, nodeMigrationDirectory('weather'));
    }
    const env = nodeServerEnv(database, environment, weatherDatabase);
    env.COLLECTION_USER_DATABASES = [env.DB, ...peers.map(path => {
      const peer = new SqliteD1Database(path, { readonly: true });
      opened.push(peer);
      peer.sqlite.prepare('SELECT nx, ny, latitude, longitude FROM installations LIMIT 0').all();
      return asD1Database(peer);
    })];
    return { database, weatherDatabase, env, close: () => {
      for (const db of opened.reverse()) db.close();
      opened.length = 0;
    } };
  } catch (error) {
    for (const db of opened.reverse()) db.close();
    throw error;
  }
}
