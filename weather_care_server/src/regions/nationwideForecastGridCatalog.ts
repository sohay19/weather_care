import { UV_AREA_GRID_ROWS } from './kmaUvAreaGridCatalog';

export interface ForecastGrid {
  nx: number;
  ny: number;
}

export const NATIONWIDE_FORECAST_GRID_SHARD_COUNT = 18;

// 앱의 2026-09-10 기상청 행정동 카탈로그와 생활기상지수 공식 격자표의
// 차이만 명시한다. 나머지 격자는 공식 격자표를 재사용해 두 대형 목록이
// 서로 다르게 갱신되는 일을 막는다.
const APP_ONLY_GRIDS: ReadonlyArray<readonly [number, number]> = [
  [52, 33],
  [94, 99],
  [97, 103],
];
const UV_ONLY_GRIDS = new Set(['94_100', '96_103']);

export const NATIONWIDE_FORECAST_GRIDS: readonly ForecastGrid[] = Object.freeze(
  [
    ...UV_AREA_GRID_ROWS
      .filter(([nx, ny]) => !UV_ONLY_GRIDS.has(`${nx}_${ny}`))
      .map(([nx, ny]) => ({ nx, ny })),
    ...APP_ONLY_GRIDS.map(([nx, ny]) => ({ nx, ny })),
  ].sort((left, right) => left.nx - right.nx || left.ny - right.ny),
);

export function nationwideForecastGridShard(
  shardIndex: number,
  shardCount = NATIONWIDE_FORECAST_GRID_SHARD_COUNT,
): readonly ForecastGrid[] {
  if (!Number.isInteger(shardCount) || shardCount < 1) {
    throw new RangeError('shardCount must be a positive integer');
  }
  if (!Number.isInteger(shardIndex) || shardIndex < 0 || shardIndex >= shardCount) {
    throw new RangeError('shardIndex must be within shardCount');
  }
  return NATIONWIDE_FORECAST_GRIDS.filter(
    (_, index) => index % shardCount === shardIndex,
  );
}

export function scheduledNationwideForecastGridShard(now: Date): {
  shardIndex: number;
  grids: readonly ForecastGrid[];
} {
  const tenMinuteSlot = Math.floor(now.getTime() / (10 * 60 * 1000));
  const shardIndex = ((tenMinuteSlot % NATIONWIDE_FORECAST_GRID_SHARD_COUNT) +
    NATIONWIDE_FORECAST_GRID_SHARD_COUNT) % NATIONWIDE_FORECAST_GRID_SHARD_COUNT;
  return {
    shardIndex,
    grids: nationwideForecastGridShard(shardIndex),
  };
}

// 실제 전국 배열 전체. 행정동 대표 격자 목록과 무관하다.
export const KMA_NATIVE_FORECAST_GRIDS: readonly ForecastGrid[] = Object.freeze(Array.from({ length: 149 * 253 }, (_, i) => ({ nx: i % 149 + 1, ny: Math.floor(i / 149) + 1 })));
