// KMA's 5 km DFS Lambert projection (same constants as the Flutter grid).
// Source: https://www.weather.go.kr/w/resources/js/fn.js (convertDfsGrid)
// This is a grid representative point, never the user's measured GPS position.
export function kmaGridCoordinates(
  nx: number,
  ny: number,
): { latitude: number; longitude: number } | undefined {
  if (!Number.isInteger(nx) || !Number.isInteger(ny) ||
      nx < 1 || nx > 149 || ny < 1 || ny > 253) return undefined;

  const radians = Math.PI / 180;
  const scaledRadius = 6371.00877 / 5;
  const firstParallel = 30 * radians;
  const secondParallel = 60 * radians;
  const cone = Math.log(Math.cos(firstParallel) / Math.cos(secondParallel)) /
    Math.log(Math.tan(Math.PI / 4 + secondParallel / 2) /
      Math.tan(Math.PI / 4 + firstParallel / 2));
  const scale = Math.pow(Math.tan(Math.PI / 4 + firstParallel / 2), cone) *
    Math.cos(firstParallel) / cone;
  const originRadius = scaledRadius * scale /
    Math.pow(Math.tan(Math.PI / 4 + 38 * radians / 2), cone);
  const x = nx - 43;
  const y = originRadius - ny + 136;
  const radius = Math.hypot(x, y);
  return {
    latitude: (2 * Math.atan(Math.pow(scaledRadius * scale / radius, 1 / cone)) -
      Math.PI / 2) / radians,
    longitude: Math.atan2(x, y) / cone / radians + 126,
  };
}
