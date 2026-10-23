import type { ServerEnv } from '../types';

/** 기존 Worker 바인딩과 테스트는 단일 DB를 계속 사용할 수 있다. */
export function weatherDatabase(env: Pick<ServerEnv, 'DB' | 'WEATHER_DB'>): D1Database {
  return env.WEATHER_DB ?? env.DB;
}
