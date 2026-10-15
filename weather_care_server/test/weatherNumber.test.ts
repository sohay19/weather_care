import { describe, expect, it } from 'vitest';
import { formatWeatherNumber } from '../src/utils/weatherNumber';

describe('날씨 숫자 정밀도', () => {
  it.each([
    [23.46, '23.5'], [12.5, '12.5'], [20, '20'], [0.125, '0.1'],
    [0.009, '0.009'], [0.00026, '0.0003'], [-0.009, '-0.009'], [-0, '0'],
  ] as const)('%s → %s', (value, expected) => {
    expect(formatWeatherNumber(value)).toBe(expected);
  });
});
