import { describe, expect, it } from 'vitest';
import { regionName } from '../src/regions/regionCatalog';

describe('region catalog', () => {
  it('keeps a known regional name and accepts a GPS fallback', () => {
    expect(regionName(60, 127, '현재 위치')).toBe('서울');
    expect(regionName(98, 76, '현재 위치')).toBe('현재 위치');
    expect(regionName(98, 76)).toBe('선택 지역');
  });
});
