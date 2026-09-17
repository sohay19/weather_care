import { resolve } from 'node:path';
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
  env: ServerEnv;
  close(): void;
}

export function nodeDatabasePath(environment = process.env): string {
  return resolve(environment.NODE_DATABASE_PATH ?? './data/weather-care.sqlite');
}

export function nodeServerEnv(
  database: SqliteD1Database,
  environment: NodeJS.ProcessEnv = process.env,
): ServerEnv {
  return {
    DB: asD1Database(database),
    INSTALLATION_ENROLL_LIMIT: new FixedWindowRateLimit(20, 60_000),
    ANALYTICS_DELETION_LIMIT: new FixedWindowRateLimit(3, 60_000),
    APP_ORIGIN: environment.APP_ORIGIN ?? 'http://127.0.0.1:8787',
    FCM_PROJECT_ID: environment.FCM_PROJECT_ID ?? 'weather-care-2aaa8',
    GA_PROPERTY_ID: environment.GA_PROPERTY_ID ?? '549443110',
    KMA_SERVICE_KEY: environment.KMA_SERVICE_KEY ?? '',
    KMA_APIHUB_KEY: environment.KMA_APIHUB_KEY ?? '',
    ITS_RELAY_URL: environment.ITS_RELAY_URL ?? '',
    ITS_RELAY_TOKEN: environment.ITS_RELAY_TOKEN ?? '',
    ITS_API_KEY: environment.ITS_API_KEY,
    FCM_CLIENT_EMAIL: environment.FCM_CLIENT_EMAIL ?? '',
    FCM_PRIVATE_KEY: environment.FCM_PRIVATE_KEY ?? '',
    GA_ADMIN_CLIENT_EMAIL: environment.GA_ADMIN_CLIENT_EMAIL ?? '',
    GA_ADMIN_PRIVATE_KEY: environment.GA_ADMIN_PRIVATE_KEY ?? '',
    RECOVERY_MODE: environment.RECOVERY_MODE,
  };
}

export function assertNodeEnvironment(environment: NodeJS.ProcessEnv = process.env): void {
  const missing: string[] = REQUIRED_SECRET_NAMES.filter((name) => !environment[name]?.trim());
  const relayConfigured = Boolean(
    environment.ITS_RELAY_URL?.trim() && environment.ITS_RELAY_TOKEN?.trim(),
  );
  if (!relayConfigured && !environment.ITS_API_KEY?.trim()) {
    missing.push('ITS_RELAY_URL/ITS_RELAY_TOKEN 또는 ITS_API_KEY');
  }
  if (missing.length > 0) {
    throw new Error(`NODE_ENVIRONMENT_MISSING:${missing.join(',')}`);
  }
}

export function createNodeRuntime(options: {
  environment?: NodeJS.ProcessEnv;
  migrate?: boolean;
} = {}): NodeRuntime {
  const environment = options.environment ?? process.env;
  const database = new SqliteD1Database(nodeDatabasePath(environment));
  if (options.migrate !== false) runSqliteMigrations(database);
  return {
    database,
    env: nodeServerEnv(database, environment),
    close: () => database.close(),
  };
}
