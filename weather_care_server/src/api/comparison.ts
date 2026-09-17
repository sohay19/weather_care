import { Hono } from 'hono';
import { ServerEnv } from '../types';
import { regionFromQuery } from '../utils';
import type { KmaHourlyComparison } from '../providers/weather/kmaHourlyObservationProvider';
import {
  collectedCacheKey,
  getCollectedCache,
} from '../database/collectedWeatherRepository';

const router = new Hono<{ Bindings: ServerEnv }>();

router.get('/yesterday', async (c) => {
  const targetDate = yesterdayDate();
  const { nx, ny } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
  try {
    const cached = await getCollectedCache<KmaHourlyComparison>(
      c.env.DB,
      collectedCacheKey.comparison(nx, ny),
    );
    if (!cached || cached.status !== 'AVAILABLE') {
      return unavailableYesterday(targetDate, 'COMPARISON_CACHE_NOT_READY');
    }
    const result = cached.value;
    return c.json({
      comparisonAvailable: true,
      current: result.current,
      comparison: result.comparison,
      targetDate,
      basis: {
        provider: 'KMA_ASOS',
        dataRole: 'OBSERVATION',
        stationId: result.stationId,
        distanceKm: result.distanceKm,
        currentObservedAt: result.currentObservedAt,
        comparisonObservedAt: result.comparisonObservedAt,
      },
    });
  } catch (error) {
    console.error(JSON.stringify({
      event: 'yesterday_comparison_cache_failed',
      error: error instanceof Error ? error.name : 'UnknownError',
    }));
    return unavailableYesterday(targetDate, 'COMPARISON_CACHE_UNAVAILABLE');
  }
});

router.get('/last-year', async (c) => {
  const targetDate = lastYearDate();
  return c.json({
    comparisonAvailable: false,
    targetDate,
    reason: 'COMPARISON_PROVENANCE_UNAVAILABLE',
  });
});

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
