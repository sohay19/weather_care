import { describe, expect, it } from 'vitest';
import { lastYearDate, yesterdayDate } from '../src/api/comparison';

describe('comparison dates', () => {
  it('uses the Korean calendar date across the UTC date boundary', () => {
    const koreanMidnight = new Date('2026-08-23T15:30:00Z');

    expect(yesterdayDate(koreanMidnight)).toBe('2026-08-23');
    expect(lastYearDate(koreanMidnight)).toBe('2025-08-24');
  });
});
