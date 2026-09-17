import { describe, expect, it } from 'vitest';
import { FixedWindowRateLimit } from '../src/node/rateLimit';
import { dueScheduledJobs, scheduledMinute } from '../src/node/schedule';
import { backupTimestamp } from '../src/node/backup';

describe('미니 PC Node 런타임', () => {
  it('Cloudflare Rate Limit과 같은 고정 구간 제한을 적용한다', async () => {
    let now = 1_000;
    const limiter = new FixedWindowRateLimit(2, 60_000, () => now);

    expect((await limiter.limit({ key: 'client' })).success).toBe(true);
    expect((await limiter.limit({ key: 'client' })).success).toBe(true);
    expect((await limiter.limit({ key: 'client' })).success).toBe(false);
    now += 60_000;
    expect((await limiter.limit({ key: 'client' })).success).toBe(true);
  });

  it('Worker와 같은 10분·15분·30분 실행 분을 유지한다', () => {
    expect(dueScheduledJobs(new Date('2026-09-17T00:00:00Z'))).toEqual(['core']);
    expect(dueScheduledJobs(new Date('2026-09-17T00:02:00Z'))).toEqual(['radar']);
    expect(dueScheduledJobs(new Date('2026-09-17T00:07:00Z'))).toEqual(['road-ice']);
    expect(dueScheduledJobs(new Date('2026-09-17T00:17:00Z'))).toEqual(['radar']);
    expect(dueScheduledJobs(new Date('2026-09-17T00:37:00Z'))).toEqual(['road-ice']);
    expect(scheduledMinute(new Date('2026-09-17T00:37:42.123Z')).toISOString())
      .toBe('2026-09-17T00:37:00.000Z');
  });

  it('백업 파일명에서 밀리초와 경로 비호환 문자를 제거한다', () => {
    expect(backupTimestamp(new Date('2026-09-17T06:34:05.326Z')))
      .toBe('20260917T063405Z');
  });
});
