import { Hono } from 'hono';
import { ServerEnv } from '../types';

const router = new Hono<{ Bindings: ServerEnv }>();

router.get('/yesterday', async (c) => {
  const targetDate = yesterdayDate();
  return c.json({
    comparisonAvailable: false,
    current: null,
    comparison: null,
    targetDate,
    reason: 'COMPARISON_PROVENANCE_UNAVAILABLE',
  });
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

export default router;
