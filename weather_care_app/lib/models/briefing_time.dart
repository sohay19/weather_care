/// 응답을 받은 시점부터 서버가 기록한 생성 시각을 기준으로 경과 시간을 계산한다.
DateTime briefingNow(
  DateTime localNow, {
  String? generatedAt,
  DateTime? receivedAt,
}) {
  final serverNow = DateTime.tryParse(generatedAt ?? '');
  if (serverNow == null || receivedAt == null) return localNow;
  final elapsed = localNow.difference(receivedAt);
  return serverNow.add(elapsed.isNegative ? Duration.zero : elapsed);
}
