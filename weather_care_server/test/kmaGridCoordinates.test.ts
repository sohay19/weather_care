import { describe, expect, it } from 'vitest';
import { kmaGridCoordinates } from '../src/regions/kmaGridCoordinates';

describe('KMA grid representative coordinates', () => {
  // Independently evaluated with KMA weather.go.kr fn.js convertDfsGrid, 2026-09-10.
  it.each([
    [43, 136, 38, 126],
    [60, 121, 37.30326021617463, 126.98505669360944],
    [60, 127, 37.579871128849334, 126.98935225645432],
    [100, 76, 35.187385416167075, 129.19712820348684],
    [52, 38, 33.5012420333313, 126.49196898149866],
    [127, 127, 37.46657057654834, 130.88275146867184],
    [144, 123, 37.23011698441371, 131.85073939120463],
    [21, 132, 37.80723464906668, 124.71503659048277],
  ])('matches official conversion for grid %d,%d', (nx, ny, latitude, longitude) => {
    expect(kmaGridCoordinates(nx, ny)?.latitude).toBeCloseTo(latitude, 10);
    expect(kmaGridCoordinates(nx, ny)?.longitude).toBeCloseTo(longitude, 10);
  });

  it.each([[0, 0], [150, 121], [60, 254], [60.5, 121], [NaN, 121], [Infinity, 121]])(
    'does not invent a location for invalid grid %d,%d', (nx, ny) => {
      expect(kmaGridCoordinates(nx, ny)).toBeUndefined();
    },
  );
});
