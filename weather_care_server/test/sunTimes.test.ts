import { describe, expect, it } from 'vitest';
import { calculateSunTimes } from '../src/presentation/sunTimes';

describe('sunrise and sunset calculation', () => {
  it('calculates plausible Seoul times for the Korean calendar date', () => {
    const result = calculateSunTimes(
      new Date('2026-09-20T16:00:00Z'),
      37.5665,
      126.978,
    );
    const sunrise = koreaMinutes(result.sunriseAt);
    const sunset = koreaMinutes(result.sunsetAt);

    expect(koreaDate(result.sunriseAt)).toBe('2026-09-21');
    expect(koreaDate(result.sunsetAt)).toBe('2026-09-21');
    expect(sunrise).toBeGreaterThanOrEqual(5 * 60 + 50);
    expect(sunrise).toBeLessThanOrEqual(6 * 60 + 40);
    expect(sunset).toBeGreaterThanOrEqual(18 * 60);
    expect(sunset).toBeLessThanOrEqual(19 * 60);
  });

  it('does not produce times for invalid coordinates', () => {
    expect(calculateSunTimes(new Date(), 91, 127)).toEqual({});
  });
});

function koreaDate(value: string | undefined): string {
  return new Date(Date.parse(value!) + 9 * 60 * 60 * 1_000)
    .toISOString()
    .slice(0, 10);
}

function koreaMinutes(value: string | undefined): number {
  const korea = new Date(Date.parse(value!) + 9 * 60 * 60 * 1_000);
  return korea.getUTCHours() * 60 + korea.getUTCMinutes();
}
