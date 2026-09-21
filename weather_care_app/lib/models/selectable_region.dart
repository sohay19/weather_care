class ForecastRegion {
  final String code;
  final String parentCode;
  final String name;
  final int nx;
  final int ny;
  final String fullName;

  const ForecastRegion(
      {required this.code,
      required this.parentCode,
      required this.name,
      required this.nx,
      required this.ny,
      required this.fullName});

  // KMA's source reuses some dong codes. Preserve name and grid as well.
  String get key => '$code|$name|$nx|$ny';
  String get gridId => '${nx}_$ny';
}

class ForecastGridSelection {
  final int nx;
  final int ny;
  final String regionKey;
  final String regionName;

  const ForecastGridSelection({
    required this.nx,
    required this.ny,
    required this.regionKey,
    required this.regionName,
  });

  String get gridId => '${nx}_$ny';
}
