import { describe, expect, it } from 'vitest';
import { uvAreaNoForGrid } from '../src/regions/kmaUvAreaGridCatalog';

describe('KMA UV area grid catalog', () => {
  it('returns a current official administrative code for nationwide grids', () => {
    expect(uvAreaNoForGrid(60, 121)).toBe('4111156000');
    expect(uvAreaNoForGrid(98, 76)).toBe('2623056000');
  });

  it('uses the nearest official grid when a populated grid has no center', () => {
    expect(uvAreaNoForGrid(97, 76)).toBeDefined();
  });

  it('does not resolve coordinates outside the official grid extent', () => {
    expect(uvAreaNoForGrid(0, 0)).toBeUndefined();
    expect(uvAreaNoForGrid(Number.NaN, 121)).toBeUndefined();
  });
});
