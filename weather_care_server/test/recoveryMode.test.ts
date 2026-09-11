import { createExecutionContext, env } from 'cloudflare:test';
import { describe, expect, it, vi } from 'vitest';
import worker from '../src/index';
import * as jobs from '../src/cron/jobs';

describe('recovery isolation outside restored D1', () => {
  it.each(['on', 'ON', '', 'unexpected'])('blocks every API without reading DB for mode %j', async (mode) => {
    for (const [method, path] of [['GET', '/health'], ['GET', '/api/v1/weather/today'], ['POST', '/api/v1/installations/enroll'], ['PUT', '/api/v1/installations/test'], ['DELETE', '/api/v1/installations/test']]) {
      const response = await worker.fetch(new Request(`https://example.invalid${path}`, { method }), {
        ...env, RECOVERY_MODE: mode, get DB(): D1Database { throw new Error('must not access restored data'); },
      }, createExecutionContext());
      expect(response.status).toBe(503);
      expect(response.headers.get('Cache-Control')).toBe('no-store');
      expect(await response.json()).toMatchObject({ error: 'SERVICE_RECOVERY' });
    }
  });
  it('does not run cleanup or notifications during recovery', async () => {
    const job = vi.spyOn(jobs, 'runRecommendationNotificationJobFromCron');
    try {
      await worker.scheduled({ scheduledTime: Date.now(), cron: '*/10 * * * *', noRetry() {} }, { ...env, RECOVERY_MODE: 'on' });
      expect(job).not.toHaveBeenCalled();
    } finally { job.mockRestore(); }
  });
  it.each([undefined, 'off'])('keeps normal health available outside recovery', async mode => {
    const response = await worker.fetch(new Request('https://example.invalid/health'), { ...env, RECOVERY_MODE: mode }, createExecutionContext());
    expect(response.status).toBe(200);
  });
});
