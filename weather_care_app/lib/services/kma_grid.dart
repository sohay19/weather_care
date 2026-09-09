import 'dart:math' as math;

class KmaGrid {
  final int nx;
  final int ny;

  const KmaGrid({required this.nx, required this.ny});

  static const suwon = KmaGrid(nx: 60, ny: 121);

  factory KmaGrid.fromCoordinates({
    required double latitude,
    required double longitude,
  }) {
    const earthRadiusKilometers = 6371.00877;
    const gridSpacingKilometers = 5.0;
    const firstStandardParallel = 30.0;
    const secondStandardParallel = 60.0;
    const originLongitude = 126.0;
    const originLatitude = 38.0;
    const originX = 43.0;
    const originY = 136.0;
    const degreesToRadians = math.pi / 180.0;

    final scaledRadius = earthRadiusKilometers / gridSpacingKilometers;
    final firstParallel = firstStandardParallel * degreesToRadians;
    final secondParallel = secondStandardParallel * degreesToRadians;
    final originLatitudeRadians = originLatitude * degreesToRadians;
    final originLongitudeRadians = originLongitude * degreesToRadians;

    var cone = math.tan(math.pi * 0.25 + secondParallel * 0.5) /
        math.tan(math.pi * 0.25 + firstParallel * 0.5);
    cone = math.log(math.cos(firstParallel) / math.cos(secondParallel)) /
        math.log(cone);
    var scale = math.tan(math.pi * 0.25 + firstParallel * 0.5);
    scale = math.pow(scale, cone) * math.cos(firstParallel) / cone;
    var originRadius = math.tan(math.pi * 0.25 + originLatitudeRadians * 0.5);
    originRadius = scaledRadius * scale / math.pow(originRadius, cone);

    var radius = math.tan(
      math.pi * 0.25 + latitude * degreesToRadians * 0.5,
    );
    radius = scaledRadius * scale / math.pow(radius, cone);
    var angle = longitude * degreesToRadians - originLongitudeRadians;
    if (angle > math.pi) angle -= 2.0 * math.pi;
    if (angle < -math.pi) angle += 2.0 * math.pi;
    angle *= cone;

    return KmaGrid(
      nx: (radius * math.sin(angle) + originX + 0.5).floor(),
      ny: (originRadius - radius * math.cos(angle) + originY + 0.5).floor(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is KmaGrid && other.nx == nx && other.ny == ny;

  @override
  int get hashCode => Object.hash(nx, ny);

  @override
  String toString() => 'KmaGrid(nx: $nx, ny: $ny)';
}
