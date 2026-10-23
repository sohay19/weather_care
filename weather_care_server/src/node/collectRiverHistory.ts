import { collectDailyRiverHistory } from '../collection/riverHistoryCollection';
import { weatherDatabase } from '../database/weatherDatabase';
import { createNodeRuntime } from './runtime';

async function main(): Promise<void> {
  const runtime = createNodeRuntime();
  try {
    if (runtime.env.WEATHER_COLLECTION_ENABLED === 'false') return;
    if (!runtime.env.HRFCO_API_KEY) throw new Error('HRFCO_KEY_MISSING');
    const summary = await collectDailyRiverHistory({ db: weatherDatabase(runtime.env),
      key: runtime.env.HRFCO_API_KEY, now: new Date(), requestIntervalMs: 300 });
    console.log(JSON.stringify({ event: 'daily_river_history_completed', ...summary }));
    if (summary.failed || summary.budgetExhausted) process.exitCode = 1;
  } finally { runtime.close(); }
}

void main().catch(() => {
  console.error(JSON.stringify({ event: 'daily_river_history_failed' }));
  process.exitCode = 1;
});
