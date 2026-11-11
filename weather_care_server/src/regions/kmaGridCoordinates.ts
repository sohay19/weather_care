// 기상청 DFS 5km 격자의 램버트 역투영. 앱과 같은 상수를 사용한다.
// https://www.weather.go.kr/w/resources/js/fn.js (convertDfsGrid)
export type GeographicBounds = [west: number, south: number, east: number, north: number];

export function kmaGridCoordinates(
  nx: number,
  ny: number,
): { latitude: number; longitude: number } | undefined {
  if (!validGrid(nx, ny)) return undefined;
  return inverseProjection(nx, ny);
}

export function kmaGridBounds(nx: number, ny: number): GeographicBounds | undefined {
  if (!validGrid(nx, ny)) return undefined;

  // 역투영의 경도 극값은 모서리에 있다. 위도는 원점 자오선(x=43)에서도 극값이 될 수 있다.
  const columns = nx === 43 ? [nx - 0.5, nx, nx + 0.5] : [nx - 0.5, nx + 0.5];
  const points = columns.flatMap(x => [inverseProjection(x, ny - 0.5), inverseProjection(x, ny + 0.5)]);
  const longitudes = points.map(point => point.longitude);
  const latitudes = points.map(point => point.latitude);
  const padding = 1e-9; // 부동소수점 오차만큼 격자를 바깥쪽으로 감싼다.
  return [Math.min(...longitudes) - padding, Math.min(...latitudes) - padding,
    Math.max(...longitudes) + padding, Math.max(...latitudes) + padding];
}

function validGrid(nx: number, ny: number): boolean {
  return Number.isInteger(nx) && Number.isInteger(ny) && nx >= 1 && nx <= 149 && ny >= 1 && ny <= 253;
}

function inverseProjection(nx: number, ny: number): { latitude: number; longitude: number } {
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
