// 기상청 DFS 5km 격자 변환. 앱 KmaGrid.fromCoordinates와 같은 상수·반올림을 쓴다.
export function kmaGridFromCoordinates(latitude: number, longitude: number): { nx: number; ny: number } {
  const radians = Math.PI / 180;
  const radius = 6371.00877 / 5;
  const first = 30 * radians;
  const second = 60 * radians;
  const cone = Math.log(Math.cos(first) / Math.cos(second)) /
    Math.log(Math.tan(Math.PI / 4 + second / 2) / Math.tan(Math.PI / 4 + first / 2));
  const scale = Math.pow(Math.tan(Math.PI / 4 + first / 2), cone) * Math.cos(first) / cone;
  const origin = radius * scale / Math.pow(Math.tan(Math.PI / 4 + 38 * radians / 2), cone);
  const projected = radius * scale / Math.pow(Math.tan(Math.PI / 4 + latitude * radians / 2), cone);
  let angle = (longitude - 126) * radians;
  if (angle > Math.PI) angle -= 2 * Math.PI;
  if (angle < -Math.PI) angle += 2 * Math.PI;
  return { nx: Math.floor(projected * Math.sin(angle * cone) + 43 + 0.5),
    ny: Math.floor(origin - projected * Math.cos(angle * cone) + 136 + 0.5) };
}
