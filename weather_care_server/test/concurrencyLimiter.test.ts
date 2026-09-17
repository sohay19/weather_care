import { describe, expect, it, vi } from 'vitest';
import { mapWithConcurrency } from '../src/utils/concurrencyLimiter';

describe('concurrency limiter', () => {
  it('never runs more tasks than the configured limit', async () => {
    let active = 0;
    let maximum = 0;
    const releases: Array<() => void> = [];

    const resultPromise = mapWithConcurrency([1, 2, 3, 4], 2, async (value) => {
      active += 1;
      maximum = Math.max(maximum, active);
      await new Promise<void>((resolve) => releases.push(resolve));
      active -= 1;
      return value * 2;
    });

    await vi.waitFor(() => {
      expect(active).toBe(2);
      expect(releases).toHaveLength(2);
    });
    releases.shift()?.();
    releases.shift()?.();
    await vi.waitFor(() => {
      expect(active).toBe(2);
      expect(releases).toHaveLength(2);
    });
    releases.shift()?.();
    releases.shift()?.();

    await expect(resultPromise).resolves.toEqual([2, 4, 6, 8]);
    expect(maximum).toBe(2);
  });
});
