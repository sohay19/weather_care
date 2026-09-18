import { describe, expect, it } from 'vitest';
import {
  NATIONWIDE_FORECAST_GRIDS,
  NATIONWIDE_FORECAST_GRID_SHARD_COUNT,
  nationwideForecastGridShard,
  scheduledNationwideForecastGridShard,
} from '../src/regions/nationwideForecastGridCatalog';

describe('전국 예보 격자 카탈로그', () => {
  it('앱이 지원하는 1,633개 고유 격자를 중복 없이 보존한다', () => {
    const keys = NATIONWIDE_FORECAST_GRIDS.map(({ nx, ny }) => `${nx}_${ny}`);

    expect(keys).toHaveLength(1_633);
    expect(new Set(keys).size).toBe(1_633);
    expect(keys).toContain('52_33');
    expect(keys).toContain('94_99');
    expect(keys).toContain('97_103');
    expect(keys).not.toContain('94_100');
    expect(keys).not.toContain('96_103');
  });

  it('18개 묶음이 전체 격자를 정확히 한 번씩 포함한다', () => {
    const shards = Array.from(
      { length: NATIONWIDE_FORECAST_GRID_SHARD_COUNT },
      (_, index) => nationwideForecastGridShard(index),
    );
    const keys = shards.flat().map(({ nx, ny }) => `${nx}_${ny}`);

    expect(shards.every((shard) => shard.length === 90 || shard.length === 91))
      .toBe(true);
    expect(keys).toHaveLength(1_633);
    expect(new Set(keys).size).toBe(1_633);
  });

  it('10분마다 다음 묶음으로 이동하고 3시간 뒤 같은 묶음으로 돌아온다', () => {
    const start = scheduledNationwideForecastGridShard(
      new Date('2026-09-18T00:00:00Z'),
    );
    const next = scheduledNationwideForecastGridShard(
      new Date('2026-09-18T00:10:00Z'),
    );
    const nextCycle = scheduledNationwideForecastGridShard(
      new Date('2026-09-18T03:00:00Z'),
    );

    expect(next.shardIndex).toBe(
      (start.shardIndex + 1) % NATIONWIDE_FORECAST_GRID_SHARD_COUNT,
    );
    expect(nextCycle.shardIndex).toBe(start.shardIndex);
    expect(nextCycle.grids).toEqual(start.grids);
  });
});
