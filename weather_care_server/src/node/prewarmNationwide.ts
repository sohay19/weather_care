import { pathToFileURL } from 'node:url';
import { runWeatherCollectionJob } from '../collection/weatherCollectionJob';
import {
  NATIONWIDE_FORECAST_GRIDS,
  NATIONWIDE_FORECAST_GRID_SHARD_COUNT,
} from '../regions/nationwideForecastGridCatalog';
import { assertNodeEnvironment, createNodeRuntime } from './runtime';

export async function prewarmNationwide(): Promise<void> {
  const runtime = createNodeRuntime();
  const now = new Date();
  runtime.env.NATIONWIDE_PRECOLLECT_ENABLED = 'true';

  try {
    for (
      let shardIndex = 0;
      shardIndex < NATIONWIDE_FORECAST_GRID_SHARD_COUNT;
      shardIndex += 1
    ) {
      await runWeatherCollectionJob(runtime.env, {
        now,
        collectCore: true,
        collectActiveDetails: false,
        nationwideShardIndex: shardIndex,
      });
      console.log(JSON.stringify({
        event: 'nationwide_prewarm_shard_completed',
        shardIndex,
        shardCount: NATIONWIDE_FORECAST_GRID_SHARD_COUNT,
      }));
    }

    const statement = runtime.database.sqlite.prepare(
      'SELECT 1 FROM weather_cache WHERE cache_key = ? LIMIT 1',
    );
    const missing = NATIONWIDE_FORECAST_GRIDS.filter(({ nx, ny }) =>
      statement.get(`COLLECTED_REGION_${nx}_${ny}`) === undefined,
    );
    console.log(JSON.stringify({
      event: 'nationwide_prewarm_completed',
      total: NATIONWIDE_FORECAST_GRIDS.length,
      collected: NATIONWIDE_FORECAST_GRIDS.length - missing.length,
      missing: missing.length,
      missingSample: missing.slice(0, 20),
    }));
    if (missing.length > 0) throw new Error('NATIONWIDE_PREWARM_INCOMPLETE');
  } finally {
    runtime.close();
  }
}

async function main(): Promise<void> {
  assertNodeEnvironment();
  await prewarmNationwide();
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  void main().catch((error) => {
    console.error(JSON.stringify({
      event: 'nationwide_prewarm_failed',
      error: error instanceof Error ? error.name : 'UnknownError',
    }));
    process.exitCode = 1;
  });
}
