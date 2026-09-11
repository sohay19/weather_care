import { createExecutionContext, env } from 'cloudflare:test';
import { describe, expect, it, vi } from 'vitest';
import worker from '../src/index';
import { KmaWeatherProvider } from '../src/providers/weather/kmaWeatherProvider';
import * as jobs from '../src/cron/jobs';

describe('log privacy boundaries', () => {
  it('logs provider errors without request identifiers or grid coordinates', async () => {
    const log = vi.spyOn(console, 'error').mockImplementation(() => {});
    const provider = vi.spyOn(KmaWeatherProvider.prototype, 'getForecastByRegion')
      .mockRejectedValue(Object.assign(new Error('private-token 37.263'), { name: 'private-installation' }));
    try {
      const response = await worker.fetch(new Request('https://example.invalid/api/v1/weather/weekly?nx=60&ny=121&installationId=private-installation'),
        { ...env, KMA_SERVICE_KEY: 'synthetic-key' }, createExecutionContext());
      expect(response.status).toBe(502);
      expect(log.mock.calls).toEqual([[JSON.stringify({ event: 'weather_provider_failed', provider: 'KMA', route: 'weekly', error: 'Error', failureReason: 'UNKNOWN' })]]);
    } finally { log.mockRestore(); provider.mockRestore(); }
  });

  it('replaces Hono raw exception logging with a fixed error response', async () => {
    const log = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const response = await worker.fetch(new Request('https://example.invalid/api/v1/weather/weekly'), {
        ...env, get KMA_SERVICE_KEY(): string { throw new Error('private-environment-value'); },
      }, createExecutionContext());
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: 'INTERNAL_SERVER_ERROR' });
      expect(log.mock.calls).toEqual([[JSON.stringify({ event: 'request_failed', error: 'Error' })]]);
    } finally { log.mockRestore(); }
  });

  it('keeps cron failures failed without exposing their original exception', async () => {
    const job = vi.spyOn(jobs, 'runRecommendationNotificationJobFromCron').mockRejectedValue(new Error('private-database-value'));
    try {
      await expect(worker.scheduled({ scheduledTime: Date.now(), cron: '*/10 * * * *', noRetry() {} }, env))
        .rejects.toThrow('SCHEDULED_JOB_FAILED');
    } finally { job.mockRestore(); }
  });
});
