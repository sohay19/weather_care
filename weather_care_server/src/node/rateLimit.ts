import type { RateLimitBinding } from '../types';

interface WindowState {
  startedAt: number;
  count: number;
}

export class FixedWindowRateLimit implements RateLimitBinding {
  private readonly windows = new Map<string, WindowState>();
  private static readonly MAX_KEYS = 10_000;

  constructor(
    private readonly limitCount: number,
    private readonly periodMs: number,
    private readonly now: () => number = Date.now,
  ) {}

  async limit({ key }: { key: string }): Promise<{ success: boolean }> {
    const now = this.now();
    const current = this.windows.get(key);
    if (!current || now - current.startedAt >= this.periodMs) {
      this.removeExpired(now);
      if (!current && this.windows.size >= FixedWindowRateLimit.MAX_KEYS) {
        return { success: false };
      }
      this.windows.set(key, { startedAt: now, count: 1 });
      return { success: true };
    }
    if (current.count >= this.limitCount) return { success: false };
    current.count += 1;
    return { success: true };
  }

  private removeExpired(now: number): void {
    if (this.windows.size < 1_000) return;
    for (const [key, value] of this.windows) {
      if (now - value.startedAt >= this.periodMs) this.windows.delete(key);
    }
  }
}
