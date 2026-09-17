import { describe, expect, it } from 'vitest';
import { shouldRefreshEnvironmentalRecord } from '../src/collection/weatherCollectionJob';
import type { CollectedCacheRecord } from '../src/database/collectedWeatherRepository';
import type { EnvironmentalDataBundle } from '../src/providers/environmental/environmentalDataService';

const collectedAt = '2026-09-17T04:00:00.000Z';

function record(
  airQualityState: EnvironmentalDataBundle['sources']['airQuality']['state'],
): CollectedCacheRecord<EnvironmentalDataBundle> {
  return {
    status: 'AVAILABLE',
    updatedAt: collectedAt,
    value: {
      sources: {
        uv: { provider: 'KMA_LIVING_INDEX_V5', state: 'AVAILABLE' },
        airQuality: { provider: 'AIRKOREA', state: airQualityState },
      },
    },
  };
}

describe('environmental collection retry interval', () => {
  it.each(['STALE', 'UNAVAILABLE'] as const)(
    '%s 상태는 10분 뒤 다시 수집한다',
    (state) => {
      expect(shouldRefreshEnvironmentalRecord(
        record(state),
        new Date('2026-09-17T04:09:59.999Z'),
      )).toBe(false);
      expect(shouldRefreshEnvironmentalRecord(
        record(state),
        new Date('2026-09-17T04:10:00.000Z'),
      )).toBe(true);
    },
  );

  it.each(['AVAILABLE', 'CACHED', 'UNSUPPORTED_REGION'] as const)(
    '%s 상태는 기존 30분 수집 주기를 유지한다',
    (state) => {
      expect(shouldRefreshEnvironmentalRecord(
        record(state),
        new Date('2026-09-17T04:29:59.999Z'),
      )).toBe(false);
      expect(shouldRefreshEnvironmentalRecord(
        record(state),
        new Date('2026-09-17T04:30:00.000Z'),
      )).toBe(true);
    },
  );
});
