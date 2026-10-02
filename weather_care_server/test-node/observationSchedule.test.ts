import { describe, expect, it } from 'vitest';
import { dueScheduledJobs } from '../src/node/schedule';

describe('현재 관측 재시도 일정', () => {
  it('예보 작업과 별도로 2분마다 현재 관측을 시도한다', () => {
    expect(dueScheduledJobs(new Date('2026-10-02T02:40:00Z')))
      .toContain('core');
    expect(dueScheduledJobs(new Date('2026-10-02T02:40:00Z')))
      .not.toContain('observation');
    expect(dueScheduledJobs(new Date('2026-10-02T02:42:00Z')))
      .toContain('observation');
    expect(dueScheduledJobs(new Date('2026-10-02T02:42:00Z')))
      .not.toContain('core');
    expect(dueScheduledJobs(new Date('2026-10-02T02:43:00Z')))
      .not.toContain('observation');
  });
});
