import { Hono } from 'hono';
import { getDailySnapshot } from '../database/comparisonRepository';
import { regionFromQuery } from '../utils';
import { ServerEnv } from '../types';

const router = new Hono<{ Bindings: ServerEnv }>();

router.get('/yesterday', async (c) => {
  const { nx, ny } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
  const targetDate = yesterdayDate();
  const row = c.env.DB ? await getDailySnapshot(c.env.DB, nx, ny, targetDate) : null;
  if (!row) {
    return c.json({
      comparisonAvailable: false,
      current: null,
      comparison: null,
      targetDate,
    });
  }
  return c.json({ comparisonAvailable: true, targetDate, comparison: row });
});

router.get('/last-year', async (c) => {
  const { nx, ny } = regionFromQuery(c.req.query('nx'), c.req.query('ny'));
  const targetDate = lastYearDate();
  const row = c.env.DB ? await getDailySnapshot(c.env.DB, nx, ny, targetDate) : null;
  if (!row) {
    return c.json({ comparisonAvailable: false, targetDate });
  }
  return c.json({ comparisonAvailable: true, targetDate, comparison: row });
});

function yesterdayDate(): string {
  const now = new Date();
  now.setDate(now.getDate() - 1);
  return now.toISOString().slice(0, 10);
}

function lastYearDate(): string {
  const now = new Date();
  now.setFullYear(now.getFullYear() - 1);
  return now.toISOString().slice(0, 10);
}

export default router;

