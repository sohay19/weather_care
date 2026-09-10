/// 시간대가 없는 기상청 시각은 한국시간으로, 오프셋이 있으면 한국시간으로 변환한다.
String forecastTemperatureLabel(String? forecastAt) {
  final parsed = forecastAt == null ? null : DateTime.tryParse(forecastAt);
  if (parsed == null || !forecastAt!.contains('T')) return '예상기온';
  final inKorea = parsed.isUtc ? parsed.add(const Duration(hours: 9)) : parsed;
  final period = inKorea.hour < 12 ? '오전' : '오후';
  final hour = inKorea.hour % 12 == 0 ? 12 : inKorea.hour % 12;
  return '$period $hour시 예상기온';
}
