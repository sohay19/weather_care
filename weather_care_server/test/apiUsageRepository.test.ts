import { env } from 'cloudflare:test';
import { beforeEach, describe, expect, it } from 'vitest';
import {
  getApiHubUsage,
  reserveApiHubBudget,
  reserveMonthlyRequestBudget,
} from '../src/database/apiUsageRepository';

describe('API usage repository', () => {
  beforeEach(async () => {
    await env.DB.exec('DROP TABLE IF EXISTS api_usage_daily');
    await env.DB.prepare(
      `CREATE TABLE api_usage_daily (
        usage_date TEXT NOT NULL,
        provider TEXT NOT NULL,
        request_count INTEGER NOT NULL DEFAULT 0,
        response_bytes INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (usage_date, provider)
      )`,
    ).run();
  });

  it('keeps ITS requests out of the APIHub daily allowance', async () => {
    const now = new Date('2026-09-22T03:00:00Z');
    expect(await reserveApiHubBudget(env.DB, 'GRID', 17_999, 0, now)).toBe(true);
    expect(await reserveMonthlyRequestBudget(
      env.DB,
      'ITS_ROAD_CONTROL',
      9_000,
      9_000,
      now,
    )).toBe(true);
    expect(await reserveApiHubBudget(env.DB, 'AWS', 1, 0, now)).toBe(true);
    await expect(getApiHubUsage(env.DB, now)).resolves.toEqual({
      requestCount: 18_000,
      responseBytes: 0,
    });
  });

  it('enforces and resets the ITS monthly request allowance in Korean time', async () => {
    const september = new Date('2026-09-30T14:59:00Z');
    expect(await reserveMonthlyRequestBudget(
      env.DB,
      'ITS_ROAD_CONTROL',
      8_999,
      9_000,
      september,
    )).toBe(true);
    expect(await reserveMonthlyRequestBudget(
      env.DB,
      'ITS_ROAD_CONTROL',
      2,
      9_000,
      september,
    )).toBe(false);
    expect(await reserveMonthlyRequestBudget(
      env.DB,
      'ITS_ROAD_CONTROL',
      1,
      9_000,
      september,
    )).toBe(true);
    expect(await reserveMonthlyRequestBudget(
      env.DB,
      'ITS_ROAD_CONTROL',
      1,
      9_000,
      new Date('2026-09-30T15:00:00Z'),
    )).toBe(true);
  });

  it('limits fast observation retries without consuming the allowance for other sources', async () => {
    const now = new Date('2026-10-02T03:00:00Z');
    expect(await reserveApiHubBudget(
      env.DB, 'GRID_OBSERVATION_FAST_RETRY', 3, 999_000_000, now,
      { providerDailyByteLimit: 1_000_000_000, dailyByteLimit: 3_500_000_000 },
    )).toBe(true);
    expect(await reserveApiHubBudget(
      env.DB, 'GRID_OBSERVATION_FAST_RETRY', 3, 3_000_000, now,
      { providerDailyByteLimit: 1_000_000_000, dailyByteLimit: 3_500_000_000 },
    )).toBe(false);
    expect(await reserveApiHubBudget(
      env.DB, 'WARNING', 1, 256_000, now,
    )).toBe(true);
  });

  it('stops fast retries before the shared allowance is exhausted', async () => {
    const now = new Date('2026-10-02T03:00:00Z');
    expect(await reserveApiHubBudget(env.DB, 'OTHER', 1, 3_499_000_000, now))
      .toBe(true);
    expect(await reserveApiHubBudget(
      env.DB, 'GRID_OBSERVATION_FAST_RETRY', 3, 3_000_000, now,
      { providerDailyByteLimit: 1_000_000_000, dailyByteLimit: 3_500_000_000 },
    )).toBe(false);
    expect(await reserveApiHubBudget(env.DB, 'WARNING', 1, 256_000, now))
      .toBe(true);
  });
});
