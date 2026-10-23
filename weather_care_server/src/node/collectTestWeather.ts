import { loadCollectionTargets } from '../collection/collectionTargets';
import { weatherDatabase } from '../database/weatherDatabase';
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
    if (runtime.env.WEATHER_COLLECTION_ENABLED === 'false') return;
    await collectNationwideUv(weatherDatabase(runtime.env), runtime.env.KMA_SERVICE_KEY, now);
    await collectNationwideLivingIndices(weatherDatabase(runtime.env), runtime.env.KMA_SERVICE_KEY, now);
    await collectWarnings(runtime.env, [], now);
    if (runtime.env.KMA_APIHUB_KEY) {
      await collectCurrentSnow(weatherDatabase(runtime.env), runtime.env.KMA_APIHUB_KEY, now);
      await runWeatherCollectionJob(runtime.env, {
        now, collectCore: false, dailyObservationLookbackDays: 7,
      });
    }
    const grids = await loadCollectionTargets(runtime.env);
    await archiveActiveDailyHumidity(weatherDatabase(runtime.env), now, grids);
    await archiveSnowProbabilityForecasts(weatherDatabase(runtime.env), now, grids);
  } finally {
    runtime.close();
  }
}

void main();
