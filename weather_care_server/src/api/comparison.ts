import { Hono } from 'hono';
import { ServerEnv } from '../types';
import { regionFromQuery } from '../utils';
import {
  KmaUltraShortObservationProvider,
  ultraShortApparentTemperature,
} from '../providers/weather/kmaUltraShortObservationProvider';
import { getCollectedCache } from '../database/collectedWeatherRepository';
import type { CollectedRegionBundle } from '../collection/collectionTypes';
import { nextForecastSnapshot } from './weather';

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

interface ComparisonRouterOptions {
  fetcher?: typeof fetch;
  now?: () => Date;
}

export function createComparisonRouter(
  options: ComparisonRouterOptions = {},
): Hono<{ Bindings: ServerEnv }> {
  const router = new Hono<{ Bindings: ServerEnv }>();

  router.get('/yesterday', async (c) => {
    const now = options.now?.() ?? new Date();
    const targetDate = yesterdayDate(now);
    const { nx, ny } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
    try {
      const regionRecord = await getCollectedCache<CollectedRegionBundle>(
        c.env.DB,
        `COLLECTED_REGION_${nx}_${ny}`,
      );
      const nextForecast = regionRecord?.status === 'AVAILABLE'
        ? nextForecastSnapshot(regionRecord.value.forecast.hourly, now)
        : undefined;
      const forecastAt = nextForecast?.forecastAt ?? nextForecast?.observedAt;
      const forecastInstant = forecastAt === undefined
        ? Number.NaN
        : Date.parse(forecastAt);
      if (
        nextForecast?.temperature === undefined ||
        !Number.isFinite(forecastInstant)
      ) {
        return unavailableYesterday(targetDate, 'NEXT_FORECAST_UNAVAILABLE');
      }
      const comparisonKoreanClock = new Date(
        forecastInstant + KST_OFFSET_MS - 24 * 60 * 60 * 1000,
      );
      const comparison = await new KmaUltraShortObservationProvider({
        serviceKey: c.env.KMA_SERVICE_KEY,
        fetcher: options.fetcher,
        now: () => now,
      }).getAt(nx, ny, comparisonKoreanClock);
      if (comparison.temperature === undefined) {
        return unavailableYesterday(targetDate, 'HISTORICAL_GRID_OBSERVATION_UNAVAILABLE');
      }
      return c.json({
        comparisonAvailable: true,
        current: {
          temperature: nextForecast.temperature,
          apparentTemperature: nextForecast.apparentTemperature,
        },
        comparison: {
          temperature: comparison.temperature,
          apparentTemperature: ultraShortApparentTemperature(comparison),
        },
        targetDate: comparison.observedAt.slice(0, 10),
        basis: {
          provider: 'KMA_FORECAST_VS_ULTRA_SHORT_OBSERVATION',
          dataRole: 'FORECAST_VS_OBSERVATION',
          gridX: nx,
          gridY: ny,
          currentForecastAt: forecastAt,
          forecastIssuedAt: nextForecast.issuedAt,
          comparisonObservedAt: comparison.observedAt,
        },
      });
    } catch (error) {
      console.error(JSON.stringify({
        event: 'yesterday_grid_comparison_fetch_failed',
        error: error instanceof Error ? error.name : 'UnknownError',
      }));
      return unavailableYesterday(targetDate, 'FORECAST_OR_OBSERVATION_UNAVAILABLE');
    }
  });

  router.get('/last-year', async (c) => {
    const targetDate = lastYearDate(options.now?.() ?? new Date());
    return c.json({
      comparisonAvailable: false,
      targetDate,
      reason: 'COMPARISON_PROVENANCE_UNAVAILABLE',
    });
  });

  return router;
}

const router = createComparisonRouter();

export function yesterdayDate(now = new Date()): string {
  const nowInKorea = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  nowInKorea.setUTCDate(nowInKorea.getUTCDate() - 1);
  return nowInKorea.toISOString().slice(0, 10);
}

export function lastYearDate(now = new Date()): string {
  const nowInKorea = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  nowInKorea.setUTCFullYear(nowInKorea.getUTCFullYear() - 1);
  return nowInKorea.toISOString().slice(0, 10);
}

function unavailableYesterday(targetDate: string, reason: string) {
  return new Response(JSON.stringify({
    comparisonAvailable: false,
    current: null,
    comparison: null,
    targetDate,
    reason,
  }), {
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
  });
}

export default router;
