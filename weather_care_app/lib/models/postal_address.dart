class PostalAddress {
  final String roadAddress;
  final String jibunAddress;
  final bool roadEstimated;
  final bool jibunEstimated;

  const PostalAddress({
    required this.roadAddress,
    required this.jibunAddress,
    this.roadEstimated = false,
    this.jibunEstimated = false,
  });

  // 자동 매핑된 예상 주소로 위치를 확정하지 않는다.
  String get locationQuery =>
      roadAddress.isNotEmpty && !roadEstimated ? roadAddress : jibunAddress;

  factory PostalAddress.fromJson(Map<String, dynamic> json) {
    String read(String key) {
      final value = json[key];
      if (value == null) return '';
      if (value is! String || value.length > 500) {
        throw const FormatException('Invalid postal address');
      }
      return value.trim().replaceAll(RegExp(r'\s+'), ' ');
    }

    final road = read('roadAddress');
    final jibun = read('jibunAddress');
    if (road.isEmpty && jibun.isEmpty) {
      throw const FormatException('Missing confirmed address');
    }
    final autoRoad = road.isEmpty ? read('autoRoadAddress') : '';
    final autoJibun = jibun.isEmpty ? read('autoJibunAddress') : '';
    return PostalAddress(
      roadAddress: road.isNotEmpty ? road : autoRoad,
      jibunAddress: jibun.isNotEmpty ? jibun : autoJibun,
      roadEstimated: autoRoad.isNotEmpty,
      jibunEstimated: autoJibun.isNotEmpty,
    );
  }
}
