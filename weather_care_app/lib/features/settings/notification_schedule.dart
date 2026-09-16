/// Mirrors the server's existing ten-minute cron slot without changing the
/// user's saved time. This is a check time, never a delivery guarantee.
String notificationScheduleDescription(String time) {
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(time);
  if (match == null) return '알림 시간을 다시 선택해주세요.';
  final minutes = int.parse(match[1]!) * 60 + int.parse(match[2]!);
  final rounded = ((minutes + 9) ~/ 10) * 10;
  final hour = ((rounded ~/ 60) % 24).toString().padLeft(2, '0');
  final minute = (rounded % 60).toString().padLeft(2, '0');
  final day = rounded >= 1440 ? '다음 날 ' : '';
  return '서버 확인 시각: $day$hour:$minute (한국시간).\n10분 단위로 확인하며 실제 도착은 늦어질 수 있어요.';
}
