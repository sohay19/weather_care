import { Hono } from 'hono';
import { safeErrorName } from '../observability/providerErrorDiagnostics';
import { ServerEnv } from '../types';
import { coordinatesFromQuery, regionFromQuery } from '../utils';
import {
  ultraShortApparentTemperature,
} from '../providers/weather/kmaUltraShortObservationProvider';
import { getGridObservationSnapshot, readCurrentGridObservation } from '../database/gridObservationRepository';
import { observationsFromGridSnapshot } from '../providers/weather/kmaGridObservationProvider';

interface ComparisonRouterOptions {
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
      const coordinates = coordinatesFromQuery(c.req.query('latitude'), c.req.query('longitude'));
      const current = await readCurrentGridObservation(c.env.DB, nx, ny, now, coordinates);
      if (!current) return unavailableYesterday(targetDate, 'CURRENT_GRID_OBSERVATION_UNAVAILABLE');
      const yesterdayAt = new Date(Date.parse(current.value.observedAt) - 24 * 60 * 60 * 1000).toISOString();
      const snapshot = await getGridObservationSnapshot(c.env.DB, yesterdayAt);
      const source = { nx: current.value.sourceLocation?.nx ?? nx, ny: current.value.sourceLocation?.ny ?? ny };
      const comparison = snapshot && observationsFromGridSnapshot(snapshot.value, [source]).get(`${source.nx}:${source.ny}`);
      if (!comparison) return unavailableYesterday(yesterdayAtKoreanDate(yesterdayAt), 'HISTORICAL_GRID_OBSERVATION_UNAVAILABLE');
      if (current.value.humidity === undefined || !Number.isFinite(current.value.humidity) ||
          current.value.humidity < 0 || current.value.humidity > 100 ||
          current.value.windSpeed === undefined || !Number.isFinite(current.value.windSpeed) ||
          current.value.windSpeed < 0 || current.value.windSpeed > 100) {
        return unavailableYesterday(yesterdayAtKoreanDate(yesterdayAt), 'APPARENT_TEMPERATURE_INPUT_UNAVAILABLE');
      }
      const currentApparent = ultraShortApparentTemperature(current.value);
      const comparisonApparent = ultraShortApparentTemperature(comparison);
      if (currentApparent === undefined || comparisonApparent === undefined) {
        return unavailableYesterday(yesterdayAtKoreanDate(yesterdayAt), 'APPARENT_TEMPERATURE_INPUT_UNAVAILABLE');
      }
      return c.json({
        comparisonAvailable: true,
        current: { temperature: current.value.temperature, apparentTemperature: currentApparent },
        comparison: { temperature: comparison.temperature, apparentTemperature: comparisonApparent },
        targetDate: yesterdayAtKoreanDate(yesterdayAt),
        basis: {
          provider: 'KMA_APIHUB_GRID_OBSERVATION', dataRole: 'OBSERVATION_VS_OBSERVATION',
          gridX: nx, gridY: ny,
          sourceLocation: current.value.sourceLocation,
        },
      });
    } catch (error) {
      console.error(JSON.stringify({
        event: 'yesterday_grid_comparison_fetch_failed',
        error: safeErrorName(error),
      }));
      return unavailableYesterday(targetDate, 'GRID_OBSERVATION_UNAVAILABLE');
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

function yesterdayAtKoreanDate(at: string): string {
  return new Date(Date.parse(at) + 9 * 60 * 60 * 1000).toISOString().slice(0, 10);
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
