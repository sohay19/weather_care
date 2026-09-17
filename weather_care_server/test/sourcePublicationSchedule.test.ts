import { describe, expect, it } from 'vitest';
import {
  compactIssueToIso,
  latestAirKoreaForecastIssue,
  latestRadarProductVersion,
  pollingWindowVersion,
  previousKoreanDate,
} from '../src/collection/sourcePublicationSchedule';

describe('source publication schedule', () => {
  it('uses one fixed version per polling window', () => {
    expect(pollingWindowVersion(
      new Date('2026-09-17T00:29:59.999Z'),
      30,
    )).toBe('2026-09-17T00:00:00.000Z');
    expect(pollingWindowVersion(
      new Date('2026-09-17T00:30:00.000Z'),
      30,
    )).toBe('2026-09-17T00:30:00.000Z');
  });

  it('waits ten minutes and selects the latest five-minute radar product', () => {
    expect(latestRadarProductVersion(
      new Date('2026-09-17T00:16:00.000Z'),
    )).toBe('202609170905');
  });

  it('uses the latest AirKorea issue after its publication delay', () => {
    expect(latestAirKoreaForecastIssue(
      new Date('2026-09-17T08:29:59.999Z'),
    )).toBe('202609171100');
    expect(latestAirKoreaForecastIssue(
      new Date('2026-09-17T08:30:00.000Z'),
    )).toBe('202609171700');
  });

  it('converts Korean issue times and calendar dates deterministically', () => {
    expect(compactIssueToIso('202609171800'))
      .toBe('2026-09-17T18:00:00+09:00');
    expect(previousKoreanDate(new Date('2026-09-17T00:00:00.000Z')))
      .toBe('2026-09-16');
  });
});
