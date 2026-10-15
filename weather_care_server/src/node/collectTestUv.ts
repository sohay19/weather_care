import { collectCurrentUv } from '../services/currentUvCache';
import { createNodeRuntime } from './runtime';

async function main(): Promise<void> {
  const runtime = createNodeRuntime();
  try { await collectCurrentUv(runtime.env.DB, runtime.env.KMA_APIHUB_KEY, new Date()); }
  finally { runtime.close(); }
}

void main();
