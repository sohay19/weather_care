import 'package:flutter_test/flutter_test.dart';
import 'package:weather_care/services/kma_grid.dart';

void main() {
  test('전국 대표 좌표를 기상청 5km 격자로 변환한다', () {
    const cases = [
      (name: '서울', latitude: 37.5665, longitude: 126.9780, nx: 60, ny: 127),
      (name: '수원', latitude: 37.2636, longitude: 127.0286, nx: 61, ny: 120),
      (name: '대전', latitude: 36.3504, longitude: 127.3845, nx: 67, ny: 100),
      (name: '대구', latitude: 35.8714, longitude: 128.6014, nx: 89, ny: 91),
      (name: '부산', latitude: 35.1796, longitude: 129.0756, nx: 98, ny: 76),
      (name: '광주', latitude: 35.1595, longitude: 126.8526, nx: 58, ny: 74),
      (name: '강릉', latitude: 37.7519, longitude: 128.8761, nx: 92, ny: 132),
      (name: '제주', latitude: 33.4996, longitude: 126.5312, nx: 53, ny: 38),
    ];

    for (final entry in cases) {
      expect(
        KmaGrid.fromCoordinates(
          latitude: entry.latitude,
          longitude: entry.longitude,
        ),
        KmaGrid(nx: entry.nx, ny: entry.ny),
        reason: entry.name,
      );
    }
  });
}
