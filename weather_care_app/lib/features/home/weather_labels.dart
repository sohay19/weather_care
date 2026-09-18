/// 시간대가 없는 기상청 시각은 한국시간으로, 오프셋이 있으면 한국시간으로 변환한다.
String forecastTemperatureLabel(String? forecastAt) {
  final parsed = forecastAt == null ? null : DateTime.tryParse(forecastAt);
  if (parsed == null || !forecastAt!.contains('T')) return '시';
  final inKorea = parsed.isUtc ? parsed.add(const Duration(hours: 9)) : parsed;
  final period = inKorea.hour < 12 ? '오전' : '오후';
  final hour = inKorea.hour % 12 == 0 ? 12 : inKorea.hour % 12;
  return '$period $hour시';
}

/// 서버 응답 생성 시각을 한국시간 기준으로 표시한다.
String weatherRefreshLabel(String? generatedAt, {DateTime? now}) {
  final parsed = generatedAt == null ? null : DateTime.tryParse(generatedAt);
  final source = parsed ?? now ?? DateTime.now();
  final inKorea = source.isUtc ? source.add(const Duration(hours: 9)) : source;
  final period = inKorea.hour < 12 ? '오전' : '오후';
  final hour = inKorea.hour % 12 == 0 ? 12 : inKorea.hour % 12;
  final minute = inKorea.minute.toString().padLeft(2, '0');
  return '${inKorea.month}월 ${inKorea.day}일 $period $hour시 $minute분 기준';
}
