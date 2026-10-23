import { weatherDatabase } from '../database/weatherDatabase';
import { collectCurrentUv } from '../services/currentUvCache';
import { createNodeRuntime } from './runtime';

async function main(): Promise<void> {
  const runtime = createNodeRuntime();
  try { if (runtime.env.WEATHER_COLLECTION_ENABLED === 'false') return; await collectCurrentUv(weatherDatabase(runtime.env), runtime.env.KMA_APIHUB_KEY, new Date()); }
  finally { runtime.close(); }
}

void main();
