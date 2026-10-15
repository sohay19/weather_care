import { archiveSnowProbabilityForecasts } from '../services/snowProbabilityHistory';
import { collectWarnings, runWeatherCollectionJob } from '../collection/weatherCollectionJob';
import { collectNationwideUv } from '../services/nationwideWeatherCache';
import { collectNationwideLivingIndices } from '../services/livingIndices';
import { collectCurrentSnow } from '../services/currentSnowCache';
import { createNodeRuntime } from './runtime';
import { archiveActiveDailyHumidity } from '../services/dailyHumidityHistory';

async function main(): Promise<void> {
  const runtime = createNodeRuntime();
  const now = new Date();
  try {
    await collectNationwideUv(runtime.env.DB, runtime.env.KMA_SERVICE_KEY, now);
    await collectNationwideLivingIndices(runtime.env.DB, runtime.env.KMA_SERVICE_KEY, now);
    await collectWarnings(runtime.env, [], now);
    if (runtime.env.KMA_APIHUB_KEY) {
      await collectCurrentSnow(runtime.env.DB, runtime.env.KMA_APIHUB_KEY, now);
      await runWeatherCollectionJob(runtime.env, {
        now, collectCore: false, dailyObservationLookbackDays: 7,
      });
    }
    const grids = await runtime.env.DB.prepare('SELECT DISTINCT nx, ny FROM installations')
      .all<{ nx: number; ny: number }>();
    await archiveActiveDailyHumidity(runtime.env.DB, now, grids.results);
    await archiveSnowProbabilityForecasts(runtime.env.DB, now, grids.results);
  } finally {
    runtime.close();
  }
}

void main();
